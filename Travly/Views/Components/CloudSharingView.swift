import SwiftUI
import CloudKit
import CoreData

struct CloudSharingView: UIViewControllerRepresentable {

    let trip: TripEntity
    let persistence: PersistenceController
    let sharingService: CloudKitSharingService

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> CloudSharingHostController {
        let host = CloudSharingHostController()
        host.trip = trip
        host.persistence = persistence
        host.sharingService = sharingService
        host.coordinator = context.coordinator
        host.onDismiss = { dismiss() }
        return host
    }

    func updateUIViewController(_ uiViewController: CloudSharingHostController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator (UICloudSharingControllerDelegate)

    class Coordinator: NSObject, UICloudSharingControllerDelegate {

        let parent: CloudSharingView

        init(_ parent: CloudSharingView) {
            self.parent = parent
        }

        func cloudSharingController(
            _ csc: UICloudSharingController,
            failedToSaveShareWithError error: Error
        ) {
            print("[SHARE] ❌ failedToSaveShareWithError: \(error)")
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            print("[SHARE] ✅ didSaveShare called")
            if let share = csc.share {
                print("[SHARE]   share URL: \(share.url?.absoluteString ?? "nil")")
                print("[SHARE]   participants: \(share.participants.count)")
                if let store = parent.persistence.privatePersistentStore {
                    parent.persistence.container.persistUpdatedShare(share, in: store)
                    print("[SHARE]   persisted share to store")
                } else {
                    print("[SHARE]   ⚠️ no private store to persist share")
                }
            } else {
                print("[SHARE]   ⚠️ csc.share is nil")
            }
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            print("[SHARE] 🛑 didStopSharing called")
            if let share = csc.share,
               let store = parent.persistence.privatePersistentStore {
                parent.persistence.container.purgeObjectsAndRecordsInZone(
                    with: share.recordID.zoneID,
                    in: store
                ) { _, error in
                    if let error {
                        print("[SHARE]   purge error: \(error)")
                    } else {
                        print("[SHARE]   purge succeeded")
                    }
                }
            }
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            let title = parent.trip.wrappedName
            print("[SHARE] itemTitle requested: \(title)")
            return title
        }

        func itemThumbnailData(for csc: UICloudSharingController) -> Data? {
            print("[SHARE] itemThumbnailData requested")
            return nil
        }
    }
}

// MARK: - Clear Background

struct ClearBackgroundView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - Host Controller

class CloudSharingHostController: UIViewController, UIAdaptivePresentationControllerDelegate {

    var trip: TripEntity!
    var persistence: PersistenceController!
    var sharingService: CloudKitSharingService!
    var coordinator: CloudSharingView.Coordinator!
    var onDismiss: (() -> Void)?

    private var didPresent = false
    private var isDismissing = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        print("[SHARE] Host viewDidLoad")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("[SHARE] Host viewDidAppear (didPresent=\(didPresent))")

        if !didPresent {
            didPresent = true
            presentSharingController()
        } else {
            print("[SHARE] Host reappeared — sharing controller dismissed, cleaning up")
            dismissIfNeeded()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("[SHARE] Host viewWillDisappear")
    }

    private func presentSharingController() {
        let controller: UICloudSharingController

        if let existingShare = sharingService.existingShare(for: trip) {
            print("[SHARE] Using EXISTING share: \(existingShare.url?.absoluteString ?? "no URL")")
            controller = UICloudSharingController(
                share: existingShare,
                container: persistence.cloudContainer
            )
        } else {
            print("[SHARE] Creating NEW share via preparationHandler")
            let container = persistence.container
            let cloudContainer = persistence.cloudContainer
            let tripToShare = trip!

            controller = UICloudSharingController { sharingController, preparationCompletionHandler in
                print("[SHARE] preparationHandler CALLED — calling container.share()")
                print("[SHARE]   thread: \(Thread.isMainThread ? "MAIN" : "background")")

                container.share([tripToShare], to: nil) { objectIDs, share, ckContainer, error in
                    print("[SHARE] container.share() completion:")
                    print("[SHARE]   thread: \(Thread.isMainThread ? "MAIN" : "background")")
                    print("[SHARE]   error: \(error?.localizedDescription ?? "none")")
                    print("[SHARE]   share: \(share != nil ? "exists" : "nil")")
                    if let share {
                        print("[SHARE]   share URL: \(share.url?.absoluteString ?? "nil")")
                        print("[SHARE]   share recordID: \(share.recordID)")
                        share[CKShare.SystemFieldKey.title] = tripToShare.wrappedName
                    }
                    if let objectIDs {
                        print("[SHARE]   objectIDs: \(objectIDs)")
                    }
                    print("[SHARE] Calling preparationCompletionHandler...")
                    preparationCompletionHandler(share, ckContainer, error)
                    print("[SHARE] preparationCompletionHandler returned")
                }
            }
        }

        controller.delegate = coordinator
        controller.availablePermissions = [.allowPublic, .allowPrivate, .allowReadOnly, .allowReadWrite]
        controller.modalPresentationStyle = .formSheet
        controller.presentationController?.delegate = self

        print("[SHARE] Presenting UICloudSharingController...")
        present(controller, animated: true) {
            print("[SHARE] UICloudSharingController presented (animation complete)")
        }
    }

    private func dismissIfNeeded() {
        guard !isDismissing else {
            print("[SHARE] dismissIfNeeded — already dismissing, skipped")
            return
        }
        isDismissing = true
        print("[SHARE] dismissIfNeeded — calling onDismiss")
        onDismiss?()
    }

    // MARK: - UIAdaptivePresentationControllerDelegate

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        print("[SHARE] presentationControllerDidDismiss")
        dismissIfNeeded()
    }
}
