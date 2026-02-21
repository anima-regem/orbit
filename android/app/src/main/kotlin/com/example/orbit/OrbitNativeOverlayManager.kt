package com.example.orbit

import android.animation.ObjectAnimator
import android.animation.ValueAnimator
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.TextUtils
import android.util.Base64
import android.util.TypedValue
import android.view.Gravity
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.view.animation.LinearInterpolator
import android.view.animation.OvershootInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.PI
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

class OrbitNativeOverlayManager(private val context: Context) {
    companion object {
        private const val COMPACT_MIN_WIDTH_DP = 170
        private const val EXPANDED_MIN_WIDTH_DP = 228

        private val FALLBACK_NEON_COLORS = intArrayOf(
            Color.parseColor("#00E5FF"),
            Color.parseColor("#FF3D9A"),
        )
    }

    private val appContext = context.applicationContext
    private val mainHandler = Handler(Looper.getMainLooper())
    private val windowManager = appContext.getSystemService(WindowManager::class.java)

    private var rootView: FrameLayout? = null
    private var borderShell: FrameLayout? = null
    private var cardView: LinearLayout? = null

    private var headerRow: LinearLayout? = null
    private var headerLeading: ImageView? = null
    private var headerLeadingShape: GradientDrawable? = null
    private var headerGapStart: View? = null
    private var headerTextContainer: LinearLayout? = null
    private var headerPrimaryText: TextView? = null
    private var headerSecondaryText: TextView? = null
    private var headerMusicSpacer: View? = null
    private var headerGapEnd: View? = null
    private var headerDot: View? = null
    private var headerWaveContainer: LinearLayout? = null
    private var headerWaveBars: List<View> = emptyList()
    private var headerWaveBarShapes: List<GradientDrawable> = emptyList()

    private var expandedSection: LinearLayout? = null
    private var expandedMusicTop: LinearLayout? = null
    private var expandedMusicThumb: ImageView? = null
    private var expandedMusicThumbShape: GradientDrawable? = null
    private var expandedMusicTitle: TextView? = null
    private var expandedMusicArtist: TextView? = null
    private var expandedMusicAlbum: TextView? = null
    private var controlsRow: LinearLayout? = null

    private var compactRotationAnimator: ObjectAnimator? = null
    private var compactWaveAnimator: ValueAnimator? = null
    private var compactPulseAnimator: ValueAnimator? = null
    private var dimensions: OrbitOverlayDimensions = OrbitOverlayDimensions()
    private var behavior: OrbitOverlayBehavior = OrbitOverlayBehavior()

    private var activeEvent: OverlayEvent? = null
    private val eventQueue = ArrayDeque<OverlayEvent>()
    private var musicPlaying = false
    private var lastMusicEvent: OverlayEvent.Music? = null
    private var isExpanded = false
    private var isAttached = false

    private val hideRunnable = Runnable { dismissActiveAndContinue() }

    fun showNotification(
        packageName: String,
        appName: String?,
        title: String,
        preview: String?,
        visibleMs: Int,
    ) {
        enqueue(
            OverlayEvent.Notification(
                packageName = packageName,
                appName = appName,
                title = title,
                preview = preview,
                visibleMs = visibleMs.coerceIn(2000, 6000),
            ),
        )
    }

    fun showMusic(
        appId: String,
        title: String,
        artist: String?,
        album: String?,
        albumArtBase64: String?,
        visibleMs: Int,
    ) {
        val event = OverlayEvent.Music(
            appId = appId,
            title = title,
            artist = artist,
            album = album,
            albumArtBase64 = albumArtBase64,
            visibleMs = visibleMs.coerceIn(2000, 6000),
        )

        enqueue(event) {
            musicPlaying = true
            lastMusicEvent = event
        }
    }

    fun onMusicPause() {
        mainHandler.post {
            musicPlaying = false
            lastMusicEvent = null
            eventQueue.removeAll { it is OverlayEvent.Music }
            if (activeEvent is OverlayEvent.Music) {
                dismissActiveAndContinue()
            }
        }
    }

    fun hideAndClear() {
        mainHandler.post {
            mainHandler.removeCallbacks(hideRunnable)
            eventQueue.clear()
            activeEvent = null
            isExpanded = false
            stopCompactAnimations()
            detachOverlay()
        }
    }

    fun destroy() {
        mainHandler.post {
            mainHandler.removeCallbacks(hideRunnable)
            eventQueue.clear()
            activeEvent = null
            musicPlaying = false
            lastMusicEvent = null
            isExpanded = false
            stopCompactAnimations()
            detachOverlay()
        }
    }

    fun updateDimensions(newDimensions: OrbitOverlayDimensions) {
        mainHandler.post {
            dimensions = newDimensions
            if (isAttached) {
                updateWindowLayout()
            }
            activeEvent?.let(::applyEventUi)
        }
    }

    fun updateBehavior(newBehavior: OrbitOverlayBehavior) {
        mainHandler.post {
            behavior = newBehavior
            activeEvent?.let(::applyEventUi)
        }
    }

    private fun enqueue(event: OverlayEvent, beforeEnqueue: (() -> Unit)? = null) {
        mainHandler.post {
            beforeEnqueue?.invoke()
            if (!canShowSystemOverlay()) {
                return@post
            }

            val current = activeEvent
            if (current == null) {
                showNow(event)
                return@post
            }

            if (event is OverlayEvent.Music && current is OverlayEvent.Music) {
                showNow(event, animate = false)
                return@post
            }

            if (event is OverlayEvent.Notification && current is OverlayEvent.Music) {
                showNow(event)
                return@post
            }

            OrbitQueuePolicy.insert(
                queue = eventQueue,
                activeCount = if (activeEvent == null) 0 else 1,
                event = event,
                isNotification = { candidate -> candidate is OverlayEvent.Notification },
                maxTotal = 3,
            )
        }
    }

    private fun showNow(event: OverlayEvent, animate: Boolean = true) {
        ensureOverlayAttached()
        mainHandler.removeCallbacks(hideRunnable)

        activeEvent = event
        isExpanded = false
        applyEventUi(event)

        val root = rootView ?: return
        root.clearAnimation()
        root.animate().cancel()

        if (animate) {
            val entryDuration = when (event) {
                is OverlayEvent.Music -> 260L
                is OverlayEvent.Notification -> 280L
            }
            val interpolator = if (
                event is OverlayEvent.Notification &&
                !behavior.reducedMotion
            ) {
                OvershootInterpolator(0.88f)
            } else {
                DecelerateInterpolator()
            }
            root.alpha = 0f
            root.translationY = -dp(20).toFloat()
            root.animate()
                .alpha(1f)
                .translationY(0f)
                .setDuration(entryDuration)
                .setInterpolator(interpolator)
                .start()
        } else {
            root.alpha = 1f
            root.translationY = 0f
        }

        when (event) {
            is OverlayEvent.Notification -> {
                mainHandler.postDelayed(hideRunnable, event.visibleMs.toLong())
            }

            is OverlayEvent.Music -> {
                if (!musicPlaying || !behavior.musicPersistent) {
                    mainHandler.postDelayed(hideRunnable, event.visibleMs.toLong())
                }
            }
        }
    }

    private fun dismissActiveAndContinue() {
        mainHandler.removeCallbacks(hideRunnable)
        activeEvent = null
        isExpanded = false
        stopCompactAnimations()

        val next = when {
            eventQueue.isNotEmpty() -> eventQueue.removeFirst()
            musicPlaying && lastMusicEvent != null -> lastMusicEvent
            else -> null
        }

        if (next != null) {
            showNow(next)
            return
        }

        val root = rootView ?: run {
            detachOverlay()
            return
        }

        root.animate().cancel()
        root.animate()
            .alpha(0f)
            .translationY(-dp(16).toFloat())
            .setDuration(200)
            .withEndAction { detachOverlay() }
            .start()
    }

    private fun ensureOverlayAttached() {
        if (isAttached || !canShowSystemOverlay()) {
            return
        }

        val root = rootView ?: createOverlayView().also { rootView = it }
        runCatching {
            windowManager?.addView(root, createLayoutParams())
            isAttached = true
        }
    }

    private fun detachOverlay() {
        if (!isAttached) {
            return
        }
        val root = rootView ?: return
        runCatching { windowManager?.removeViewImmediate(root) }
        isAttached = false
    }

    private fun createOverlayView(): FrameLayout {
        val root = FrameLayout(appContext).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
            )
        }

        val border = FrameLayout(appContext).apply {
            setPadding(dp(1.4f), dp(1.4f), dp(1.4f), dp(1.4f))
            background = borderBackground(useNeon = false, colors = FALLBACK_NEON_COLORS)
        }

        val card = LinearLayout(appContext).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
            minimumHeight = dp(dimensions.compactHeightDp.toFloat())
            setPadding(dp(16), dp(4), dp(16), dp(4))
            background = cardBackground()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                elevation = dp(18).toFloat()
            }

            setOnClickListener {
                val event = activeEvent ?: return@setOnClickListener
                isExpanded = !isExpanded
                applyEventUi(event)
            }

            var downY = 0f
            setOnTouchListener { _, motionEvent ->
                when (motionEvent.actionMasked) {
                    MotionEvent.ACTION_DOWN -> {
                        downY = motionEvent.rawY
                    }

                    MotionEvent.ACTION_UP -> {
                        val deltaY = motionEvent.rawY - downY
                        if (isExpanded && deltaY < -dp(22)) {
                            isExpanded = false
                            activeEvent?.let(::applyEventUi)
                            return@setOnTouchListener true
                        }
                    }
                }
                false
            }
        }

        val header = LinearLayout(appContext).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
        }

        val leadingShape = GradientDrawable().apply {
            setColor(Color.parseColor("#222222"))
            cornerRadius = dp(15).toFloat()
        }
        val leadingImage = ImageView(appContext).apply {
            layoutParams = LinearLayout.LayoutParams(dp(30), dp(30))
            scaleType = ImageView.ScaleType.CENTER_CROP
            background = leadingShape
            clipToOutline = true
        }

        val gapStart = spacer(widthDp = 10)

        val textContainer = LinearLayout(appContext).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }

        val primaryText = TextView(appContext).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
            letterSpacing = 0.02f
        }

        val secondaryText = TextView(appContext).apply {
            setTextColor(Color.parseColor("#D1FFFFFF"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
            visibility = View.GONE
        }

        textContainer.addView(primaryText)
        textContainer.addView(secondaryText)

        val musicSpacer = View(appContext).apply {
            layoutParams = LinearLayout.LayoutParams(0, 1, 1f)
            visibility = View.GONE
        }

        val gapEnd = spacer(widthDp = 10)

        val dot = View(appContext).apply {
            layoutParams = LinearLayout.LayoutParams(dp(8), dp(8))
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#FFFF5F6D"))
            }
            visibility = View.GONE
        }

        val waveBars = mutableListOf<View>()
        val waveShapes = mutableListOf<GradientDrawable>()
        val waveGroup = LinearLayout(appContext).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(dp(38), dp(20))
            visibility = View.GONE
        }
        repeat(4) { index ->
            val shape = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(4).toFloat()
                setColor(Color.WHITE)
            }
            val bar = View(appContext).apply {
                background = shape
                layoutParams = LinearLayout.LayoutParams(dp(3), dp(8)).apply {
                    if (index > 0) {
                        marginStart = dp(2)
                    }
                }
            }
            waveBars.add(bar)
            waveShapes.add(shape)
            waveGroup.addView(bar)
        }

        header.addView(leadingImage)
        header.addView(gapStart)
        header.addView(textContainer)
        header.addView(musicSpacer)
        header.addView(gapEnd)
        header.addView(dot)
        header.addView(waveGroup)

        val expanded = LinearLayout(appContext).apply {
            orientation = LinearLayout.VERTICAL
            visibility = View.GONE
            alpha = 0f
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
        }

        val musicTop = LinearLayout(appContext).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.TOP
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
        }

        val musicThumbShape = GradientDrawable().apply {
            setColor(Color.parseColor("#222222"))
            cornerRadius = dp(72f * 0.26f).toFloat()
        }
        val musicThumb = ImageView(appContext).apply {
            layoutParams = LinearLayout.LayoutParams(dp(72), dp(72)).apply {
                marginEnd = dp(12)
            }
            scaleType = ImageView.ScaleType.CENTER_CROP
            background = musicThumbShape
            clipToOutline = true
        }

        val musicTextColumn = LinearLayout(appContext).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }

        val musicTitle = TextView(appContext).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            maxLines = 2
            ellipsize = TextUtils.TruncateAt.END
            setLineSpacing(0f, 1.15f)
        }

        val musicArtist = TextView(appContext).apply {
            setTextColor(Color.parseColor("#E6FFFFFF"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
            setPadding(0, dp(6), 0, 0)
        }

        val musicAlbum = TextView(appContext).apply {
            setTextColor(Color.parseColor("#B8FFFFFF"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
            setPadding(0, dp(2), 0, 0)
            letterSpacing = 0.01f
        }

        musicTextColumn.addView(musicTitle)
        musicTextColumn.addView(musicArtist)
        musicTextColumn.addView(musicAlbum)

        musicTop.addView(musicThumb)
        musicTop.addView(musicTextColumn)

        val controlRow = LinearLayout(appContext).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
        }

        expanded.addView(musicTop)
        expanded.addView(controlRow)

        card.addView(header)
        card.addView(expanded)
        border.addView(card)
        root.addView(border)

        borderShell = border
        cardView = card
        headerRow = header
        headerLeading = leadingImage
        headerLeadingShape = leadingShape
        headerGapStart = gapStart
        headerTextContainer = textContainer
        headerPrimaryText = primaryText
        headerSecondaryText = secondaryText
        headerMusicSpacer = musicSpacer
        headerGapEnd = gapEnd
        headerDot = dot
        headerWaveContainer = waveGroup
        headerWaveBars = waveBars
        headerWaveBarShapes = waveShapes
        expandedSection = expanded
        expandedMusicTop = musicTop
        expandedMusicThumb = musicThumb
        expandedMusicThumbShape = musicThumbShape
        expandedMusicTitle = musicTitle
        expandedMusicArtist = musicArtist
        expandedMusicAlbum = musicAlbum
        controlsRow = controlRow
        return root
    }

    private fun applyEventUi(event: OverlayEvent) {
        val card = cardView ?: return
        val header = headerRow ?: return
        val leading = headerLeading ?: return
        val leadingShape = headerLeadingShape ?: return
        val textContainer = headerTextContainer ?: return
        val primaryText = headerPrimaryText ?: return
        val secondaryText = headerSecondaryText ?: return
        val musicSpacer = headerMusicSpacer ?: return
        val gapEnd = headerGapEnd ?: return
        val dot = headerDot ?: return
        val wave = headerWaveContainer ?: return
        val expanded = expandedSection ?: return
        val musicTop = expandedMusicTop ?: return
        val musicThumb = expandedMusicThumb ?: return
        val musicThumbShape = expandedMusicThumbShape ?: return
        val musicTitle = expandedMusicTitle ?: return
        val musicArtist = expandedMusicArtist ?: return
        val musicAlbum = expandedMusicAlbum ?: return

        val controls = controlsRow ?: return

            if (event is OverlayEvent.Music) {
                val appColor = musicColorForAppId(event.appId)
                val fallbackIcon = appIconForMusic(event.appId)
            val art = decodeBitmap(event.albumArtBase64)

            if (isExpanded) {
                header.visibility = View.GONE
                expanded.visibility = View.VISIBLE
                musicTop.visibility = View.VISIBLE
                updateControlsForMusic(controls, event)

                if (art != null) {
                    musicThumb.setImageBitmap(art)
                } else {
                    musicThumb.setImageDrawable(fallbackIcon)
                }
                musicThumb.scaleX = 1f
                musicThumb.scaleY = 1f
                musicThumbShape.cornerRadius = dp(72f * 0.26f).toFloat()

                musicTitle.text = event.title
                musicArtist.text = event.artist?.trim().takeUnless { it.isNullOrEmpty() } ?: "Unknown artist"
                musicAlbum.text = event.album?.trim().takeUnless { it.isNullOrEmpty() } ?: "Unknown album"

                (controls.layoutParams as LinearLayout.LayoutParams).topMargin = dp(12)
                expanded.setPadding(0, 0, 0, 0)
            } else {
                header.visibility = View.VISIBLE
                expanded.visibility = View.GONE
                musicTop.visibility = View.GONE

                configureLeadingSize(leading, leadingShape, sizeDp = 30, circular = true)
                if (art != null) {
                    leading.setImageBitmap(art)
                } else {
                    leading.setImageDrawable(fallbackIcon)
                }
                leading.scaleX = 1.20f
                leading.scaleY = 1.20f

                textContainer.visibility = View.GONE
                musicSpacer.visibility = View.VISIBLE
                if (behavior.reducedMotion) {
                    gapEnd.visibility = View.VISIBLE
                    dot.visibility = View.VISIBLE
                    wave.visibility = View.GONE
                    (dot.background as? GradientDrawable)?.setColor(appColor)
                } else {
                    gapEnd.visibility = View.GONE
                    dot.visibility = View.GONE
                    wave.visibility = View.VISIBLE
                }

                setWaveColor(appColor)
            }

            val neon = colorsForAlbum(art)
            updateBorder(useNeon = behavior.dynamicThemeEnabled, colors = neon)

            val minHeight = if (isExpanded) {
                dp(dimensions.musicExpandedHeightDp.toFloat())
            } else {
                dp(dimensions.compactHeightDp.toFloat())
            }
            val width = if (isExpanded) expandedWidthPx() else compactWidthPx()
            updateCardMetrics(card, width, minHeight)
            updateCardPadding(card)

            if (isExpanded) {
                stopCompactAnimations()
            } else {
                startCompactAnimations()
            }
            return
        }

        if (event is OverlayEvent.Notification) {
            val appColor = notificationColorForPackage(event.packageName)
            val icon = appIconForPackage(event.packageName)

            header.visibility = View.VISIBLE
            configureLeadingSize(leading, leadingShape, sizeDp = 28, circular = true)
            leading.scaleX = 1f
            leading.scaleY = 1f
            leading.setImageDrawable(icon)

            textContainer.visibility = View.VISIBLE
            musicSpacer.visibility = View.GONE
            wave.visibility = View.GONE
            gapEnd.visibility = View.VISIBLE
            dot.visibility = View.VISIBLE
            (dot.background as? GradientDrawable)?.setColor(appColor)

            if (!isExpanded || event.preview.isNullOrBlank()) {
                val line = if (event.preview.isNullOrBlank()) {
                    event.title
                } else {
                    "${event.title}: ${event.preview}"
                }
                primaryText.text = line
                primaryText.maxLines = 1
                secondaryText.visibility = View.GONE
            } else {
                primaryText.text = event.title
                primaryText.maxLines = 1
                secondaryText.text = event.preview
                secondaryText.visibility = View.VISIBLE
            }

            musicTop.visibility = View.GONE
            if (isExpanded) {
                expanded.visibility = View.VISIBLE
                updateControlsForNotification(controls, event)
                (controls.layoutParams as LinearLayout.LayoutParams).topMargin = 0
                expanded.setPadding(0, dp(8), 0, 0)
                expanded.alpha = 0f
                expanded.animate().alpha(1f).setDuration(120L).start()
            } else {
                expanded.visibility = View.GONE
            }

            updateBorder(useNeon = false, colors = FALLBACK_NEON_COLORS)

            val minHeight = if (isExpanded) {
                dp(dimensions.notificationExpandedHeightDp.toFloat())
            } else {
                dp(dimensions.compactHeightDp.toFloat())
            }
            val width = if (isExpanded) expandedWidthPx() else compactWidthPx()
            updateCardMetrics(card, width, minHeight)
            updateCardPadding(card)

            stopCompactAnimations()
        }
    }

    private fun configureLeadingSize(
        imageView: ImageView,
        shape: GradientDrawable,
        sizeDp: Int,
        circular: Boolean,
    ) {
        imageView.layoutParams = (imageView.layoutParams as LinearLayout.LayoutParams).apply {
            width = dp(sizeDp)
            height = dp(sizeDp)
        }
        shape.cornerRadius = if (circular) dp(sizeDp / 2f).toFloat() else dp(sizeDp * 0.26f).toFloat()
    }

    private fun updateCardPadding(card: LinearLayout) {
        val horizontal = if (isExpanded) 14 else 16
        val vertical = if (isExpanded) 12 else 4
        card.setPadding(dp(horizontal), dp(vertical), dp(horizontal), dp(vertical))
    }

    private fun updateCardMetrics(card: LinearLayout, widthPx: Int, minHeightPx: Int) {
        card.layoutParams = (card.layoutParams as? FrameLayout.LayoutParams
            ?: FrameLayout.LayoutParams(widthPx, FrameLayout.LayoutParams.WRAP_CONTENT)).apply {
            width = widthPx
            gravity = Gravity.CENTER_HORIZONTAL
        }
        card.minimumHeight = minHeightPx
    }

    private fun updateControlsForMusic(row: LinearLayout, event: OverlayEvent.Music) {
        row.removeAllViews()
        row.addView(createControlChip(android.R.drawable.ic_media_previous, "Prev") {
            sendMediaKey(KeyEvent.KEYCODE_MEDIA_PREVIOUS)
        })
        row.addView(spacer(6))
        row.addView(
            createControlChip(
                if (musicPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                if (musicPlaying) "Pause" else "Play",
            ) {
                sendMediaKey(KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
            },
        )
        row.addView(spacer(6))
        row.addView(createControlChip(android.R.drawable.ic_media_next, "Next") {
            sendMediaKey(KeyEvent.KEYCODE_MEDIA_NEXT)
        })
        row.addView(spacer(6))
        row.addView(createControlChip(android.R.drawable.ic_menu_manage, "App") {
            openAppNotificationSettings(packageNameForMusicAppId(event.appId))
        })
    }

    private fun updateControlsForNotification(row: LinearLayout, event: OverlayEvent.Notification) {
        row.removeAllViews()
        row.addView(createControlChip(android.R.drawable.ic_menu_close_clear_cancel, "Dismiss") {
            dismissActiveAndContinue()
        })
        row.addView(spacer(6))
        row.addView(createControlChip(android.R.drawable.ic_lock_silent_mode, "Mute") {
            muteNotificationApp(event.packageName)
            dismissActiveAndContinue()
        })
        row.addView(spacer(6))
        row.addView(createControlChip(android.R.drawable.ic_menu_manage, "App") {
            openAppNotificationSettings(event.packageName)
        })
    }

    private fun createControlChip(iconRes: Int, label: String, onTap: () -> Unit): View {
        val container = LinearLayout(appContext).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(dp(8), dp(6), dp(8), dp(6))
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#1FFFFFFF"))
                cornerRadius = dp(12).toFloat()
            }
            setOnClickListener { onTap.invoke() }
        }

        val icon = ImageView(appContext).apply {
            setImageResource(iconRes)
            setColorFilter(Color.WHITE)
            layoutParams = LinearLayout.LayoutParams(dp(14), dp(14))
        }

        val text = TextView(appContext).apply {
            this.text = label
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                marginStart = dp(4)
            }
        }

        container.addView(icon)
        container.addView(text)
        return container
    }

    private fun startCompactAnimations() {
        if (behavior.reducedMotion) {
            stopCompactRotation()
            stopWaveformAnimation()
            startCompactPulse()
            return
        }
        stopCompactPulse()
        startCompactRotation()
        startWaveformAnimation()
    }

    private fun stopCompactAnimations() {
        stopCompactPulse()
        stopCompactRotation()
        stopWaveformAnimation()
    }

    private fun startCompactRotation() {
        val image = headerLeading ?: return
        if (compactRotationAnimator?.isRunning == true) {
            return
        }

        compactRotationAnimator = ObjectAnimator.ofFloat(image, View.ROTATION, 0f, 360f).apply {
            duration = 14000L
            interpolator = LinearInterpolator()
            repeatMode = ValueAnimator.RESTART
            repeatCount = ValueAnimator.INFINITE
            start()
        }
    }

    private fun stopCompactRotation() {
        compactRotationAnimator?.cancel()
        compactRotationAnimator = null
        headerLeading?.rotation = 0f
    }

    private fun startWaveformAnimation() {
        val bars = headerWaveBars
        if (bars.isEmpty()) {
            return
        }
        if (compactWaveAnimator?.isRunning == true) {
            return
        }

        compactWaveAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 920L
            interpolator = LinearInterpolator()
            repeatCount = ValueAnimator.INFINITE
            repeatMode = ValueAnimator.RESTART
            addUpdateListener { animator ->
                val t = (animator.animatedValue as Float) * (PI * 2.0)
                bars.forEachIndexed { index, view ->
                    val wave = (sin(t + index * 0.72) + 1.0) / 2.0
                    val height = dp((5f + wave.toFloat() * 10f))
                    val params = view.layoutParams as LinearLayout.LayoutParams
                    if (params.height != height) {
                        params.height = height
                        view.layoutParams = params
                    }
                }
            }
            start()
        }
    }

    private fun stopWaveformAnimation() {
        compactWaveAnimator?.cancel()
        compactWaveAnimator = null
        headerWaveBars.forEach { bar ->
            val params = bar.layoutParams as LinearLayout.LayoutParams
            params.height = dp(8)
            bar.layoutParams = params
        }
    }

    private fun startCompactPulse() {
        val dot = headerDot ?: return
        if (compactPulseAnimator?.isRunning == true) {
            return
        }
        compactPulseAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 1200L
            interpolator = LinearInterpolator()
            repeatCount = ValueAnimator.INFINITE
            repeatMode = ValueAnimator.REVERSE
            addUpdateListener { animator ->
                val value = animator.animatedValue as Float
                dot.alpha = 0.38f + (value * 0.52f)
                dot.scaleX = 0.9f + (value * 0.2f)
                dot.scaleY = 0.9f + (value * 0.2f)
            }
            start()
        }
    }

    private fun stopCompactPulse() {
        compactPulseAnimator?.cancel()
        compactPulseAnimator = null
        headerDot?.apply {
            alpha = 1f
            scaleX = 1f
            scaleY = 1f
        }
    }

    private fun setWaveColor(color: Int) {
        val alphaColor = Color.argb(
            242,
            Color.red(color),
            Color.green(color),
            Color.blue(color),
        )
        headerWaveBarShapes.forEach { shape ->
            shape.setColor(alphaColor)
        }
    }

    private fun sendMediaKey(keyCode: Int) {
        val audioManager = appContext.getSystemService(AudioManager::class.java) ?: return
        runCatching {
            audioManager.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
            audioManager.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, keyCode))
        }
    }

    private fun muteNotificationApp(packageName: String) {
        val current = OrbitNotificationConfig.snapshot().toMutableSet()
        current.remove(packageName.trim().lowercase())
        OrbitNotificationConfig.setAllowedPackages(current)
    }

    private fun openAppNotificationSettings(packageName: String) {
        if (packageName.isBlank()) {
            return
        }
        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
            putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        runCatching { appContext.startActivity(intent) }
    }

    private fun packageNameForMusicAppId(appId: String): String {
        return when (appId.lowercase()) {
            "spotify", "com.spotify.music" -> "com.spotify.music"
            else -> if (appId.contains('.')) appId else ""
        }
    }

    private fun musicColorForAppId(appId: String): Int {
        return when (appId.lowercase()) {
            "spotify", "com.spotify.music" -> Color.parseColor("#1DB954")
            else -> colorFromString(appId)
        }
    }

    private fun notificationColorForPackage(packageName: String): Int {
        return when (packageName.lowercase()) {
            "com.instagram.android" -> Color.parseColor("#E95950")
            "com.whatsapp" -> Color.parseColor("#25D366")
            "com.google.android.gm" -> Color.parseColor("#DB4437")
            "com.slack", "com.slack.android" -> Color.parseColor("#4A154B")
            else -> colorFromString(packageName)
        }
    }

    private fun colorFromString(value: String): Int {
        val hash = value.hashCode() and 0x00FFFFFF
        val r = 70 + ((hash shr 16) and 0x7F)
        val g = 70 + ((hash shr 8) and 0x7F)
        val b = 70 + (hash and 0x7F)
        return Color.rgb(r, g, b)
    }

    private fun updateBorder(useNeon: Boolean, colors: IntArray) {
        val shell = borderShell ?: return
        shell.background = borderBackground(useNeon, colors)
    }

    private fun borderBackground(useNeon: Boolean, colors: IntArray): GradientDrawable {
        return if (useNeon) {
            GradientDrawable(
                GradientDrawable.Orientation.TL_BR,
                intArrayOf(colors[0], colors[1]),
            ).apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(24).toFloat()
            }
        } else {
            GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                setColor(Color.TRANSPARENT)
                cornerRadius = dp(24).toFloat()
                setStroke(dp(1), Color.parseColor("#2BFFFFFF"))
            }
        }
    }

    private fun cardBackground(): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(Color.BLACK)
            cornerRadius = dp(24).toFloat()
        }
    }

    private fun appIconForPackage(packageName: String): Drawable {
        return runCatching {
            appContext.packageManager.getApplicationIcon(packageName)
        }.getOrElse {
            appContext.getDrawable(android.R.drawable.ic_dialog_info)
                ?: GradientDrawable().apply { setColor(Color.DKGRAY) }
        }
    }

    private fun appIconForMusic(appId: String): Drawable {
        val packageName = packageNameForMusicAppId(appId)
        if (packageName.isNotBlank()) {
            return appIconForPackage(packageName)
        }
        return appContext.getDrawable(android.R.drawable.ic_media_play)
            ?: GradientDrawable().apply { setColor(Color.DKGRAY) }
    }

    private fun decodeBitmap(base64Data: String?): Bitmap? {
        if (base64Data.isNullOrBlank()) {
            return null
        }
        return runCatching {
            val bytes = Base64.decode(base64Data, Base64.DEFAULT)
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        }.getOrNull()
    }

    private fun colorsForAlbum(bitmap: Bitmap?): IntArray {
        if (bitmap == null) {
            return FALLBACK_NEON_COLORS
        }

        val left = averageColor(bitmap, 0, bitmap.width / 2)
        val right = averageColor(bitmap, bitmap.width / 2, bitmap.width)
        return intArrayOf(saturateAndLift(left), saturateAndLift(right))
    }

    private fun averageColor(bitmap: Bitmap, xStart: Int, xEnd: Int): Int {
        val safeXStart = max(0, min(bitmap.width - 1, xStart))
        val safeXEnd = max(safeXStart + 1, min(bitmap.width, xEnd))
        val yStart = bitmap.height / 6
        val yEnd = bitmap.height - yStart

        var rSum = 0L
        var gSum = 0L
        var bSum = 0L
        var count = 0L

        val stepX = max(1, (safeXEnd - safeXStart) / 18)
        val stepY = max(1, (yEnd - yStart) / 18)

        var y = yStart
        while (y < yEnd) {
            var x = safeXStart
            while (x < safeXEnd) {
                val color = bitmap.getPixel(x, y)
                rSum += Color.red(color)
                gSum += Color.green(color)
                bSum += Color.blue(color)
                count++
                x += stepX
            }
            y += stepY
        }

        if (count == 0L) {
            return FALLBACK_NEON_COLORS[0]
        }

        val r = (rSum / count).toInt().coerceIn(0, 255)
        val g = (gSum / count).toInt().coerceIn(0, 255)
        val b = (bSum / count).toInt().coerceIn(0, 255)
        return Color.rgb(r, g, b)
    }

    private fun saturateAndLift(color: Int): Int {
        val hsv = FloatArray(3)
        Color.colorToHSV(color, hsv)
        hsv[1] = (hsv[1] * 1.28f).coerceIn(0.45f, 1.0f)
        hsv[2] = (hsv[2] * 1.15f).coerceIn(0.40f, 1.0f)
        return Color.HSVToColor(hsv)
    }

    private fun createLayoutParams(): WindowManager.LayoutParams {
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            val topBase = (statusBarHeightPx() - dp(32)).coerceAtLeast(0)
            y = topBase + dimensions.verticalOffsetPx
            x = dimensions.horizontalOffsetPx
        }
    }

    private fun compactWidthPx(): Int {
        val width = appContext.resources.displayMetrics.widthPixels
        val factor = dimensions.compactWidthFactor.coerceIn(0.35f, 0.85f)
        return max(dp(COMPACT_MIN_WIDTH_DP), (width * factor).toInt())
    }

    private fun expandedWidthPx(): Int {
        val width = appContext.resources.displayMetrics.widthPixels
        val factor = dimensions.expandedWidthFactor.coerceIn(0.55f, 0.92f)
        return max(dp(EXPANDED_MIN_WIDTH_DP), (width * factor).toInt())
    }

    private fun updateWindowLayout() {
        val root = rootView ?: return
        if (!isAttached) {
            return
        }
        runCatching {
            windowManager?.updateViewLayout(root, createLayoutParams())
        }
    }

    private fun canShowSystemOverlay(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }
        return Settings.canDrawOverlays(appContext)
    }

    private fun statusBarHeightPx(): Int {
        val resId = appContext.resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (resId > 0) appContext.resources.getDimensionPixelSize(resId) else 0
    }

    private fun spacer(widthDp: Int): View {
        return View(appContext).apply {
            layoutParams = LinearLayout.LayoutParams(dp(widthDp), 1)
        }
    }

    private fun dp(value: Int): Int = dp(value.toFloat())

    private fun dp(value: Float): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value,
            appContext.resources.displayMetrics,
        ).toInt()
    }

    private sealed class OverlayEvent {
        data class Music(
            val appId: String,
            val title: String,
            val artist: String?,
            val album: String?,
            val albumArtBase64: String?,
            val visibleMs: Int,
        ) : OverlayEvent()

        data class Notification(
            val packageName: String,
            val appName: String?,
            val title: String,
            val preview: String?,
            val visibleMs: Int,
        ) : OverlayEvent()
    }
}
