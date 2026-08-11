import AVFoundation
import Foundation
import Speech

/// Listens for German spoken answers (e.g. "die Sonne") using Apple Speech.
@MainActor
final class SpeechRecognitionService: NSObject, ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var transcript = ""
    @Published private(set) var authorizationDenied = false
    @Published private(set) var statusMessage: String?

    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))
    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var silenceTask: Task<Void, Never>?

    /// Called with the latest transcript and whether Speech marked the result final.
    var onTranscript: ((String, Bool) -> Void)?

    var isAvailable: Bool {
        ensureRecognizer().map(\.isAvailable) == true
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

        guard let recognizer = ensureRecognizer() else {
            statusMessage = "German speech recognition is not supported on this device."
            return
        }
        guard recognizer.isAvailable else {
            statusMessage = "German speech recognition is temporarily unavailable. Check network or try again."
            return
        }

        stopListening(resetTranscript: true)
        resetAudioEngine()

        do {
            try configureAudioSessionForRecognition()
        } catch {
            statusMessage = "Could not activate the microphone: \(error.localizedDescription)"
            return
        }

        // Touch input node only after the session is active.
        let inputNode = audioEngine.inputNode
        let hardwareFormat = inputNode.inputFormat(forBus: 0)
        guard hardwareFormat.sampleRate > 0, hardwareFormat.channelCount > 0 else {
            statusMessage = simulatorOrMicHint()
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        if #available(iOS 16, *) {
            request.addsPunctuation = false
        }
        // Helps the recognizer bias toward short German article answers.
        request.contextualStrings = ["der", "die", "das"]
        recognitionRequest = request

        let tapFormat = inputNode.outputFormat(forBus: 0)
        guard tapFormat.sampleRate > 0, tapFormat.channelCount > 0 else {
            statusMessage = simulatorOrMicHint()
            return
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: tapFormat) { buffer, _ in
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

                if let error, self.isListening {
                    let nsError = error as NSError
                    // Cancellation / no-speech end are expected when we stop intentionally.
                    let ignored = nsError.domain == "kAFAssistantErrorDomain" && (nsError.code == 216 || nsError.code == 203)
                    if !ignored, self.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.statusMessage = "Listening stopped: \(error.localizedDescription)"
                    }
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
            statusMessage = "Could not start the mic: \(error.localizedDescription)"
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

    private func ensureRecognizer() -> SFSpeechRecognizer? {
        if let speechRecognizer, speechRecognizer.locale.identifier.lowercased().hasPrefix("de") {
            return speechRecognizer
        }
        // Fallbacks if de-DE assets are missing.
        for identifier in ["de-DE", "de-AT", "de-CH", "de"] {
            if let candidate = SFSpeechRecognizer(locale: Locale(identifier: identifier)), candidate.isAvailable {
                speechRecognizer = candidate
                return candidate
            }
        }
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))
        return speechRecognizer
    }

    private func resetAudioEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.reset()
        audioEngine = AVAudioEngine()
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

    private func simulatorOrMicHint() -> String {
        #if targetEnvironment(simulator)
        return "Simulator mic is unavailable (common on iOS 17+). Please try on a real iPhone."
        #else
        return "Microphone is not ready yet. Tap Listen again, or check Settings → Der Die Das."
        #endif
    }
}
