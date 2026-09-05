//
//  Completer.swift
//  Places
//
//  Created by David Sherlock on 2026.
//
//  MKLocalSearchCompleter is delegate-based, stateful, AND requires a running
//  run loop. This drives one on a thread of its own so a caller just awaits.
//

import Foundation
import MapKit

/// Wraps `MKLocalSearchCompleter` in a single `await`.
///
/// **The completer needs a run loop.** Measured 2026-09-05: driven from a
/// detached task with no run loop spinning, the delegate is NEVER called and
/// the await hangs forever — no error, no timeout, nothing. Spin a run loop
/// and the same query answers with 15 results immediately. An app always has
/// one; a command-line tool does not, which is precisely where the fleet uses
/// this. So the completer gets a dedicated thread with its own run loop, and a
/// deadline, and can therefore never hang a caller.
///
/// Results are mapped to ``Suggestion`` inside the delegate callback:
/// `MKLocalSearchCompletion` is not `Sendable`, so sending one across the
/// continuation is a data race under Swift 6. ``Suggestion`` is a plain value.
final class Completer: NSObject, MKLocalSearchCompleterDelegate, @unchecked Sendable {

    /// How long to wait before giving up. Autocomplete that takes longer than
    /// this is useless anyway — the user has typed another character.
    static let timeout: TimeInterval = 10

    private var continuation: CheckedContinuation<[Suggestion], Error>?
    private let lock = NSLock()
    private var completer: MKLocalSearchCompleter?

    /// Resumes once, whichever arrives first: results, failure, or the deadline.
    private func finish(_ result: Result<[Suggestion], Error>) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        guard let pending else { return }
        completer?.delegate = nil
        pending.resume(with: result)
    }

    /// The MapKit filter objects are not Sendable, so the Sendable inputs cross
    /// into the completer's thread and the filters are built there.
    func suggestions(for fragment: String,
                     near: Coordinate?,
                     radiusMetres: Double,
                     regionPriority: RegionPriority,
                     resultTypes: ResultTypes,
                     categories: [PointOfInterest],
                     excluding: [PointOfInterest],
                     addressComponents: AddressComponents,
                     excludingAddressComponents: AddressComponents) async throws -> [Suggestion] {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            self.continuation = continuation
            lock.unlock()

            let thread = Thread { [self] in
                let completer = MKLocalSearchCompleter()
                self.completer = completer
                completer.delegate = self
                completer.resultTypes = resultTypes.completerResultType
                completer.pointOfInterestFilter = Places.filter(including: categories, excluding: excluding)
                completer.addressFilter = AddressComponents.filter(including: addressComponents, excluding: excludingAddressComponents)
                if let near {
                    completer.region = near.region(radiusMetres: radiusMetres)
                    completer.regionPriority = regionPriority.mapKit
                }
                // Assigning the fragment is what starts the search, so it is last.
                completer.queryFragment = fragment

                // Drive the run loop the completer depends on, until it answers
                // or the deadline passes. `finish` is a no-op after the first.
                let deadline = Date().addingTimeInterval(Completer.timeout)
                while Date() < deadline {
                    lock.lock(); let stillWaiting = self.continuation != nil; lock.unlock()
                    guard stillWaiting else { return }
                    RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
                }
                finish(.failure(PlacesError.timedOut))
            }
            thread.name = "places.completer"
            thread.start()
        }
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        finish(.success(completer.results.map(Suggestion.init)))
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        finish(.failure(error))
    }
}
