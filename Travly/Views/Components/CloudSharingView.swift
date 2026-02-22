import SwiftUI
import CloudKit
import CoreData
import CoreTransferable
import os.log

private let shareLog = Logger(subsystem: "com.kevinbuckley.travelplanner", category: "Sharing")

// MARK: - Sharing Presenter

/// Handles CloudKit sharing for trips.
///
/// For NEW shares: Creates the CKShare first, then shares the share URL
/// via a plain UIActivityViewController. This completely avoids the
/// UICloudSharingController + Messages collaboration framework spinner bug
/// by sending a regular URL instead of a collaboration object.
///
/// For EXISTING shares: Uses UICloudSharingController for managing
/// participants, permissions, and stopping sharing.
enum CloudSharingPresenter {

    /// Present the sharing UI for a trip.
    static func present(
        trip: TripEntity,
        persistence: PersistenceController,
        sharingService: CloudKitSharingService
    ) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else {
            shareLog.error("[SHARE] No window scene or root VC found")
            return
        }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        if let existingShare = sharingService.existingShare(for: trip) {
            // Existing share — use UICloudSharingController for management
            shareLog.info("[SHARE] Presenting UICloudSharingController for EXISTING share")
            presentSharingController(
                share: existingShare,
                container: persistence.cloudContainer,
                persistence: persistence,
                from: topVC
            )
        } else {
            // New share — create CKShare, then share the URL directly
            shareLog.info("[SHARE] Creating NEW share, then sharing URL directly")
            createAndShareURL(
                trip: trip,
                persistence: persistence,
                from: topVC
            )
        }
    }

    // MARK: - New Share: Create CKShare then share its URL

    /// Creates a CKShare via NSPersistentCloudKitContainer with retry logic,
    /// waits for the share URL, then presents a standard UIActivityViewController.
    /// This bypasses the Messages collaboration framework entirely — the URL is just
    /// a regular link that the recipient taps to accept the CloudKit share.
    ///
    /// Retries up to 3 times with increasing delays (2s, 4s) to handle cases where
    /// the trip record hasn't finished syncing to CloudKit yet (causes permission errors).
    private static func createAndShareURL(
        trip: TripEntity,
        persistence: PersistenceController,
        from presenter: UIViewController
    ) {
        let tripName = trip.wrappedName

        // Save any pending changes
        if let ctx = trip.managedObjectContext, ctx.hasChanges {
            do {
                try ctx.save()
                shareLog.info("[SHARE] Pre-share context save succeeded")
            } catch {
                shareLog.error("[SHARE] Pre-share context save FAILED: \(error.localizedDescription)")
            }
        }

        // Show loading indicator
        let loadingAlert = UIAlertController(
            title: nil,
            message: "Preparing share link...",
            preferredStyle: .alert
        )
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        loadingAlert.view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerYAnchor.constraint(equalTo: loadingAlert.view.centerYAnchor),
            spinner.leadingAnchor.constraint(equalTo: loadingAlert.view.leadingAnchor, constant: 20),
            loadingAlert.view.heightAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])
        presenter.present(loadingAlert, animated: true)

        // Use async Task with retry logic
        Task { @MainActor in
            let startTime = CFAbsoluteTimeGetCurrent()
            shareLog.info("[SHARE] Starting share creation with retries for trip: \(tripName)")

            var lastError: Error?

            for attempt in 0..<3 {
                if attempt > 0 {
                    let delay = 2 * attempt
                    shareLog.info("[SHARE] Retry \(attempt)/2 — waiting \(delay)s for CloudKit sync...")
                    loadingAlert.message = "Waiting for sync... (attempt \(attempt + 1)/3)"
                    try? await Task.sleep(for: .seconds(delay))
                }

                do {
                    let (_, share, _) = try await persistence.container.share(
                        [trip],
                        to: nil
                    )

                    let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                    shareLog.info("[SHARE] container.share() succeeded in \(String(format: "%.2f", elapsed))s (attempt \(attempt + 1))")

                    // Configure the share
                    share[CKShare.SystemFieldKey.title] = tripName
                    share.publicPermission = .readWrite

                    // Persist locally
                    if let store = persistence.privatePersistentStore {
                        try await persistence.container.persistUpdatedShare(share, in: store)
                        shareLog.info("[SHARE] persistUpdatedShare completed")
                    }

                    shareLog.info("[SHARE] Share URL: \(share.url?.absoluteString ?? "nil")")

                    guard let shareURL = share.url else {
                        shareLog.error("[SHARE] Share has no URL — cannot share")
                        loadingAlert.dismiss(animated: true) {
                            showError(
                                NSError(domain: "Travly", code: -2,
                                        userInfo: [NSLocalizedDescriptionKey: "Share was created but has no link. Please try again."]),
                                from: presenter
                            )
                        }
                        return
                    }

                    // Success — dismiss loading and present the share sheet with a WRAPPED URL.
                    // We wrap the share.icloud.com URL inside a custom travly:// scheme
                    // so that Messages does NOT detect it as a CloudKit collaboration URL
                    // and trigger the infinite spinner bug.
                    loadingAlert.dismiss(animated: true) {
                        shareLog.info("[SHARE] Presenting UIActivityViewController with wrapped share URL")

                        // Encode the real share URL inside our custom scheme
                        let encodedShareURL = shareURL.absoluteString.addingPercentEncoding(
                            withAllowedCharacters: .urlQueryAllowed
                        ) ?? shareURL.absoluteString
                        let wrappedURLString = "travly://share?url=\(encodedShareURL)"

                        // Share as a plain text string — NOT a URL object — to prevent
                        // any URL detection from intercepting the link
                        let shareText = "Join my trip \"\(tripName)\" on Travly!\n\(wrappedURLString)"
                        let activityVC = UIActivityViewController(
                            activityItems: [shareText as NSString],
                            applicationActivities: nil
                        )
                        activityVC.modalPresentationStyle = .formSheet

                        presenter.present(activityVC, animated: true) {
                            shareLog.info("[SHARE] UIActivityViewController presented")
                        }
                    }
                    return // Success — exit the retry loop

                } catch {
                    lastError = error
                    let nsError = error as NSError
                    shareLog.error("[SHARE] container.share() attempt \(attempt + 1) failed: \(nsError.domain) code=\(nsError.code) — \(error.localizedDescription)")

                    // Only retry on permission/server errors that might resolve after sync
                    let isRetryable = nsError.domain == "CKErrorDomain" &&
                        (nsError.code == 10 || nsError.code == 1 || nsError.code == 7)
                    if !isRetryable {
                        shareLog.error("[SHARE] Error is not retryable — giving up")
                        break
                    }
                }
            }

            // All retries exhausted
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            shareLog.error("[SHARE] All share attempts failed after \(String(format: "%.2f", elapsed))s")
            loadingAlert.dismiss(animated: true) {
                showError(lastError ?? NSError(
                    domain: "Travly", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to create share after multiple attempts. Please try again in a moment."]),
                    from: presenter
                )
            }
        }
    }

    // MARK: - Existing Share: UICloudSharingController for management

    private static func presentSharingController(
        share: CKShare,
        container: CKContainer,
        persistence: PersistenceController,
        from presenter: UIViewController
    ) {
        let delegate = SharingDelegate(persistence: persistence)
        let controller = UICloudSharingController(share: share, container: container)
        controller.delegate = delegate
        controller.availablePermissions = [.allowPublic, .allowPrivate, .allowReadOnly, .allowReadWrite]
        controller.modalPresentationStyle = .formSheet

        objc_setAssociatedObject(controller, &SharingDelegate.associatedKey, delegate, .OBJC_ASSOCIATION_RETAIN)

        shareLog.info("[SHARE] Presenting UICloudSharingController for share management")
        presenter.present(controller, animated: true)
    }

    @MainActor private static func showError(_ error: Error, from presenter: UIViewController) {
        let alert = UIAlertController(
            title: "Sharing Failed",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        presenter.present(alert, animated: true)
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
        shareLog.error("[SHARE] failedToSaveShareWithError: \(error.localizedDescription)")
    }

    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        shareLog.info("[SHARE] didSaveShare")
        if let share = csc.share, let store = persistence.privatePersistentStore {
            persistence.container.persistUpdatedShare(share, in: store)
            shareLog.info("[SHARE] persistUpdatedShare completed")
        } else {
            shareLog.warning("[SHARE] WARNING: no share or no private store to persist")
        }
    }

    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        shareLog.info("[SHARE] didStopSharing")
        if let share = csc.share,
           let store = persistence.privatePersistentStore {
            persistence.container.purgeObjectsAndRecordsInZone(
                with: share.recordID.zoneID,
                in: store
            ) { _, error in
                if let error {
                    shareLog.error("[SHARE] purge error: \(error.localizedDescription)")
                } else {
                    shareLog.info("[SHARE] purge completed successfully")
                }
            }
        }
    }

    func itemTitle(for csc: UICloudSharingController) -> String? {
        csc.share?.value(forKey: CKShare.SystemFieldKey.title) as? String
    }

    func itemThumbnailData(for csc: UICloudSharingController) -> Data? { nil }
}
