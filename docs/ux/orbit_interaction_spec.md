# Orbit Lite Interaction and Motion Spec

## Product Surface Information Architecture
Orbit Lite is split into three surfaces:
- `SetupFlowScreen`: guided permissions and recovery.
- `OrbitDashboardScreen`: live status, quick trigger actions, now-live preview.
- `OrbitSettingsScreen`: behavior, placement, app filtering, analytics controls.

Navigation shell:
- `OrbitShellScaffold` bottom navigation.
- Setup destination appears only when required permissions are incomplete.

## Motion System
### Permission Setup Microinteractions
- Step completion confirmation: 180ms scale + fade.
- Step card transition: 220ms, `easeOutCubic`.
- Haptic: `HapticFeedback.lightImpact` once per newly completed step.

### Overlay Enter/Exit
- Music entry: 260ms, slide + scale, `easeOutCubic`.
- Notification entry: 280ms, slide + bounce, `easeOutBack` (unless reduced motion).
- Exit: 200ms, fade + upward slide, `easeInCubic`.

### Expand/Collapse
- Tap toggles expansion state.
- Expand/collapse duration: 180ms animated height.
- Expanded controls fade in with 50ms stagger.
- Swipe-up collapse threshold retained for expanded mode.

### Burst Handling
- Queue max: 3 events.
- Notification events preempt music event display.
- Compact notification UI shows `+N` badge for queued notifications.

### Reduced Motion
- Rotation and looping waveform disabled.
- Replace waveform with static pulse indicator at 1.2s cadence.
- Overshoot curves replaced with standard easing.

### Control Feedback
- Press opacity animation on chips:
  - press in: 90ms
  - release: 120ms
- Setting toggles update semantic labels immediately.

## Visual Direction: Premium Minimal
- Contrast-first dark overlay card with restrained gradients.
- Calm shadows and selective accent highlights.
- Typography hierarchy optimized for glanceability.

## UX Acceptance Behaviors
1. No dead-end permission state; each missing permission has a direct action.
2. Overlay behavior is consistent across in-app and native background surfaces.
3. Queue and preemption behavior is predictable during bursts.
4. Reduced motion fully disables continuous decorative motion.
