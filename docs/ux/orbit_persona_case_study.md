# Orbit Lite Persona Case Study

## 1. Context and Method
Orbit Lite currently behaves like a prototype control panel. This case study uses heuristic analysis of the existing Flutter and native overlay surfaces plus assumed product analytics patterns from notification-driven apps.

Method:
- UI heuristic audit of onboarding, settings discoverability, and event feedback loops.
- Flow decomposition for permission setup, live event display, queueing, and muting actions.
- Assumed telemetry baselines (drop-off by step, repeat settings changes, dismiss frequency) to define measurable UX outcomes.

Analytics assumptions used for this case study:
- Permission setup has the highest first-session drop-off.
- Overlays that appear without clear filtering controls increase dismiss rates.
- Users who tune placement and filtering within first week retain longer.

## 2. Persona Profiles
### Commuter Listener
- Goal: Instantly glance now-playing context while multitasking.
- Behaviors: Short sessions, quick interactions, minimal settings work.
- Constraints: Limited attention and time during movement.
- Trigger moments: Music starts, track changes.

### Deep-Work Professional
- Goal: Only urgent app notifications should interrupt focus.
- Behaviors: Strict filtering, low tolerance for noisy UI.
- Constraints: Cognitive interruption cost is high.
- Trigger moments: Work apps, high-priority messages.

### Social Responder
- Goal: Triage high-frequency social notifications quickly.
- Behaviors: Receives bursts, dismisses repetitive overlays.
- Constraints: Burst fatigue during active chat windows.
- Trigger moments: Group chat spikes and social message bursts.

### Control Seeker
- Goal: Fine-tune placement, visibility, and interaction behavior.
- Behaviors: Adjusts sliders/switches repeatedly.
- Constraints: Friction when advanced settings are buried.
- Trigger moments: Device change, orientation change, notched displays.

### Accessibility-First User
- Goal: Comfortable usage with scaled text and reduced motion.
- Behaviors: Uses larger system text and motion-reduced interfaces.
- Constraints: Motion sensitivity and readability needs.
- Trigger moments: New install, visual discomfort after interaction.

## 3. Current-State Friction Map
| Area | Current Friction | Affected Personas |
|---|---|---|
| Single monolithic page | Setup, diagnostics, and advanced controls are mixed | Commuter Listener, Deep-Work Professional |
| Permission acquisition | No guided step sequence or clear completion progression | Commuter Listener, Accessibility-First User |
| Notification filtering | App selection lacks confidence-building context | Deep-Work Professional, Social Responder |
| Overlay motion | Rotation/waveform can be excessive for sensitivity cases | Accessibility-First User |
| Advanced tuning | Placement and behavior controls are dense and not goal-ordered | Control Seeker |

## 4. Journey Maps
### Onboarding
1. Launch app.
2. See guided 3-step setup with explicit rationale.
3. Complete permission steps with visual progress.
4. Reach dashboard automatically when all permissions are granted.

Failure points addressed:
- Unclear next action.
- Missing success feedback.

### Music Event Journey
1. Music playback starts.
2. Compact overlay enters with title/source.
3. User can expand for controls.
4. Overlay persists or auto-dismisses based on setting.

Failure points addressed:
- Ambiguous music state transitions.
- Inconsistent restore behavior after interruptions.

### Notification Burst Journey
1. Multiple notifications arrive in short interval.
2. Queue applies max-3 and notification priority over music.
3. Compact overlay shows queued badge (+N).
4. User dismisses/mutes as needed.

Failure points addressed:
- Burst overload.
- No visibility into queued events.

### App Muting Journey
1. User expands notification overlay.
2. Taps `Mute` for source app.
3. App removed from allowed list immediately.
4. Future events from source are suppressed.

Failure points addressed:
- Low trust in filtering response.

### Permission Denial Recovery Journey
1. User denies permission.
2. Setup step remains visible with corrective action.
3. User opens settings deep link and returns.
4. Completion state updates in-flow.

Failure points addressed:
- Dead-end states after denial.

## 5. Persona-to-Requirement Traceability Matrix
| Requirement | Persona Link |
|---|---|
| Guided 3-step permission onboarding | Commuter Listener, Accessibility-First User |
| Dashboard with live status and quick actions | Commuter Listener, Social Responder |
| Searchable notification app selection sheet | Deep-Work Professional, Control Seeker |
| Queue cap 3 with notification preemption and +N badge | Social Responder, Deep-Work Professional |
| Reduced motion mode in Flutter and native overlays | Accessibility-First User |
| Real-time placement preview and reset defaults | Control Seeker |
| Analytics event taxonomy + diagnostics | All personas (validation layer) |

## 6. Prioritization Rubric
### P0
- Permission setup flow with progressive completion state.
- Hard-reset v2 event contract across native/Flutter.
- Queue semantics and preemption parity foreground/background.
- Reduced motion branch.

### P1
- Dashboard and settings split with clear IA.
- Searchable notification app picker.
- Control-chip interaction feedback and expand/collapse polish.

### P2
- Additional persona inference refinement from telemetry.
- Future experiment hooks for adaptive defaults.

## 7. Validation Plan
Telemetry-backed validation for persona hypotheses:

- Commuter Listener:
  - Metrics: `onboarding_started` -> full completion rate, time-to-first-overlay.
  - Target: setup completion under two minutes median.

- Deep-Work Professional:
  - Metrics: `notification_app_toggled`, dismiss rate per notification source.
  - Target: reduced unwanted overlay dismiss ratio.

- Social Responder:
  - Metrics: burst-trigger frequency vs dismiss count.
  - Target: fewer dismisses per burst session.

- Control Seeker:
  - Metrics: settings change sequence depth and repeat resets.
  - Target: reduced repetitive reset behavior.

- Accessibility-First User:
  - Metrics: reduced motion enabled adoption, completion under larger text scale tests.
  - Target: full task completion with reduced motion enabled.

Validation cadence:
- First release week: monitor onboarding and dismiss funnels.
- Week 2: compare burst session outcomes.
- Week 4: evaluate retention signals from settings personalization.
