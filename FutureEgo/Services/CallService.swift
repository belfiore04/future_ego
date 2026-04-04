import CallKit
import AVFoundation
import SwiftUI

@MainActor
class CallService: NSObject, ObservableObject {
    static let shared = CallService()

    @Published var isCallActive = false
    @Published var callUUID: UUID?

    private let provider: CXProvider
    private let callController = CXCallController()

    override init() {
        let config = CXProviderConfiguration()
        config.supportsVideo = false
        config.maximumCallsPerCallGroup = 1
        config.supportedHandleTypes = [.generic]

        provider = CXProvider(configuration: config)
        super.init()
        provider.setDelegate(self, queue: nil)
    }

    // MARK: - Outgoing Call (user taps phone button)

    func startCall() {
        let uuid = UUID()
        callUUID = uuid

        let handle = CXHandle(type: .generic, value: "Future Ego")
        let startAction = CXStartCallAction(call: uuid, handle: handle)
        startAction.isVideo = false
        startAction.contactIdentifier = "AI Coach"

        let transaction = CXTransaction(action: startAction)
        callController.request(transaction) { error in
            if let error {
                print("Start call error: \(error)")
            }
        }

        // Mark as connected after brief delay (simulates "dialing")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            self.provider.reportOutgoingCall(with: uuid, connectedAt: nil)
        }
    }

    // MARK: - Incoming Call (triggered by morning/evening alarm)

    func reportIncomingCall(reason: String = "AI Coach") {
        let uuid = UUID()
        callUUID = uuid

        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: reason)
        update.localizedCallerName = "Future Ego"
        update.hasVideo = false
        update.supportsGrouping = false
        update.supportsHolding = false

        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error {
                print("Report incoming call error: \(error)")
            }
        }
    }

    // MARK: - End Call

    func endCall() {
        guard let uuid = callUUID else { return }
        let endAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endAction)
        callController.request(transaction) { error in
            if let error {
                print("End call error: \(error)")
            }
        }
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
        // User answered incoming call
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

    nonisolated func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        // Called by the system after CallKit activates the audio session.
        // Audio hardware is now available for recording / playback.
    }

    nonisolated func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        // Called by the system after CallKit deactivates the audio session.
    }

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
