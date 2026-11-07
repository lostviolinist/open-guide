# OpenGuide MVP architecture

OpenGuide is the root Swift package. It preserves the public Clicky repository as the licensed foundation, but the new executable does not link the legacy app, telemetry, updater, account services, worker, or branding assets.

## Components

| File | Responsibility |
| --- | --- |
| `Sources/GuideCore/GuideDocument.swift` | Codable v1 protocol, bounds/resource validation, coordinate mapping, dwell/click gate |
| `Sources/GuideCore/DemoGuide.swift` | Deterministic offline explanation fixtures |
| `Sources/OpenGuide/OpenGuideApp.swift` | Menu bar entry point and movable control/notes window |
| `Sources/OpenGuide/SelectionShortcut.swift` | Command–Shift–Space via Carbon hotkey registration |
| `Sources/OpenGuide/RegionSelector.swift` | Per-display drag selection and Escape cancellation |
| `Sources/OpenGuide/ScreenCaptureService.swift` | ScreenCaptureKit selected-region capture; adapts public Clicky filtering and display mapping |
| `Sources/OpenGuide/GuideSession.swift` | Cancellation-aware request/playback/interaction/recapture state machine |
| `Sources/OpenGuide/DrawingOverlay.swift` | Native click-through drawing canvas and offline playground |
| `Sources/OpenGuide/SpeechPlayer.swift` | AVSpeechSynthesizer playback coordinated with steps |
| `Sources/OpenGuide/VoiceInput.swift` | Optional, explicitly initiated on-device Apple Speech dictation |
| `Sources/OpenGuide/ModelProvider.swift` | Provider interface, Anthropic Messages adapter, tool schema, Keychain storage |
| `Sources/OpenGuide/GuideControlView.swift` | Controls, settings, errors, and in-memory session notes |
| `scripts/build-app.sh` | SwiftPM build, app bundle, local ad-hoc signing |

## Flow

1. User selects a region on one display; coordinates are retained in AppKit points.
2. User types or dictates a question, then chooses Explain selection.
3. ScreenCaptureKit captures that region with this process's windows excluded.
4. The provider receives a JPEG and the question, and returns one `show_guide` tool payload.
5. The host decodes and validates the complete document before displaying anything.
6. Each step replaces the marks and plays its narration. Speech completion advances the timeline; muted mode uses bounded reading time.
7. An optional final hover/click checkpoint waits for the user. Continuous hover dwell is required; dragging a held mouse button into a click target does not complete it.
8. The host clears marks, waits 600 ms, captures the same region again, and sends the latest document and original question as continuation context. Maximum five model rounds per request.
9. Stop invalidates the session generation, cancels networking/playback, and removes marks. Notes remain in memory until cleared or the app exits.

All screen geometry uses the selected display's actual AppKit frame, including negative display origins. Normalized coordinates use a top-left origin. Display layout changes stop the session and invalidate the selection.

## Trust boundaries

Model output is data. There is no eval, JavaScript bridge, shell tool, automatic click, browser control, or file access in the drawing protocol. Unknown command enum values and invalid documents are rejected. Extra JSON fields are ignored by Codable and cannot cause actions. The schema sent to the model disallows extra fields.

API keys are stored in Keychain. The executable contacts only the configured model through the fixed Anthropic endpoint. The model ID is editable, the destination URL is not. Screen images and notes are not persisted by OpenGuide. Live mode sends selected images to Anthropic; its service terms and retention apply. Offline demo sends nothing and requests no screen/microphone permissions.

## MVP limitations

- A full document arrives before playback; token-by-token drawing streaming is deferred.
- One selected region on one display per session. No accessibility-tree grounding yet.
- Speech is step-aligned, not word-timed stroke animation.
- Notes are in a movable native window, not individually pinnable cards.
- The target stays tied to a screen region. Moving or scrolling underlying content can make it stale; stop and reselect. Display layout changes are detected automatically.
- Hover/click observation triggers recapture; it does not prove the UI changed. The model must inspect the new image and acknowledge uncertainty.
- No live service call is necessary for tests. A user-supplied Anthropic key and macOS screen permission are needed to verify live explanations.
- Ad-hoc signed local development build; no notarized distribution or automatic updates.
