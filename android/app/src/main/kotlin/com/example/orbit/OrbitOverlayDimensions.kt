package com.example.orbit

data class OrbitOverlayDimensions(
    val horizontalOffsetPx: Int = 0,
    val verticalOffsetPx: Int = 0,
    val zAxisPx: Int = 0,
    val anchorMode: String = "top_safe_lane",
    val lanePreset: String = "balanced",
    val compactWidthFactor: Float = 0.42f,
    val compactHeightDp: Int = 52,
    val expandedWidthFactor: Float = 0.74f,
    val musicExpandedHeightDp: Int = 196,
    val notificationExpandedHeightDp: Int = 140,
)
