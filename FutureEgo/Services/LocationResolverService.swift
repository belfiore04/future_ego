import Foundation
import MapKit
import CoreLocation

// MARK: - LocationResolverService

/// Resolves a natural-language location string (e.g. "星巴克 望京店", "海底捞",
/// "国家会议中心") to a `GeoPoint` via `MKLocalSearch`.
///
/// `ScheduleManager` calls this from a background task after inserting an
/// `outing` / `exercising` / `eating.eat_out` item so the detail pages can
/// show a real map pin without the AI having to guess lat/lng itself.
///
/// Strategy:
/// - Uses the user's home address (if set in UserDefaults) as a region hint.
///   Without this, generic queries like "星巴克" would match globally and the
///   top hit is often in the wrong country.
/// - Caches the home → region resolution for the process lifetime so every
///   schedule insert doesn't re-geocode the same address.
/// - Silent failures: returns `nil` if the query is empty, if MapKit errors,
///   or if nothing matches. Callers treat a missing coordinate as "map pin
///   unavailable" rather than surfacing the error.
enum LocationResolverService {

    // MARK: - Home region cache

    /// Process-lifetime cache for the geocoded home region. Invalidated only
    /// when the home address string changes.
    private static var cachedHomeRegion: MKCoordinateRegion?
    private static var cachedHomeResolvedFor: String?
    private static let cacheLock = NSLock()

    // MARK: - Public API

    /// Resolve `query` to a coordinate. Returns `nil` on empty input or if
    /// MapKit returns no results / errors.
    static func resolve(_ query: String) async -> GeoPoint? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        if let region = await regionHint() {
            request.region = region
        }

        do {
            let response = try await MKLocalSearch(request: request).start()
            guard
                let top = response.mapItems.first,
                let coord = top.placemark.location?.coordinate
            else {
                return nil
            }
            return GeoPoint(coordinate: coord)
        } catch {
            return nil
        }
    }

    // MARK: - Private

    /// Geocode the user's home address (once) to bias MKLocalSearch toward
    /// the right city. Returns nil if no home is set or geocoding fails.
    private static func regionHint() async -> MKCoordinateRegion? {
        let home = UserLocationStore.homeAddress
        guard let home, !home.isEmpty else { return nil }

        cacheLock.lock()
        let cached = cachedHomeRegion
        let cachedKey = cachedHomeResolvedFor
        cacheLock.unlock()

        if cachedKey == home, let cached {
            return cached
        }

        do {
            let placemarks = try await CLGeocoder().geocodeAddressString(home)
            guard let coord = placemarks.first?.location?.coordinate else {
                return nil
            }
            let region = MKCoordinateRegion(
                center: coord,
                latitudinalMeters: 20_000,
                longitudinalMeters: 20_000
            )
            cacheLock.lock()
            cachedHomeRegion = region
            cachedHomeResolvedFor = home
            cacheLock.unlock()
            return region
        } catch {
            return nil
        }
    }
}
