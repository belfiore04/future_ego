import CallKit
import AVFoundation
import SwiftUI

@MainActor
class CallService: NSObject, ObservableObject {
    static let shared = CallService()

    @Published var isCallActive = false
    @Published var callUUID: UUID?

    private var provider: CXProvider?
    private var callController: CXCallController?

    /// CallKit is unavailable on the iOS Simulator.
    private let isSimulator: Bool = {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }()

    override init() {
        super.init()

        if !isSimulator {
            let config = CXProviderConfiguration()
            config.supportsVideo = false
            config.maximumCallsPerCallGroup = 1
            config.supportedHandleTypes = [.generic]

            let p = CXProvider(configuration: config)
            provider = p
            callController = CXCallController()
            p.setDelegate(self, queue: nil)
        }
    }

    // MARK: - Outgoing Call (user taps phone button)

    /// User-initiated call — directly show overlay, no CallKit needed.
    func startCall() {
        let uuid = UUID()
        callUUID = uuid
        configureAudioSession()
        isCallActive = true
    }

    // MARK: - Incoming Call (triggered by morning/evening alarm)

    func reportIncomingCall(reason: String = "AI Coach") {
        let uuid = UUID()
        callUUID = uuid

        if isSimulator {
            configureAudioSession()
            isCallActive = true
            return
        }

        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: reason)
        update.localizedCallerName = "Future Ego"
        update.hasVideo = false
        update.supportsGrouping = false
        update.supportsHolding = false

        provider?.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error {
                print("Report incoming call error: \(error)")
            }
        }
    }

    // MARK: - End Call

    func endCall() {
        guard let uuid = callUUID else { return }

        // If CallKit is managing this call (incoming), end via transaction
        if !isSimulator, provider != nil {
            let endAction = CXEndCallAction(call: uuid)
            let transaction = CXTransaction(action: endAction)
            callController?.request(transaction) { error in
                if let error {
                    print("End call error: \(error)")
                }
            }
        }

        // Always reset local state immediately
        isCallActive = false
        callUUID = nil
    }
}

// MARK: - CXProviderDelegate

extension CallService: CXProviderDelegate {
    nonisolated func providerDidReset(_ provider: CXProvider) {
        Task { @MainActor in
            isCallActive = false
            callUUID = nil
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        configureAudioSession()
        action.fulfill()
        Task { @MainActor in
            isCallActive = true
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        configureAudioSession()
        action.fulfill()
        Task { @MainActor in
            isCallActive = true
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        action.fulfill()
        Task { @MainActor in
            isCallActive = false
            callUUID = nil
        }
    }

    nonisolated func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {}

    nonisolated func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {}

    // MARK: - Audio Session

    nonisolated private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker, .allowBluetoothA2DP]
            )
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }
}
