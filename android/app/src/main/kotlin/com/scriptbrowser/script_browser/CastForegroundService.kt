package com.scriptbrowser.script_browser

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/** A user-visible lease for the existing relay process; never starts a second WebView or video download. */
class CastForegroundService : Service() {
    private var cpuLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null
    private val channelId = "active_cast"
    private val notificationId = 8878

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= 26) {
            val channel = NotificationChannel(channelId, "Active TV casting", NotificationManager.IMPORTANCE_LOW)
            channel.description = "Keeps your TV connection active while the phone is locked."
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    @Suppress("DEPRECATION")
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "STOP_CAST") {
            MainActivity.castChannel?.invokeMethod("stopRequested", null)
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }
        val open = PendingIntent.getActivity(this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val stop = PendingIntent.getService(this, 1,
            Intent(this, CastForegroundService::class.java).setAction("STOP_CAST"),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, channelId) else Notification.Builder(this)
        val notification = builder
            .setSmallIcon(R.drawable.ic_cast_notification)
            .setContentTitle("Casting to ${intent?.getStringExtra("deviceName") ?: "TV"}")
            .setContentText("You can lock your phone. Tap Stop to disconnect.")
            .setContentIntent(open)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .addAction(Notification.Action.Builder(null, "Stop casting", stop).build())
            .build()
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(notificationId, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
        } else startForeground(notificationId, notification)
        if (cpuLock == null) {
            cpuLock = getSystemService(PowerManager::class.java)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "ScriptBrowser:CastRelay")
                .apply { setReferenceCounted(false); acquire() }
            // On Android 14+ this is mapped to low-latency mode by the OS; it is not a Doze exemption.
            wifiLock = (applicationContext.getSystemService(WIFI_SERVICE) as WifiManager)
                .createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "ScriptBrowser:CastWifi")
                .apply { setReferenceCounted(false); acquire() }
        }
        // A lost relay cannot be reconstructed without its private in-memory URLs/cookies.
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        MainActivity.castChannel?.invokeMethod("stopRequested", null)
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        wifiLock?.let { if (it.isHeld) it.release() }
        cpuLock?.let { if (it.isHeld) it.release() }
        wifiLock = null
        cpuLock = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
