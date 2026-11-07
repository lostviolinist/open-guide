import AVFoundation
import Speech

@MainActor
final class VoiceInput: ObservableObject {
    @Published private(set) var isRecording = false
    private let engine = AVAudioEngine()
    private var recognitionTask: SFSpeechRecognitionTask?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var generation = UUID()
    private var hasTap = false

    func start(onText: @escaping (String) -> Void, onError: @escaping (String) -> Void) async {
        stop()
        let token = UUID()
        generation = token
        let microphoneAllowed = await AVCaptureDevice.requestAccess(for: .audio)
        let speechAllowed = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        guard generation == token else { return }
        guard microphoneAllowed && speechAllowed else { onError("Allow Microphone and Speech Recognition in System Settings, or type your question."); return }
        guard let recognizer = SFSpeechRecognizer(locale: .current), recognizer.isAvailable,
              recognizer.supportsOnDeviceRecognition else {
            onError("On-device dictation is unavailable for this language. Type your question instead."); return
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        self.request = request
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { onError("No microphone is available."); return }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
        hasTap = true
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self, self.generation == token else { return }
                if let result { onText(result.bestTranscription.formattedString) }
                if let error { self.stop(); onError(error.localizedDescription) }
            }
        }
        do { engine.prepare(); try engine.start(); isRecording = true }
        catch { stop(); onError(error.localizedDescription) }
    }
    func stop() {
        generation = UUID()
        engine.stop()
        if hasTap { engine.inputNode.removeTap(onBus: 0); hasTap = false }
        request?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        request = nil
        isRecording = false
    }
}
