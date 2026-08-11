import AVFoundation
import Foundation
import Speech

/// Listens for German spoken answers (e.g. "die Sonne") using on-device / Apple Speech.
@MainActor
final class SpeechRecognitionService: NSObject, ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var transcript = ""
    @Published private(set) var authorizationDenied = false
    @Published private(set) var statusMessage: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var silenceTask: Task<Void, Never>?

    /// Called with the latest transcript and whether Speech marked the result final.
    var onTranscript: ((String, Bool) -> Void)?

    var isAvailable: Bool {
        recognizer?.isAvailable == true
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        let status = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }

        switch status {
        case .authorized:
            let mic = await requestMicrophoneAccess()
            authorizationDenied = !mic
            statusMessage = mic ? nil : "Microphone access is required to answer out loud."
            return mic
        case .denied, .restricted:
            authorizationDenied = true
            statusMessage = "Enable Speech Recognition and Microphone in Settings to answer out loud."
            return false
        case .notDetermined:
            authorizationDenied = true
            statusMessage = "Speech recognition permission is required."
            return false
        @unknown default:
            authorizationDenied = true
            statusMessage = "Speech recognition is unavailable."
            return false
        }
    }

    func startListening() async {
        guard !isListening else { return }
        guard await requestAuthorizationIfNeeded() else { return }
        guard let recognizer, recognizer.isAvailable else {
            statusMessage = "German speech recognition is unavailable on this device."
            return
        }

        stopListening(resetTranscript: true)

        do {
            try configureAudioSessionForRecognition()
        } catch {
            statusMessage = "Could not start the microphone."
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        if #available(iOS 16, *) {
            request.addsPunctuation = false
        }
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    self.transcript = text
                    self.onTranscript?(text, result.isFinal)
                    if result.isFinal {
                        self.stopListening(resetTranscript: false)
                    } else {
                        self.scheduleSilenceFinalize(after: 1.1)
                    }
                }
                if error != nil, self.isListening {
                    // End of utterance / cancellation is normal; keep last transcript.
                    self.stopListening(resetTranscript: false)
                }
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
            statusMessage = nil
        } catch {
            stopListening(resetTranscript: true)
            statusMessage = "Could not start listening."
        }
    }

    func stopListening(resetTranscript: Bool) {
        silenceTask?.cancel()
        silenceTask = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
        if resetTranscript {
            transcript = ""
        }
    }

    private func scheduleSilenceFinalize(after delay: TimeInterval) {
        silenceTask?.cancel()
        let snapshot = transcript
        silenceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            guard self.isListening, self.transcript == snapshot, !snapshot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }
            self.onTranscript?(snapshot, true)
            self.stopListening(resetTranscript: false)
        }
    }

    private func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
    }

    private func configureAudioSessionForRecognition() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }
}
