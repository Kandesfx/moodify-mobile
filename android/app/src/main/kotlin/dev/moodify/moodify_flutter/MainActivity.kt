package dev.moodify.moodify_flutter

import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.Animatable
import android.graphics.drawable.Animatable2
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {
    private var preSplashOverlay: FrameLayout? = null
    private var preSplashDrawable: Drawable? = null
    private var keepAnimatingPreSplash = false

    override fun onCreate(savedInstanceState: Bundle?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashScreen.setOnExitAnimationListener { splashScreenView ->
                splashScreenView.remove()
            }
        }
        super.onCreate(savedInstanceState)
        attachAnimatedPreSplashOverlay()
    }

    private fun attachAnimatedPreSplashOverlay() {
        val root = window?.decorView as? ViewGroup ?: return
        val density = resources.displayMetrics.density
        fun dp(value: Int): Int = (value * density).toInt()

        keepAnimatingPreSplash = true

        val overlay = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#0C0C10"))
            isClickable = false
            isFocusable = false
        }

        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
        }

        val logoView = ImageView(this).apply {
            setImageResource(R.drawable.avd_launch_logo)
            scaleType = ImageView.ScaleType.FIT_CENTER
        }
        val logoDrawable = logoView.drawable
        preSplashDrawable = logoDrawable

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && logoDrawable is Animatable2) {
            logoDrawable.registerAnimationCallback(object : Animatable2.AnimationCallback() {
                override fun onAnimationEnd(drawable: Drawable?) {
                    if (keepAnimatingPreSplash) {
                        logoView.post {
                            if (keepAnimatingPreSplash) {
                                (drawable as? Animatable)?.start()
                            }
                        }
                    }
                }
            })
        }
        (logoDrawable as? Animatable)?.start()

        val titleView = TextView(this).apply {
            text = "moodify"
            setTextColor(Color.parseColor("#F5F3FF"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 28f)
            typeface = Typeface.create("sans-serif-black", Typeface.BOLD)
            gravity = Gravity.CENTER
            letterSpacing = -0.02f
            setPadding(0, dp(4), 0, dp(8))
        }

        val pillBg = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(20).toFloat()
            setColor(Color.parseColor("#161422"))
            setStroke(dp(1).coerceAtLeast(1), Color.parseColor("#4D8B5CF6"))
        }

        val subtitleView = TextView(this).apply {
            text = "Âm nhạc theo từng cảm xúc"
            setTextColor(Color.parseColor("#C4B5FD"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f)
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            gravity = Gravity.CENTER
            background = pillBg
            setPadding(dp(16), dp(6), dp(16), dp(6))
        }

        column.addView(
            logoView,
            LinearLayout.LayoutParams(dp(230), dp(230)).apply {
                gravity = Gravity.CENTER
            },
        )
        column.addView(
            titleView,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ),
        )
        column.addView(
            subtitleView,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ),
        )

        overlay.addView(
            column,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER,
            ),
        )

        root.addView(
            overlay,
            ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
        preSplashOverlay = overlay
    }

    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        dismissAnimatedPreSplashOverlay()
    }

    private fun dismissAnimatedPreSplashOverlay() {
        keepAnimatingPreSplash = false
        (preSplashDrawable as? Animatable)?.stop()
        preSplashDrawable = null

        val overlay = preSplashOverlay ?: return
        preSplashOverlay = null
        overlay.animate()
            .alpha(0f)
            .setDuration(180L)
            .withEndAction {
                (overlay.parent as? ViewGroup)?.removeView(overlay)
            }
            .start()
    }

    override fun onDestroy() {
        keepAnimatingPreSplash = false
        (preSplashDrawable as? Animatable)?.stop()
        preSplashDrawable = null
        preSplashOverlay = null
        super.onDestroy()
    }
}
