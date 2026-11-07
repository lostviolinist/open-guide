import AppKit
import SwiftUI
import GuideCore

@MainActor
final class GuideSession: ObservableObject {
    @Published var question = "What am I looking at, and how does it work?"
    @Published var model = UserDefaults.standard.string(forKey: "guide.model") ?? "claude-sonnet-4-6"
    @Published var speechEnabled = true
    @Published private(set) var status = "Ready when you are"
    @Published private(set) var selection: ScreenSelection?
    @Published private(set) var document: GuideDocument?
    @Published private(set) var currentStepIndex: Int?
    @Published private(set) var busy = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var isDemo = false
    @Published private(set) var isWaiting = false
    @Published private(set) var completedNarration: [String] = []
    let voiceInput = VoiceInput()
    var onShowControls: (() -> Void)?
    var onHideControls: (() -> Void)?
    private let overlay = DrawingOverlay()
    private let selector = RegionSelector()
    private let speech = SpeechPlayer()
    private let demoStage = DemoStage()
    private let provider: GuideModelProvider = AnthropicGuideProvider()
    private var activeTask: Task<Void, Never>?
    private var generation = UUID()
    private var screenObserver: NSObjectProtocol?
    private var demoRegion: CGRect?
    private var recheckRequested = false
    private var interactionObservation: String?

    init() {
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                                 object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.stop(); self?.selection = nil
                self?.status = "Display layout changed. Select a new region."
            }
        }
    }
    func selectRegion() {
        stop()
        demoStage.close()
        isDemo = false
        document = nil
        completedNarration = []
        status = "Drag to select · Esc to cancel"
        onHideControls?()
        selector.begin { [weak self] selection in
            guard let self else { return }
            self.selection = selection
            self.status = selection == nil ? "Selection cancelled" : "Region selected · ask a question"
            self.onShowControls?()
        }
    }
    func startDemo() {
        stop()
        isDemo = true
        selection = nil
        completedNarration = []
        let region = demoStage.show()
        demoRegion = region
        let token = generation
        busy = true
        activeTask = Task { [weak self] in
            guard let self else { return }
            do {
                let document = try GuideDocument.decode(Data(DemoGuide.introduction.utf8))
                try await self.play(document, region: region, token: token)
            } catch { self.handle(error, token: token) }
        }
    }
    func explainSelection() {
        guard let selection else { errorMessage = "Select a screen region first."; return }
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty, trimmedQuestion.count <= 4000 else { errorMessage = "Enter a question of 1–4000 characters."; return }
        stop()
        isDemo = false
        completedNarration = []
        let token = generation
        busy = true
        UserDefaults.standard.set(model, forKey: "guide.model")
        onHideControls?()
        activeTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.requestAndPlay(selection: selection, question: trimmedQuestion, previous: nil,
                                              interaction: nil, token: token, depth: 0)
            } catch { self.handle(error, token: token) }
        }
    }
    func stop() {
        generation = UUID()
        activeTask?.cancel()
        activeTask = nil
        speech.stop()
        voiceInput.stop()
        overlay.hide()
        isWaiting = false
        busy = false
        currentStepIndex = nil
        errorMessage = nil
        status = "Stopped · notes kept below"
    }
    func clearNotes() {
        stop()
        selector.cancel()
        demoStage.close()
        document = nil
        completedNarration = []
        demoRegion = nil
        status = "Ready when you are"
    }
    func reportError(_ message: String) { errorMessage = message }
    func beginDictation() {
        Task { [weak self] in
            guard let self else { return }
            await self.voiceInput.start(onText: { [weak self] in self?.question = $0 },
                                        onError: { [weak self] in self?.errorMessage = $0 })
        }
    }
    func advanceWithoutSpeech() { speech.stop() }
    func recheckContext() {
        guard isWaiting else { return }
        recheckRequested = true
    }

    private func requestAndPlay(selection: ScreenSelection, question: String, previous: GuideDocument?,
                                interaction: String?, token: UUID, depth: Int) async throws {
        guard depth < 5 else { throw GuideAppError("This walkthrough reached five rounds. Ask a new question to continue.") }
        try check(token)
        status = interaction == nil ? "Capturing your selection…" : "Observing the revealed context…"
        overlay.hide()
        let image = try await ScreenCaptureService.capture(selection)
        try check(token)
        status = "Building your explanation…"
        let document = try await provider.explain(image: image, question: question, previous: previous,
                                                   interaction: interaction, model: model)
        try check(token)
        try await play(document, region: selection.region, token: token, continuation: false)
        if let interaction = document.steps.last?.interaction {
            try check(token)
            overlay.hide()
            status = "Interaction observed · refreshing selection…"
            try await Task.sleep(nanoseconds: 600_000_000)
            try await requestAndPlay(selection: selection, question: question, previous: document,
                                     interaction: interactionObservation ?? interaction.label, token: token, depth: depth + 1)
        }
    }
    private func play(_ document: GuideDocument, region: CGRect, token: UUID, continuation: Bool = true) async throws {
        try document.validate()
        try check(token)
        self.document = document
        for (index, step) in document.steps.enumerated() {
            try check(token)
            currentStepIndex = index
            status = "Step \(index + 1) of \(document.steps.count)"
            overlay.show(marks: step.marks, interaction: nil, region: region)
            completedNarration.append(step.narration)
            if speechEnabled {
                await speech.speak(step.narration)
            } else {
                try await Task.sleep(nanoseconds: UInt64(min(12, max(3, Double(step.narration.count) / 22))) * 1_000_000_000)
            }
            try check(token)
            if let interaction = step.interaction {
                overlay.show(marks: step.marks, interaction: interaction, region: region)
                isWaiting = true
                status = interaction.label
                try await waitForInteraction(interaction, region: region, token: token)
                isWaiting = false
            }
        }
        try check(token)
        if isDemo && continuation && document.steps.last?.interaction != nil {
            overlay.hide()
            let next = try GuideDocument.decode(Data(DemoGuide.continuation.utf8))
            try await play(next, region: region, token: token, continuation: false)
        } else if document.steps.last?.interaction == nil {
            overlay.hide()
            busy = false
            currentStepIndex = nil
            status = "Explanation complete · notes kept below"
            onShowControls?()
        }
    }
    private func waitForInteraction(_ interaction: GuideInteraction, region: CGRect, token: UUID) async throws {
        var gate = InteractionGate()
        recheckRequested = false
        interactionObservation = nil
        let target = interaction.target.appKitFrame(in: region)
        let deadline = ProcessInfo.processInfo.systemUptime + 90
        // Seed button state so a click already held when narration finishes cannot complete a step.
        _ = gate.update(inside: false, mouseDown: NSEvent.pressedMouseButtons & 1 != 0,
                        time: ProcessInfo.processInfo.systemUptime, kind: interaction.kind,
                        dwellMilliseconds: interaction.dwellMilliseconds)
        while ProcessInfo.processInfo.systemUptime < deadline {
            try check(token)
            if recheckRequested {
                interactionObservation = "The user requested a new observation. The target interaction was not verified: " + interaction.label
                return
            }
            let completed = gate.update(inside: target.contains(NSEvent.mouseLocation),
                mouseDown: NSEvent.pressedMouseButtons & 1 != 0, time: ProcessInfo.processInfo.systemUptime,
                kind: interaction.kind, dwellMilliseconds: interaction.dwellMilliseconds)
            if completed {
                interactionObservation = "Observed a " + interaction.kind.rawValue + " at the target: " + interaction.label
                return
            }
            try await Task.sleep(nanoseconds: 40_000_000)
        }
        throw GuideAppError("The interaction timed out. Select the region again if the screen moved.")
    }
    private func check(_ token: UUID) throws {
        try Task.checkCancellation()
        guard generation == token else { throw CancellationError() }
    }
    private func handle(_ error: Error, token: UUID) {
        guard generation == token, !(error is CancellationError) else { return }
        overlay.hide()
        speech.stop()
        busy = false
        isWaiting = false
        currentStepIndex = nil
        errorMessage = error.localizedDescription
        status = "Needs your attention"
        onShowControls?()
    }
}
