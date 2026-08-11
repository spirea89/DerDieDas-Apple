import AVFoundation
import Foundation

@MainActor
final class SpeechService {
    private let synthesizer = AVSpeechSynthesizer()
    private var didConfigureSession = false

    func speakGerman(_ prompt: String) {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        synthesizer.stopSpeaking(at: .immediate)
        configureAudioSessionIfNeeded()

        let utterance = AVSpeechUtterance(string: prompt)
        utterance.voice = preferredGermanVoice()
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.88
        utterance.pitchMultiplier = 1.02
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }

    func cancel() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func configureAudioSessionIfNeeded() {
        guard !didConfigureSession else {
            try? AVAudioSession.sharedInstance().setActive(true, options: [])
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: [])
            didConfigureSession = true
        } catch {
            didConfigureSession = false
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
