import AVFoundation
import Foundation

@MainActor
final class SpeechService: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var speakContinuation: CheckedContinuation<Void, Never>?
    private var speakTimeoutTask: Task<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speakGerman(_ prompt: String) async {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        synthesizer.stopSpeaking(at: .immediate)
        finishSpeakWait()
        configureAudioSessionForPlayback()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            speakContinuation = continuation
            let utterance = AVSpeechUtterance(string: prompt)
            utterance.voice = preferredGermanVoice()
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.88
            utterance.pitchMultiplier = 1.02
            utterance.volume = 1.0
            synthesizer.speak(utterance)

            // Never block the game forever if the synthesizer fails to callback.
            speakTimeoutTask?.cancel()
            speakTimeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                await MainActor.run {
                    self?.finishSpeakWait()
                }
            }
        }
    }

    func speakGerman(_ prompt: String) {
        Task { await speakGerman(prompt) }
    }

    func cancel() {
        speakTimeoutTask?.cancel()
        speakTimeoutTask = nil
        synthesizer.stopSpeaking(at: .immediate)
        finishSpeakWait()
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.finishSpeakWait()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.finishSpeakWait()
        }
    }

    private func finishSpeakWait() {
        speakTimeoutTask?.cancel()
        speakTimeoutTask = nil
        speakContinuation?.resume()
        speakContinuation = nil
    }

    private func configureAudioSessionForPlayback() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .duckOthers])
            try session.setActive(true, options: [])
        } catch {
            // Playback may still work with the existing session.
        }
    }

    private func preferredGermanVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("de") }
        if let enhanced = voices.first(where: { $0.quality == .enhanced }) {
            return enhanced
        }
        return AVSpeechSynthesisVoice(language: "de-DE") ?? voices.first
    }
}
