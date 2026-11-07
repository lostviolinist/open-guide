# Validation — 2026-11-06

## Automated checks

On an Apple Silicon Mac with Xcode 27 / Swift 6.4:

- SwiftPM builds the native executable and test targets successfully.
- 16 tests pass: 11 protocol/geometry/interaction tests and 5 provider integration tests using a stub HTTP transport.
- Tested rejection of unsupported versions, invalid coordinates, duplicate step IDs, unknown drawing commands, oversized payloads, invalid dwell, misplaced checkpoints, malformed provider geometry, and truncated model replies.
- Tested offset-display coordinate conversion, continuous hover dwell, and rejecting a held-button drag as a click.
- Tested valid tool-response decoding, missing-key prevention of network requests, and redacted provider authentication errors.
- The packaging script produces an ad-hoc signed `OpenGuide.app`; its signature verifies with `codesign --verify --deep --strict`.

## Native UI smoke checks

- Launched the packaged app and verified its menu-bar/control-window interface.
- Started region selection and verified Escape returns to the controls with “Selection cancelled.”
- Ran the offline demo through narration and its hover checkpoint.
- Observed the continuation and “Explanation complete” with all three narration notes retained.
- Local demo runs without an API key, screen capture, or microphone permission.
- Verified the Recheck fallback advances to the continuation, completes, and retains the drawing preview with narration.

## Still requires live validation

No real provider request was made and no API credentials were supplied for this build session. Live screenshot quality, model grounding, the provider round trip after real UI interaction, permission prompts, speech recognition hardware, and multi-monitor selection remain manual checks. The mocked tests do not establish live model quality or real screen-capture behavior.

Suggested manual check: configure your own key, select a harmless UI region, ask a simple question, complete one hover/click checkpoint, and verify the continued explanation reflects the new image. Test Stop during inference and narration, denial/regrant of screen permissions, and a secondary display placed to the left or above the primary display.

CI configuration is supplied as `docs/ci-workflow.example.yml` but is not active: the Git credential used for this repository cannot create Actions workflows. Local checks were completed directly.
