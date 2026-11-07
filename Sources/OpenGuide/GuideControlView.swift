import SwiftUI
import AppKit

struct GuideControlView: View {
    @ObservedObject var session: GuideSession
    @State private var showingSettings = false
    private let accent = Color(red: 0.46, green: 0.89, blue: 0.72)
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "sparkle.magnifyingglass").font(.system(size: 24)).foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("OpenGuide").font(.system(size: 23, weight: .semibold, design: .rounded))
                    Text("A little clarity, right here.").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button { showingSettings.toggle() } label: { Image(systemName: "slider.horizontal.3") }
                    .buttonStyle(GuideButtonStyle()).help("Settings")
                    .accessibilityLabel("Settings")
            }.padding(24)
            Divider().opacity(0.4)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 8) {
                        Circle().fill(session.busy ? accent : .secondary).frame(width: 7, height: 7)
                        Text(session.status).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                        Spacer()
                        if session.isDemo { Text("LOCAL DEMO").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(accent) }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Make sense of what's on screen.").font(.system(size: 27, weight: .medium, design: .rounded))
                        Text("Select a region. Ask a question. Follow an explanation that points the way.")
                            .font(.system(size: 14)).foregroundStyle(.secondary).lineSpacing(4)
                    }
                    HStack {
                        Button { session.selectRegion() } label: {
                            Label(session.selection == nil ? "Select a region" : "Change selection", systemImage: "viewfinder")
                        }.buttonStyle(GuideButtonStyle(prominent: true))
                        Spacer()
                        Text("⌘ ⇧ Space").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                    }
                    if let selection = session.selection {
                        Text("Selected \(Int(selection.region.width)) × \(Int(selection.region.height)) pt")
                            .font(.caption).foregroundStyle(accent)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("YOUR QUESTION").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                        TextEditor(text: $session.question)
                            .font(.system(size: 14)).scrollContentBackground(.hidden)
                            .frame(height: 72).padding(10)
                            .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1)))
                            .accessibilityLabel("Your question")
                        HStack {
                            DictationButton(session: session, voice: session.voiceInput)
                            Spacer()
                            Button("Explain selection") { session.explainSelection() }
                                .buttonStyle(GuideButtonStyle(prominent: true))
                                .disabled(session.selection == nil || session.busy)
                        }
                        Text("Live mode sends the selected region and your question to Anthropic using your own API key.")
                            .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    if let error = session.errorMessage {
                        Label(error, systemImage: "exclamationmark.circle")
                            .font(.system(size: 12)).foregroundStyle(.orange)
                            .padding(12).background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }
                    if session.busy {
                        HStack {
                            ProgressView().controlSize(.small)
                            Button("Stop") { session.stop() }.buttonStyle(GuideButtonStyle())
                            if session.isWaiting {
                                Button("Recheck") { session.recheckContext() }.buttonStyle(GuideButtonStyle())
                                    .help("Capture the selected region again even if the hover or click was not detected")
                            } else {
                                Button("Skip speech") { session.advanceWithoutSpeech() }.buttonStyle(GuideButtonStyle())
                            }
                        }
                    }
                    Divider().opacity(0.4)
                    if session.completedNarration.isEmpty {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "play.rectangle.on.rectangle").font(.title2).foregroundStyle(accent)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Try it before connecting a model.").font(.system(size: 14, weight: .medium))
                                Text("A guided local playground. No key, capture, or network needed.").font(.system(size: 12)).foregroundStyle(.secondary)
                                Button("Run local demo") { session.startDemo() }.buttonStyle(GuideButtonStyle())
                            }
                        }
                    } else {
                        HStack {
                            Text("\(session.document?.title ?? "Session notes")").font(.headline)
                            Spacer()
                            Button("Clear") { session.clearNotes() }.buttonStyle(GuideButtonStyle())
                        }
                        if let document = session.document, !document.steps.isEmpty {
                            let step = document.steps[session.currentStepIndex ?? (document.steps.count - 1)]
                            DrawingCanvas(marks: step.marks, interaction: step.interaction)
                                .frame(height: 150)
                                .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
                                .overlay(alignment: .bottomLeading) {
                                    Text("DRAWING PREVIEW").font(.system(size: 8, design: .monospaced)).foregroundStyle(.secondary).padding(8)
                                }
                        }
                        ForEach(Array(session.completedNarration.enumerated()), id: \.offset) { index, narration in
                            HStack(alignment: .top, spacing: 12) {
                                Text(String(format: "%02d", index + 1)).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(accent)
                                Text(narration).font(.system(size: 13)).lineSpacing(4).textSelection(.enabled)
                            }
                        }
                        Button("Run demo again") { session.startDemo() }.buttonStyle(GuideButtonStyle())
                    }
                }.padding(24)
            }
            Divider().opacity(0.4)
            HStack {
                Text("OPEN SOURCE · BUILT FOR macOS").font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }.buttonStyle(GuideButtonStyle())
            }.padding(.horizontal, 24).padding(.vertical, 12)
        }
        .background(Color(red: 0.055, green: 0.075, blue: 0.1))
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingSettings) { GuideSettingsView(session: session) }
    }
}

private struct DictationButton: View {
    @ObservedObject var session: GuideSession
    @ObservedObject var voice: VoiceInput
    var body: some View {
        Button {
            if voice.isRecording { voice.stop() } else { session.beginDictation() }
        } label: {
            Label(voice.isRecording ? "Finish dictation" : "Dictate", systemImage: voice.isRecording ? "stop.circle" : "mic")
        }.buttonStyle(GuideButtonStyle()).disabled(session.busy)
    }
}

struct GuideButtonStyle: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .semibold)).padding(.horizontal, 12).padding(.vertical, 9)
            .foregroundStyle(prominent ? Color.black : Color.white.opacity(0.85))
            .background(prominent ? Color.mint.opacity(configuration.isPressed ? 0.65 : 0.9) : Color.white.opacity(configuration.isPressed ? 0.15 : 0.07), in: RoundedRectangle(cornerRadius: 8))
            .onHover { hovering in if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
    }
}

private struct GuideSettingsView: View {
    @ObservedObject var session: GuideSession
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""
    @State private var message = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Make it yours").font(.title2.bold())
            Text("Your key stays in macOS Keychain. Screen images are held in memory and sent only during live explanations and their interaction follow-ups.")
                .font(.callout).foregroundStyle(.secondary)
            SecureField("Anthropic API key", text: $apiKey).textFieldStyle(.roundedBorder)
            HStack {
                Button("Save key") {
                    do { try GuideKeychain.save(apiKey); apiKey = ""; message = "Saved in Keychain." }
                    catch { message = error.localizedDescription }
                }.buttonStyle(GuideButtonStyle(prominent: true))
                Button("Remove saved key") {
                    do { try GuideKeychain.remove(); message = "Removed from Keychain." }
                    catch { message = error.localizedDescription }
                }.buttonStyle(GuideButtonStyle())
            }
            TextField("Model ID", text: $session.model).textFieldStyle(.roundedBorder)
            Toggle("Speak explanations", isOn: $session.speechEnabled)
            Text("Dictation uses Apple's on-device recognition when available. You can always type instead.").font(.caption).foregroundStyle(.secondary)
            Text(message).font(.caption).foregroundStyle(.mint)
            HStack { Spacer(); Button("Done") { dismiss() }.buttonStyle(GuideButtonStyle()) }
        }.padding(28).frame(width: 440).preferredColorScheme(.dark)
    }
}
