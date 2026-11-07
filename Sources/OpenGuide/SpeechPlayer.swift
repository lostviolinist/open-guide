import AVFoundation

@MainActor
final class SpeechPlayer: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var currentUtterance: AVSpeechUtterance?
    private var completion: CheckedContinuation<Void, Never>?
    override init() { super.init(); synthesizer.delegate = self }
    func speak(_ text: String) async {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.48
        currentUtterance = utterance
        await withCheckedContinuation { continuation in
            completion = continuation
            synthesizer.speak(utterance)
        }
    }
    func stop() {
        // Resolve before stopping: cancellation callbacks must never resolve a later utterance.
        let pending = completion
        completion = nil
        currentUtterance = nil
        synthesizer.stopSpeaking(at: .immediate)
        pending?.resume()
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, self.currentUtterance === utterance else { return }
            let pending = self.completion
            self.completion = nil
            self.currentUtterance = nil
            pending?.resume()
        }
    }
}
