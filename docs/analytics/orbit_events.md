# Orbit Lite Analytics Event Taxonomy

All events are routed through `OrbitAnalytics` and gated by `analytics_enabled` user setting.

## Common Properties
Every event includes:
- `persona_context`
- `session_id`
- `app_in_foreground`
- `permission_state_snapshot`

## Event Definitions
1. `onboarding_started`
- Trigger: setup screen first shown in session.

2. `onboarding_step_completed`
- Properties: `step_key` (`post_notifications`, `notification_access`, `overlay_permission`).

3. `permission_grant_result`
- Properties: `permission_key`, `granted`.

4. `dashboard_viewed`
- Trigger: dashboard becomes active destination.

5. `overlay_event_received`
- Properties: `kind`, `source_package`, `priority`.

6. `overlay_event_displayed`
- Properties: `kind`, `queue_state`, `display_ms`.

7. `overlay_event_dismissed`
- Properties: `kind`, `reason` (`timeout`, `user_dismiss`, `preempted`, `paused`).

8. `overlay_expanded`
- Properties: `kind`, `expanded`.

9. `notification_app_toggled`
- Properties: `source_package`, `selected`.

10. `settings_changed`
- Properties: `setting_key`, `old_value`, `new_value`.

11. `burst_test_triggered`
- Properties: `count`.

12. `overlay_error`
- Properties: `stage`, `message`.

13. `profile_changed`
- Properties: `profile_id`, `source`.

14. `lane_calibration_opened`
- Properties: `source`.

15. `lane_calibration_saved`
- Properties: `lane_preset`, `offset_y_px`.

16. `setup_wizard_completed`
- Properties: `selected_profile`.

17. `advanced_settings_opened`
- Trigger: user switches to advanced settings pane.
