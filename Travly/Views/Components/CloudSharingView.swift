import SwiftUI
import CloudKit
import CoreData

// MARK: - Present UICloudSharingController from pure UIKit

/// Presents UICloudSharingController directly from UIKit's view controller hierarchy,
/// bypassing UIViewControllerRepresentable which has known bugs with the preparationHandler.
enum CloudSharingPresenter {

    /// Present the sharing UI for a trip.
    /// For NEW shares, uses the preparationHandler initializer presented from pure UIKit.
    /// For EXISTING shares, uses the share:container: initializer.
    static func present(
        trip: TripEntity,
        persistence: PersistenceController,
        sharingService: CloudKitSharingService
    ) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return }

        // Walk to the topmost presented controller
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        let delegate = SharingDelegate(persistence: persistence)

        let controller: UICloudSharingController
        if let existingShare = sharingService.existingShare(for: trip) {
            // Existing share — present directly
            controller = UICloudSharingController(
                share: existingShare,
                container: persistence.cloudContainer
            )
        } else {
            // New share — use preparationHandler.
            // This works correctly when presented from pure UIKit.
            let container = persistence.container
            let tripToShare = trip

            controller = UICloudSharingController { sharingController, preparationCompletionHandler in
                container.share([tripToShare], to: nil) { objectIDs, share, ckContainer, error in
                    if let share {
                        share[CKShare.SystemFieldKey.title] = tripToShare.wrappedName
                    }
                    preparationCompletionHandler(share, ckContainer, error)
                }
            }
        }

        controller.delegate = delegate
        controller.availablePermissions = [.allowPublic, .allowPrivate, .allowReadOnly, .allowReadWrite]
        controller.modalPresentationStyle = .formSheet

        // Keep the delegate alive until the controller is dismissed
        objc_setAssociatedObject(controller, &SharingDelegate.associatedKey, delegate, .OBJC_ASSOCIATION_RETAIN)

        topVC.present(controller, animated: true)
    }
}

// MARK: - Sharing Delegate

private class SharingDelegate: NSObject, UICloudSharingControllerDelegate {

    static var associatedKey: UInt8 = 0

    let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    func cloudSharingController(
        _ csc: UICloudSharingController,
        failedToSaveShareWithError error: Error
    ) {
        print("[SHARE] failedToSaveShareWithError: \(error)")
    }

    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        if let share = csc.share, let store = persistence.privatePersistentStore {
            persistence.container.persistUpdatedShare(share, in: store)
        }
    }

    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        if let share = csc.share,
           let store = persistence.privatePersistentStore {
            persistence.container.purgeObjectsAndRecordsInZone(
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
