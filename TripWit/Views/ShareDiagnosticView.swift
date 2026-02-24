import SwiftUI
import CloudKit
import CoreData
import os.log

private let diagLog = Logger(subsystem: "com.kevinbuckley.travelplanner", category: "ShareDiag")

/// Diagnostic view that queries CloudKit directly to help debug sharing issues.
/// Shows: iCloud account status, shared zones, records in each zone, Core Data state, and sync events.
struct ShareDiagnosticView: View {

    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(sortDescriptors: []) private var allTrips: FetchedResults<TripEntity>

    @State private var isRunning = false
    @State private var results: [DiagLine] = []

    private let persistence = PersistenceController.shared
    private let ckContainer = CKContainer(identifier: "iCloud.com.kevinbuckley.travelplanner")

    var body: some View {
        List {
            Section {
                Button {
                    Task { await runDiagnostics() }
                } label: {
                    HStack {
                        Label("Run Full Diagnostics", systemImage: "stethoscope")
                        Spacer()
                        if isRunning {
                            ProgressView()
                        }
                    }
                }
                .disabled(isRunning)
            } footer: {
                Text("Queries iCloud account, CloudKit databases, Core Data stores, and sync events. Copy results and send to developer.")
            }

            if !results.isEmpty {
                Section("Results (\(results.count) items)") {
                    ForEach(results) { line in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: line.icon)
                                .foregroundStyle(line.color)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(line.title)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                if let detail = line.detail {
                                    Text(detail)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        .padding(.vertical, 1)
                    }
                }

                Section {
                    Button {
                        let text = results.map { line in
                            "\(line.type.rawValue.uppercased()) | \(line.title)\(line.detail.map { "\n  \($0)" } ?? "")"
                        }.joined(separator: "\n")
                        UIPasteboard.general.string = text
                    } label: {
                        Label("Copy All Results", systemImage: "doc.on.clipboard")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Share Diagnostics")
    }

    @MainActor
    private func runDiagnostics() async {
        isRunning = true
        results = []

        // ── 1. iCloud Account ──
        add(.info, "=== iCloud Account ===")
        do {
            let status = try await ckContainer.accountStatus()
            switch status {
            case .available: add(.ok, "iCloud: Available")
            case .noAccount: add(.error, "iCloud: NOT SIGNED IN")
            case .restricted: add(.error, "iCloud: Restricted")
            case .couldNotDetermine: add(.warning, "iCloud: Could not determine")
            case .temporarilyUnavailable: add(.warning, "iCloud: Temporarily unavailable")
            @unknown default: add(.warning, "iCloud: Unknown (\(status.rawValue))")
            }
        } catch {
            add(.error, "iCloud check failed", detail: error.localizedDescription)
        }

        // ── 2. Core Data Stores ──
        add(.info, "=== Core Data Stores ===")
        let stores = persistence.container.persistentStoreCoordinator.persistentStores
        add(.info, "Loaded stores: \(stores.count)")
        for store in stores {
            let isShared = store.url?.lastPathComponent == "Shared.sqlite"
            let hasCloudKit = store.options?.keys.contains(where: { ($0 as? String)?.contains("CloudKit") == true }) ?? false
            add(.info, "  \(store.url?.lastPathComponent ?? "?")", detail: "isShared=\(isShared), cloudKit=\(hasCloudKit), id=\(store.identifier)")
        }

        // ── 3. Direct Store Trip Counts ──
        add(.info, "=== Direct Store Queries ===")
        let privateCount = persistence.privateStoreTripCount()
        let sharedCount = persistence.sharedStoreTripCount()
        add(privateCount >= 0 ? .info : .error, "Private store trips: \(privateCount)")
        add(.info, "Shared store trips: \(sharedCount)", detail: sharedCount == 0 ? "No trips imported from shared zones yet" : nil)

        // viewContext count
        let vcCount = allTrips.count
        let sharingService = CloudKitSharingService(persistence: persistence)
        let participantTrips = allTrips.filter { sharingService.isParticipant($0) }
        add(.info, "viewContext trips: \(vcCount)", detail: "\(participantTrips.count) as participant")

        // ── 4. Shares in Each Store ──
        add(.info, "=== CKShare Objects ===")
        if let privateStore = persistence.privatePersistentStore {
            do {
                let shares = try persistence.container.fetchShares(in: privateStore)
                add(.info, "Shares we OWN (private): \(shares.count)")
                for share in shares {
                    let parts = share.participants.map { p in
                        "\(p.role == .owner ? "owner" : "participant"):\(p.acceptanceStatus == .accepted ? "accepted" : "pending")"
                    }.joined(separator: ", ")
                    add(.info, "  \(share.recordID.recordName)", detail: "url=\(share.url?.absoluteString ?? "nil"), participants=[\(parts)]")
                }
            } catch {
                add(.error, "fetchShares(private) failed", detail: error.localizedDescription)
            }
        }

        if let sharedStore = persistence.sharedPersistentStore {
            do {
                let shares = try persistence.container.fetchShares(in: sharedStore)
                if shares.isEmpty {
                    add(.warning, "Shares we ACCEPTED (shared): 0", detail: "If you accepted a share, this should not be 0. This means Core Data hasn't imported the share metadata.")
                } else {
                    add(.ok, "Shares we ACCEPTED (shared): \(shares.count)")
                }
                for share in shares {
                    add(.info, "  \(share.recordID.recordName)", detail: "zone=\(share.recordID.zoneID.zoneName), owner=\(share.recordID.zoneID.ownerName)")
                }
            } catch {
                add(.error, "fetchShares(shared) failed", detail: error.localizedDescription)
            }
        }

        // ── 5. CloudKit Shared Database ──
        add(.info, "=== CloudKit Shared Database ===")
        let sharedDB = ckContainer.sharedCloudDatabase
        do {
            let zones = try await sharedDB.allRecordZones()
            if zones.isEmpty {
                add(.warning, "Shared zones: 0", detail: "CloudKit has no shared zones visible to this account. Either no share was accepted, or the share was revoked.")
            } else {
                add(.ok, "Shared zones: \(zones.count)")
            }

            for zone in zones {
                let zoneID = zone.zoneID
                add(.info, "Zone: \(zoneID.zoneName)", detail: "owner: \(zoneID.ownerName)")

                do {
                    let changes = try await sharedDB.recordZoneChanges(inZoneWith: zoneID, since: nil)
                    let modifications = changes.modificationResultsByID
                    add(.ok, "  Records: \(modifications.count)")

                    var typeCount: [String: Int] = [:]
                    for (_, result) in modifications {
                        switch result {
                        case .success(let modification):
                            typeCount[modification.record.recordType, default: 0] += 1
                        case .failure:
                            typeCount["(error)", default: 0] += 1
                        }
                    }
                    for (type, count) in typeCount.sorted(by: { $0.key < $1.key }) {
                        add(.info, "    \(type): \(count)")
                    }
                } catch {
                    add(.error, "  Zone fetch failed", detail: error.localizedDescription)
                }
            }
        } catch {
            add(.error, "allRecordZones failed", detail: error.localizedDescription)
        }

        // ── 6. Sync Events ──
        add(.info, "=== Sync Events (since app launch) ===")
        let events = persistence.syncEvents
        if events.isEmpty {
            add(.warning, "No sync events captured", detail: "NSPersistentCloudKitContainer hasn't fired any eventChanged notifications. This could mean sync hasn't been triggered.")
        } else {
            add(.info, "Total events: \(events.count)")
            let failures = events.filter { !$0.succeeded }
            if !failures.isEmpty {
                add(.error, "FAILED events: \(failures.count)")
            }
            // Show last 20 events
            for event in events.suffix(20) {
                let timeStr = event.date.formatted(date: .omitted, time: .standard)
                let status = event.succeeded ? "OK" : "FAIL"
                let errDetail = event.error.map { "Error: \($0)" }
                add(event.succeeded ? .ok : .error, "  [\(timeStr)] \(event.type) \(event.storeName): \(status)", detail: errDetail)
            }
        }

        add(.ok, "=== Diagnostics Complete ===")
        isRunning = false
    }

    private func add(_ type: DiagType, _ title: String, detail: String? = nil) {
        results.append(DiagLine(type: type, title: title, detail: detail))
        diagLog.info("[DIAG] \(type.rawValue) \(title) \(detail ?? "")")
    }
}

// MARK: - Models

private enum DiagType: String {
    case ok, warning, error, info
}

private struct DiagLine: Identifiable {
    let id = UUID()
    let type: DiagType
    let title: String
    let detail: String?

    var icon: String {
        switch type {
        case .ok: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle"
        }
    }

    var color: Color {
        switch type {
        case .ok: return .green
        case .warning: return .orange
        case .error: return .red
        case .info: return .blue
        }
    }
}
