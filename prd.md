Good. Narrow scope = better execution.

We’re not building a full Dynamic Island clone.

We’re building a Reactive Live Animation Overlay triggered only by:
	1.	🎵 Music playback
	2.	🔔 Notifications from selected apps

Everything else is out of scope.

⸻

📄 Product Requirements Document

Product Name: Orbit Lite

Android Reactive Music & Notification Animation Overlay

⸻

1. Product Overview

Orbit Lite is a lightweight Android overlay that displays a compact animated pill at the top of the screen when:
	•	Music starts playing
	•	A notification is received from selected apps

It does not replace notifications.
It enhances them with a smooth, glanceable animation.

The system is event-triggered, not persistent.

⸻

2. Problem Statement

Current Android notifications are functional but visually static.

Users want:
	•	Subtle, modern feedback when music starts
	•	A premium animation when important notifications arrive
	•	A glanceable surface that feels alive

But without:
	•	Heavy battery drain
	•	Complex persistent UI
	•	Always-on overlay clutter

⸻

3. Scope

✅ In Scope (Strict)
	•	Detect music playback state
	•	Detect notifications from selected apps
	•	Show a compact animated overlay
	•	Auto-dismiss after animation
	•	Minimal interaction (tap to expand optional)
	•	Lightweight foreground service

❌ Out of Scope
	•	Calls
	•	Timers
	•	Navigation
	•	Lock screen
	•	Multi-activity stacking
	•	AI prioritization
	•	Developer SDK
	•	Full expandable dynamic island
	•	Full notification replacement

This is animation-only with light contextual info.

⸻

4. Feature Definition

4.1 Music Trigger

Trigger Condition:
	•	Media session changes to PLAYING state

Behavior:
	•	Animated pill slides in from top
	•	Show:
	•	Song title
	•	App icon
	•	Play waveform animation
	•	Stay visible for:
	•	3–5 seconds (configurable)
	•	Auto-collapse

If music pauses:
	•	Small fade-out animation

⸻

4.2 Notification Trigger

Trigger Condition:
	•	Notification received from user-selected apps

Behavior:
	•	Pill slides in
	•	Show:
	•	App icon
	•	Notification title
	•	Optional short preview (1 line max)
	•	Soft bounce animation
	•	Auto-dismiss after 4 seconds

No persistent state retained.

⸻

5. User Stories

Music
	•	As a user, when I start music, I see a smooth animation at the top.
	•	As a user, when the track changes, I see a subtle refresh animation.

Notifications
	•	As a user, when Instagram sends a message, I see a clean animated alert.
	•	As a user, only selected apps trigger animation.

⸻

6. Technical Architecture

Overview

Android System Events
        ↓
Kotlin Foreground Service
        ↓
Flutter UI Overlay
        ↓
Animation Controller


⸻

6.1 Native Layer (Kotlin)

Responsibilities:
	•	MediaSession listener
	•	NotificationListenerService
	•	Filter selected apps
	•	Send event data to Flutter via MethodChannel

Required Permissions:
	•	BIND_NOTIFICATION_LISTENER_SERVICE
	•	FOREGROUND_SERVICE
	•	SYSTEM_ALERT_WINDOW

Core Components:
	•	OrbitEventService
	•	MediaSessionObserver
	•	NotificationObserver

⸻

6.2 Flutter Layer

Responsibilities:
	•	Render pill overlay
	•	Animate entry/exit
	•	Render text and icon
	•	Auto-dismiss logic

Core Widgets:
	•	OverlayEntry
	•	AnimatedContainer
	•	SlideTransition
	•	FadeTransition
	•	StreamController for event updates

Animation Specs:
	•	Duration: 250–350ms
	•	Curve: EaseOutCubic
	•	Frame target: 60fps

⸻

7. UI Specifications

Pill Dimensions
	•	Height: 40dp
	•	Min width: 120dp
	•	Max width: 80% screen width
	•	Rounded radius: 24dp

Position
	•	Top center
	•	Respect status bar padding
	•	Avoid notch area if detected

⸻

Music Visual Treatment

Compact Mode:
	•	App icon (left)
	•	Song title (center)
	•	Animated waveform (right)

Animation:
	•	Slide down + scale up
	•	Waveform loops while visible

⸻

Notification Visual Treatment

Compact Mode:
	•	App icon
	•	Title
	•	Short preview

Animation:
	•	Slide down
	•	Slight bounce
	•	Subtle glow pulse

⸻

8. Performance Requirements
	•	Animation must not drop below 55fps
	•	Memory usage under 120MB
	•	Service CPU idle usage under 2%
	•	No wake locks
	•	Event-driven architecture only

⸻

9. Battery Constraints
	•	Foreground service required only for listeners
	•	No polling
	•	No continuous animation when hidden
	•	Overlay destroyed after animation completes

⸻

10. Edge Cases
	•	Rapid notification bursts → queue max 3
	•	Music + notification simultaneously → prioritize notification
	•	Screen off → do not show animation
	•	Fullscreen video → optional suppression (V2)

⸻

11. Settings (Minimal)
	•	Toggle music animation
	•	Select notification apps
	•	Animation duration slider
	•	Enable/disable overlay

No advanced customization.

⸻

12. Milestones

Phase 1 – Flutter UI Prototype
	•	Static animation
	•	Mock data triggers

Phase 2 – Media Session Integration
	•	Detect music playback
	•	Render live song info

Phase 3 – Notification Listener
	•	Filter selected apps
	•	Animate correctly

Phase 4 – Optimization & Battery Testing

⸻

13. Definition of Done

Product is complete when:
	•	Music from Spotify triggers animation
	•	Notification from WhatsApp triggers animation
	•	Animation is smooth
	•	Service runs 24h without crash
	•	No noticeable battery drain

⸻

14. Technical Decision Justification

Flutter is used because:
	•	Complex animation is easier
	•	UI iteration is fast
	•	Consistent rendering across devices

Kotlin is required because:
	•	MediaSession API access
	•	NotificationListenerService access
	•	Overlay permission handling

⸻

15. Future Expansion Path (Not Now)
	•	Expandable view
	•	Persistent compact mode
	•	Interaction buttons
	•	Smart priority logic

