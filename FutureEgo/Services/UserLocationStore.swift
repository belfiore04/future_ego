import Foundation

// MARK: - UserLocationStore
//
// Thin static accessor over UserDefaults for the user's commonly-used
// addresses (home + work). The same keys are bound in `LocationSettingsView`
// via `@AppStorage`, so UI writes and this store stay in sync.
//
// v1: plain strings only — no geocoding, no CoreLocation, no maps.

enum UserLocationStore {

    // MARK: - UserDefaults Keys
    //
    // Keep these identical to the `@AppStorage` keys used in
    // `LocationSettingsView`, otherwise writes and reads will diverge.

    static let homeAddressKey = "user_home_address"
    static let workAddressKey = "user_work_address"

    // MARK: - Home Address

    /// The user's home address as plain text. `nil` when unset or empty.
    static var homeAddress: String? {
        get { readTrimmedString(forKey: homeAddressKey) }
        set { writeString(newValue, forKey: homeAddressKey) }
    }

    // MARK: - Work Address

    /// The user's work / company address as plain text. `nil` when unset or empty.
    static var workAddress: String? {
        get { readTrimmedString(forKey: workAddressKey) }
        set { writeString(newValue, forKey: workAddressKey) }
    }

    // MARK: - Private Helpers

    /// Reads a string from UserDefaults, returning `nil` if missing or
    /// whitespace-only so callers can just use `if let`.
    private static func readTrimmedString(forKey key: String) -> String? {
        guard let raw = UserDefaults.standard.string(forKey: key) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Writes a string to UserDefaults. Passing `nil` or an empty value
    /// removes the entry so `@AppStorage` sees the default state.
    private static func writeString(_ value: String?, forKey key: String) {
        let defaults = UserDefaults.standard
        if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
