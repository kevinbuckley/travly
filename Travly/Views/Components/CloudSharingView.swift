import SwiftUI
import CloudKit
import CoreData

struct CloudSharingView: UIViewControllerRepresentable {

    let share: CKShare
    let persistence: PersistenceController
    let sharingService: CloudKitSharingService
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> CloudSharingHostController {
        let host = CloudSharingHostController()
        host.share = share
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
            print("[SHARE] failedToSaveShareWithError: \(error)")
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            if let share = csc.share, let store = parent.persistence.privatePersistentStore {
                parent.persistence.container.persistUpdatedShare(share, in: store)
            }
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            if let share = csc.share,
               let store = parent.persistence.privatePersistentStore {
                parent.persistence.container.purgeObjectsAndRecordsInZone(
                    with: share.recordID.zoneID,
                    in: store
                ) { _, error in
                    if let error {
                        print("[SHARE] purge error: \(error)")
                    }
                }
            }
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            csc.share?.value(forKey: CKShare.SystemFieldKey.title) as? String
        }

        func itemThumbnailData(for csc: UICloudSharingController) -> Data? { nil }
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

    var share: CKShare!
    var persistence: PersistenceController!
    var sharingService: CloudKitSharingService!
    var coordinator: CloudSharingView.Coordinator!
    var onDismiss: (() -> Void)?

    private var didPresent = false
    private var isDismissing = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !didPresent {
            didPresent = true
            presentSharingController()
        } else {
            // Sharing controller was dismissed — clean up
            dismissIfNeeded()
        }
    }

    private func presentSharingController() {
        // Always use the share:container: initializer.
        // The share was already created before this view was presented.
        let controller = UICloudSharingController(
            share: share,
            container: persistence.cloudContainer
        )
        controller.delegate = coordinator
        controller.availablePermissions = [.allowPublic, .allowPrivate, .allowReadOnly, .allowReadWrite]
        controller.modalPresentationStyle = .formSheet
        controller.presentationController?.delegate = self
        present(controller, animated: true)
    }

    private func dismissIfNeeded() {
        guard !isDismissing else { return }
        isDismissing = true
        onDismiss?()
    }

    // MARK: - UIAdaptivePresentationControllerDelegate

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        dismissIfNeeded()
    }
}
