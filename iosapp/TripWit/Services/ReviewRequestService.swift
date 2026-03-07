import StoreKit
import Foundation

/// Manages when to request an App Store review using StoreKit's
/// `SKStoreReviewController` / `AppStore.requestReview(in:)`.
///
/// Strategy: request after the user has completed 3+ trips and
/// not been prompted in the last 90 days.
enum ReviewRequestService {

    // MARK: - UserDefaults Keys

    private static let lastPromptDateKey    = "tripwit.review.lastPromptDate"
    private static let completedTripsKey    = "tripwit.review.completedTripsCount"
    private static let minimumTrips         = 3
    private static let minimumDaysBetween   = 90

    // MARK: - Eligibility

    /// Returns true if conditions are met to show the review prompt.
    static func shouldRequestReview(
        completedTripsCount: Int,
        now: Date = Date(),
        defaults: UserDefaults = .standard
    ) -> Bool {
        guard completedTripsCount >= minimumTrips else { return false }

        if let last = defaults.object(forKey: lastPromptDateKey) as? Date {
            let daysSince = Calendar.current.dateComponents([.day], from: last, to: now).day ?? 0
            return daysSince >= minimumDaysBetween
        }

        return true  // Never prompted before
    }

    /// Record that a review prompt was shown today.
    static func recordPrompt(now: Date = Date(), defaults: UserDefaults = .standard) {
        defaults.set(now, forKey: lastPromptDateKey)
    }

    /// Persist the count of completed trips.
    static func setCompletedTripsCount(_ count: Int, defaults: UserDefaults = .standard) {
        defaults.set(count, forKey: completedTripsKey)
    }

    /// Read the persisted count of completed trips.
    static func completedTripsCount(defaults: UserDefaults = .standard) -> Int {
        defaults.integer(forKey: completedTripsKey)
    }

    // MARK: - Days Since Last Prompt

    /// Returns the number of days since the last review prompt, or nil if never prompted.
    static func daysSinceLastPrompt(
        now: Date = Date(),
        defaults: UserDefaults = .standard
    ) -> Int? {
        guard let last = defaults.object(forKey: lastPromptDateKey) as? Date else { return nil }
        return Calendar.current.dateComponents([.day], from: last, to: now).day
    }

    // MARK: - Reset (for testing)

    static func reset(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: lastPromptDateKey)
        defaults.removeObject(forKey: completedTripsKey)
    }

    // MARK: - Threshold constants (testable)

    static var minimumTripsThreshold: Int { minimumTrips }
    static var cooldownDays: Int { minimumDaysBetween }
}
