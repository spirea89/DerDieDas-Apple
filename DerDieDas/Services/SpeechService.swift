import AudioToolbox
import AVFoundation
import Foundation

@MainActor
final class SpeechService: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var speakContinuation: CheckedContinuation<Void, Never>?
    private var speakTimeoutTask: Task<Void, Never>?
    private var cuePlayer: AVAudioPlayer?
    private var cueContinuation: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
        prepareSpeakCue()
    }

    func speakGerman(_ prompt: String, rateMultiplier: Float = 0.88) async {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        synthesizer.stopSpeaking(at: .immediate)
        finishSpeakWait()
        configureAudioSessionForPlayback()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            speakContinuation = continuation
            let utterance = AVSpeechUtterance(string: prompt)
            utterance.voice = preferredGermanVoice()
            let clamped = min(max(rateMultiplier, 0.5), 1.2)
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * clamped
            utterance.pitchMultiplier = 1.02
            utterance.volume = 1.0
            synthesizer.speak(utterance)

            // Never block the game forever if the synthesizer fails to callback.
            speakTimeoutTask?.cancel()
            let timeoutNs = UInt64((6.0 / Double(clamped)) * 1_000_000_000)
            speakTimeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: timeoutNs)
                await MainActor.run {
                    self?.finishSpeakWait()
                }
            }
        }
    }

    func speakGerman(_ prompt: String, rateMultiplier: Float = 0.88) {
        Task { await speakGerman(prompt, rateMultiplier: rateMultiplier) }
    }

    /// Short chime meaning: mic is about to open — say the article + word now.
    func playSpeakCue() async {
        configureAudioSessionForPlayback()
        guard let player = cuePlayer else {
            // Fallback beep via system sound if the bundled cue is missing.
            AudioServicesPlaySystemSound(1057)
            try? await Task.sleep(nanoseconds: 220_000_000)
            return
        }

        player.stop()
        player.currentTime = 0
        player.volume = 1.0

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            cueContinuation?.resume()
            cueContinuation = continuation
            player.play()
            // Safety timeout slightly longer than the cue.
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 500_000_000)
                await MainActor.run {
                    self?.finishCueWait()
                }
            }
        }
        // Tiny beat so the ding has settled before the mic opens.
        try? await Task.sleep(nanoseconds: 120_000_000)
    }

    func cancel() {
        speakTimeoutTask?.cancel()
        speakTimeoutTask = nil
        synthesizer.stopSpeaking(at: .immediate)
        finishSpeakWait()
        cuePlayer?.stop()
        finishCueWait()
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

    private func finishCueWait() {
        guard let continuation = cueContinuation else { return }
        cueContinuation = nil
        continuation.resume()
    }

    private func prepareSpeakCue() {
        guard let url = Bundle.main.url(forResource: "speak-cue", withExtension: "wav") else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            cuePlayer = player
        } catch {
            cuePlayer = nil
        }
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

extension SpeechService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.finishCueWait()
        }
    }
}
