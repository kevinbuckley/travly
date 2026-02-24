import SwiftUI
import CoreData
import CloudKit
import os.log

private let appLog = Logger(subsystem: "com.kevinbuckley.travelplanner", category: "App")

@main
struct TripWitApp: App {

    let persistence = PersistenceController.shared
    @State private var locationManager = LocationManager()
    @State private var pendingImportURL: URL?
    @State private var shareAcceptAlert: ShareAcceptAlert?

    /// UIApplicationDelegate adapter to handle CloudKit share acceptance.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView(pendingImportURL: $pendingImportURL)
                .environment(locationManager)
                .environment(\.managedObjectContext, persistence.viewContext)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .alert(item: $shareAcceptAlert) { alert in
                    Alert(
                        title: Text(alert.title),
                        message: Text(alert.message),
                        dismissButton: .default(Text("OK"))
                    )
                }
        }
    }

    /// Route incoming URLs to the right handler
    private func handleIncomingURL(_ url: URL) {
        appLog.info("[URL] Received URL: \(url.absoluteString)")

        if url.scheme == "tripwit" && url.host == "share" {
            // tripwit://share?url=<encoded_share_url>
            handleShareURL(url)
        } else if url.pathExtension == "tripwit" {
            // .tripwit file import
            pendingImportURL = url
        } else {
            appLog.warning("[URL] Unhandled URL: \(url.absoluteString)")
        }
    }

    /// Accept a CloudKit share from a wrapped URL.
    /// Extracts the real share.icloud.com URL, fetches metadata, and accepts the share.
    private func handleShareURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let rawParam = components.queryItems?.first(where: { $0.name == "url" })?.value
        else {
            appLog.error("[SHARE-ACCEPT] Could not extract share URL from: \(url.absoluteString)")
            shareAcceptAlert = ShareAcceptAlert(
                title: "Invalid Share Link",
                message: "This share link appears to be invalid. Please ask the sender to share again."
            )
            return
        }

        // iMessage can wrap URLs in markdown-style formatting (e.g. __url__ for bold).
        // Strip leading/trailing underscores and whitespace before parsing.
        let cleaned = rawParam.trimmingCharacters(in: CharacterSet(charactersIn: "_").union(.whitespaces))

        guard let shareURL = URL(string: cleaned) else {
            appLog.error("[SHARE-ACCEPT] Could not parse cleaned share URL: \(cleaned) (raw: \(rawParam))")
            shareAcceptAlert = ShareAcceptAlert(
                title: "Invalid Share Link",
                message: "This share link appears to be malformed. Please ask the sender to share again."
            )
            return
        }

        appLog.info("[SHARE-ACCEPT] Extracted share URL: \(shareURL.absoluteString)")

        // Show a loading indicator (we'll use an alert for simplicity)
        shareAcceptAlert = ShareAcceptAlert(
            title: "Joining Trip...",
            message: "Connecting to the shared trip. This may take a moment — hang tight!"
        )

        Task {
            // Collect diagnostic info as we go — will show in final alert
            var diag: [String] = []

            func log(_ msg: String) {
                appLog.info("[SHARE-ACCEPT] \(msg)")
                diag.append(msg)
            }

            do {
                // Step 1: Fetch the share metadata from the URL
                let metadata = try await fetchShareMetadata(from: shareURL)
                log("1. Metadata fetched")
                log("   Share ID: \(metadata.share.recordID.recordName)")
                log("   Zone: \(metadata.share.recordID.zoneID.zoneName)")
                log("   Owner: \(metadata.share.recordID.zoneID.ownerName)")
                log("   Root record: \(metadata.rootRecordID.recordName)")
                log("   Participant status: \(Self.participantStatusString(metadata.participantStatus))")
                log("   Participant permission: \(Self.participantPermissionString(metadata.participantPermission))")
                log("   Participant role: \(Self.participantRoleString(metadata.participantRole))")

                // Step 2: Accept the share into the shared persistent store
                guard let sharedStore = persistence.sharedPersistentStore else {
                    log("ERROR: No shared store available!")
                    await MainActor.run {
                        shareAcceptAlert = ShareAcceptAlert(title: "Error", message: diag.joined(separator: "\n"))
                    }
                    return
                }
                log("2. Shared store: \(sharedStore.url?.lastPathComponent ?? "?")")

                // Clear sync events so we only see events from THIS acceptance
                await MainActor.run { persistence.syncEvents.removeAll() }

                try await persistence.container.acceptShareInvitations(
                    from: [metadata],
                    into: sharedStore
                )
                log("3. acceptShareInvitations succeeded")

                // Check participant status after accept
                log("   Post-accept status: \(Self.participantStatusString(metadata.participantStatus))")

                // Query store counts BEFORE any sync attempt
                let privateCount = persistence.privateStoreTripCount()
                let sharedCount = persistence.sharedStoreTripCount()
                let viewContextCount = await MainActor.run { () -> Int in
                    let req = TripEntity.fetchRequest() as! NSFetchRequest<TripEntity>
                    return (try? persistence.viewContext.count(for: req)) ?? 0
                }
                log("4. Store counts before sync:")
                log("   Private store: \(privateCount) trips")
                log("   Shared store: \(sharedCount) trips")
                log("   viewContext: \(viewContextCount) trips")

                // Step 3a: Fetch records from the shared zone directly via CloudKit API
                let zoneID = metadata.share.recordID.zoneID
                let ckContainer = CKContainer(identifier: "iCloud.com.kevinbuckley.travelplanner")
                let sharedDB = ckContainer.sharedCloudDatabase

                var ckRecordCount = 0
                var ckRecordTypes: [String: Int] = [:]
                do {
                    let zoneChanges = try await sharedDB.recordZoneChanges(inZoneWith: zoneID, since: nil)
                    ckRecordCount = zoneChanges.modificationResultsByID.count
                    for (_, result) in zoneChanges.modificationResultsByID {
                        if case .success(let mod) = result {
                            ckRecordTypes[mod.record.recordType, default: 0] += 1
                        }
                    }
                    log("5. CloudKit zone fetch: \(ckRecordCount) records")
                    for (type, count) in ckRecordTypes.sorted(by: { $0.key < $1.key }) {
                        log("   \(type): \(count)")
                    }
                } catch {
                    log("5. CloudKit zone fetch FAILED: \(error.localizedDescription)")
                }

                // Step 3b: Check shares in shared store
                do {
                    let shares = try persistence.container.fetchShares(in: sharedStore)
                    log("6. Shares in shared store: \(shares.count)")
                    for share in shares {
                        log("   \(share.recordID.recordName) zone=\(share.recordID.zoneID.zoneName)")
                    }
                } catch {
                    log("6. fetchShares failed: \(error.localizedDescription)")
                }

                // Step 3c: Reload shared store
                await persistence.refreshCloudKitSync()
                log("7. Shared store reloaded")

                // Wait and check sync events + store counts
                try? await Task.sleep(for: .seconds(5))

                let sharedCountAfter = persistence.sharedStoreTripCount()
                let viewContextAfter = await MainActor.run { () -> Int in
                    persistence.viewContext.refreshAllObjects()
                    let req = TripEntity.fetchRequest() as! NSFetchRequest<TripEntity>
                    return (try? persistence.viewContext.count(for: req)) ?? 0
                }
                log("8. After 5s wait:")
                log("   Shared store: \(sharedCountAfter) trips")
                log("   viewContext: \(viewContextAfter) trips")

                // Capture sync events
                let events = await MainActor.run { persistence.syncEvents }
                if events.isEmpty {
                    log("9. Sync events: NONE (NSPersistentCloudKitContainer never fired)")
                } else {
                    log("9. Sync events: \(events.count)")
                    for event in events {
                        let status = event.succeeded ? "OK" : "FAIL"
                        let errStr = event.error.map { " — \($0)" } ?? ""
                        log("   [\(status)] \(event.type) \(event.storeName)\(errStr)")
                    }
                }

                // Poll a bit more
                var tripArrived = sharedCountAfter > 0 || viewContextAfter > viewContextCount
                if !tripArrived {
                    for pollAttempt in 1...10 {
                        try? await Task.sleep(for: .seconds(2))
                        let current = persistence.sharedStoreTripCount()
                        if current > 0 {
                            tripArrived = true
                            log("10. Trip appeared after poll \(pollAttempt)! (\(current) in shared store)")
                            break
                        }
                    }
                    if !tripArrived {
                        log("10. Trip did NOT appear after 20s additional polling")
                    }
                } else {
                    log("10. Trip already present!")
                }

                // Final summary
                await MainActor.run {
                    persistence.viewContext.refreshAllObjects()
                    let diagText = diag.joined(separator: "\n")
                    if tripArrived {
                        shareAcceptAlert = ShareAcceptAlert(
                            title: "Trip Joined! 🎉",
                            message: "The shared trip is now in your trips list.\n\n--- Debug ---\n\(diagText)"
                        )
                    } else {
                        shareAcceptAlert = ShareAcceptAlert(
                            title: "Trip Not Syncing",
                            message: "The share was accepted but the trip hasn't appeared. Go to Settings → Share Diagnostics for more info.\n\n--- Debug ---\n\(diagText)"
                        )
                    }
                }
            } catch {
                log("ERROR: \(error.localizedDescription)")
                let diagText = diag.joined(separator: "\n")
                await MainActor.run {
                    shareAcceptAlert = ShareAcceptAlert(
                        title: "Could Not Join Trip",
                        message: "\(error.localizedDescription)\n\n--- Debug ---\n\(diagText)"
                    )
                }
            }
        }
    }

    // MARK: - CloudKit Enum Helpers

    private static func participantStatusString(_ status: CKShare.ParticipantAcceptanceStatus) -> String {
        switch status {
        case .unknown: return "unknown"
        case .pending: return "pending"
        case .accepted: return "accepted"
        case .removed: return "removed"
        @unknown default: return "rawValue(\(status.rawValue))"
        }
    }

    private static func participantPermissionString(_ perm: CKShare.ParticipantPermission) -> String {
        switch perm {
        case .unknown: return "unknown"
        case .none: return "none"
        case .readOnly: return "readOnly"
        case .readWrite: return "readWrite"
        @unknown default: return "rawValue(\(perm.rawValue))"
        }
    }

    private static func participantRoleString(_ role: CKShare.ParticipantRole) -> String {
        switch role {
        case .unknown: return "unknown"
        case .owner: return "owner"
        case .privateUser: return "privateUser"
        case .publicUser: return "publicUser"
        @unknown default: return "rawValue(\(role.rawValue))"
        }
    }

    /// Fetch CKShare.Metadata from a share URL using CKFetchShareMetadataOperation
    private func fetchShareMetadata(from url: URL) async throws -> CKShare.Metadata {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKFetchShareMetadataOperation(shareURLs: [url])
            operation.shouldFetchRootRecord = true

            var foundMetadata: CKShare.Metadata?
            var perShareError: Error?

            operation.perShareMetadataResultBlock = { shareURL, result in
                switch result {
                case .success(let metadata):
                    appLog.info("[SHARE-ACCEPT] Got metadata for \(shareURL)")
                    foundMetadata = metadata
                case .failure(let error):
                    appLog.error("[SHARE-ACCEPT] perShareMetadata error for \(shareURL): \(error.localizedDescription)")
                    perShareError = error
                }
            }

            operation.fetchShareMetadataResultBlock = { result in
                switch result {
                case .success:
                    if let metadata = foundMetadata {
                        continuation.resume(returning: metadata)
                    } else if let error = perShareError {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(throwing: NSError(
                            domain: "TripWit", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "No metadata returned for share URL. The share may have been revoked or the link may be invalid."]
                        ))
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            let container = CKContainer(identifier: "iCloud.com.kevinbuckley.travelplanner")
            container.add(operation)
        }
    }
}

// MARK: - Share Accept Alert

struct ShareAcceptAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

// MARK: - AppDelegate for CloudKit Share Acceptance

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )
        config.delegateClass = SceneDelegate.self
        return config
    }
}

class SceneDelegate: NSObject, UIWindowSceneDelegate {

    /// This is still needed for cases where the OS intercepts a share.icloud.com
    /// URL directly (e.g. from older invitations or if someone manually shares the raw URL).
    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        appLog.info("[SHARE-ACCEPT] System accepted share via userDidAcceptCloudKitShareWith")
        let persistence = PersistenceController.shared
        let sharingService = CloudKitSharingService(persistence: persistence)
        Task {
            do {
                try await sharingService.acceptShare(cloudKitShareMetadata)
                appLog.info("[SHARE-ACCEPT] Share accepted via SceneDelegate, refreshing viewContext")
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run {
                    persistence.viewContext.refreshAllObjects()
                }
            } catch {
                appLog.error("[SHARE-ACCEPT] Failed to accept CloudKit share: \(error)")
            }
        }
    }
}
