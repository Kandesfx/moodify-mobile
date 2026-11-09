package dev.moodify.moodify_flutter

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.Animatable
import android.graphics.drawable.Animatable2
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File
import android.util.TypedValue
import android.view.Gravity
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    companion object {
        private const val NOTIFICATION_CHANNEL_NAME = "dev.moodify.moodify_flutter/notifications"
        private const val BRAND_CHANNEL_ID = "moodify_brand_alerts_v1"
        private const val REQUEST_POST_NOTIFICATIONS = 4102
        private const val APP_UPDATE_CHANNEL_NAME = "dev.moodify.moodify_flutter/app_update"
    }

    private var preSplashOverlay: FrameLayout? = null
    private var preSplashDrawable: Drawable? = null
    private var keepAnimatingPreSplash = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ensureBrandNotificationChannel()
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NOTIFICATION_CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "ensurePermission" -> {
                    ensureBrandNotificationChannel()
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val granted = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.POST_NOTIFICATIONS,
                        ) == PackageManager.PERMISSION_GRANTED
                        if (!granted) {
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                REQUEST_POST_NOTIFICATIONS,
                            )
                        }
                        result.success(granted)
                    } else {
                        result.success(true)
                    }
                }
                "showNotification" -> {
                    val id = call.argument<String>("id") ?: System.currentTimeMillis().toString()
                    val title = call.argument<String>("title") ?: "Moodify"
                    val message = call.argument<String>("message") ?: ""
                    val silent = call.argument<Boolean>("silent") ?: false
                    val shown = showBrandNotification(id, title, message, silent)
                    result.success(shown)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_UPDATE_CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAppVersion" -> {
                    try {
                        val pInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            packageManager.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0))
                        } else {
                            @Suppress("DEPRECATION")
                            packageManager.getPackageInfo(packageName, 0)
                        }
                        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            pInfo.longVersionCode.toInt()
                        } else {
                            @Suppress("DEPRECATION")
                            pInfo.versionCode
                        }
                        val versionName = pInfo.versionName ?: "0.1.0"
                        result.success(mapOf(
                            "versionName" to versionName,
                            "versionCode" to versionCode
                        ))
                    } catch (e: Exception) {
                        result.error("VERSION_ERROR", e.message, null)
                    }
                }
                "canInstallPackage" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        result.success(packageManager.canRequestPackageInstalls())
                    } else {
                        result.success(true)
                    }
                }
                "openInstallPermissionSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SETTINGS_ERROR", e.message, null)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath.isNullOrBlank()) {
                        result.error("INVALID_PATH", "Đường dẫn file APK không hợp lệ", null)
                        return@setMethodCallHandler
                    }
                    val file = File(filePath)
                    if (!file.exists()) {
                        result.error("FILE_NOT_FOUND", "Không tìm thấy file APK", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val apkUri = FileProvider.getUriForFile(
                            this,
                            "$packageName.fileprovider",
                            file
                        )
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(apkUri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun brandSoundUri(): Uri =
        Uri.parse("android.resource://$packageName/${R.raw.moodify_notification_chime}")

    private fun ensureBrandNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        val existing = manager.getNotificationChannel(BRAND_CHANNEL_ID)
        if (existing != null) return
        val audioAttributes = AudioAttributes.Builder()
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .build()
        val channel = NotificationChannel(
            BRAND_CHANNEL_ID,
            "Thông báo hệ thống Moodify",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Thông báo hệ thống, gói dịch vụ và cập nhật tài khoản Moodify"
            enableLights(true)
            lightColor = Color.parseColor("#8B5CF6")
            enableVibration(true)
            setSound(brandSoundUri(), audioAttributes)
        }
        manager.createNotificationChannel(channel)
    }

    private fun showBrandNotification(
        id: String,
        title: String,
        message: String,
        silent: Boolean,
    ): Boolean {
        ensureBrandNotificationChannel()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    REQUEST_POST_NOTIFICATIONS,
                )
                return false
            }
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return false
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(this, id.hashCode(), launchIntent, pendingFlags)

        val smallIconRes = try {
            val iconId = resources.getIdentifier("ic_stat_moodify", "drawable", packageName)
            if (iconId != 0) iconId else R.mipmap.ic_launcher
        } catch (_: Exception) {
            R.mipmap.ic_launcher
        }

        val notification = NotificationCompat.Builder(this, BRAND_CHANNEL_ID)
            .setSmallIcon(smallIconRes)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setColor(Color.parseColor("#8B5CF6"))
            .setAutoCancel(true)
            .setSilent(silent)
            .apply {
                if (!silent) {
                    setSound(brandSoundUri())
                    setDefaults(NotificationCompat.DEFAULT_VIBRATE or NotificationCompat.DEFAULT_LIGHTS)
                }
            }
            .setContentIntent(pendingIntent)
            .build()
        manager.notify(id.hashCode(), notification)
        return true
    }

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
            text = "Âm nhạc theo cách của bạn"
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
