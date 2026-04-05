import Foundation
import os

/// Lightweight launch-time instrumentation. Captures the absolute time at
/// first module load, then lets us log "+Nms since start" at key milestones
/// so we can attribute a slow cold-launch white screen to a specific phase.
///
/// View with Console.app (Mac) with the iPhone connected: filter by
/// `subsystem:com.futureego.launch`. Survives Xcode detach.
enum LaunchTrace {
    /// Captured the first time this enum is touched. For the earliest possible
    /// start we reference `LaunchTrace.start` from `FutureEgoApp.init()`.
    static let start: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()

    static let log = Logger(subsystem: "com.futureego.launch", category: "LaunchTrace")

    /// Log a milestone with ms elapsed since `start`.
    static func mark(_ tag: String) {
        let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
        log.info("+\(ms)ms \(tag, privacy: .public)")
    }
}
