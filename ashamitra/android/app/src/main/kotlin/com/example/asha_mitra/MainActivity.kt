package com.example.asha_mitra

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createAlertChannel()
    }

    // The backend sends android.notification.channel_id = "ashamitra_alerts".
    // FCM will NOT create that channel for us — if it doesn't exist, Android
    // quietly files the message under its fallback "Miscellaneous" channel at
    // low importance, so a RED maternal alert would arrive with no sound and no
    // heads-up banner. Creating it here at IMPORTANCE_HIGH is what makes the
    // phone actually buzz. Re-creating an existing channel is a no-op, so this
    // is safe to run on every launch.
    private fun createAlertChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            "ashamitra_alerts",
            "জরুরি অ্যালার্ট",            // shown to the user in Android's settings
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "বিপদচিহ্ন, রেফারেল ও জরুরি খবর"
            enableVibration(true)
        }
        getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
    }
}
