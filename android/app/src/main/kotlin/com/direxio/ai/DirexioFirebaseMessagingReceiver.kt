package com.direxio.ai

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import kotlin.math.abs

class DirexioFirebaseMessagingReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val extras = intent.extras
        if (extras == null) {
            Log.d(tag, "onMessageReceived skip: empty extras")
            return
        }

        val data = dataPayloadFromExtras(extras)
        Log.i(tag, "onMessageReceived data=$data")
        if (data.isEmpty()) {
            Log.d(tag, "onMessageReceived skip: empty data payload")
            return
        }
        if (hasNotificationPayload(extras)) {
            Log.d(tag, "onMessageReceived skip: notification payload present")
            return
        }
        showDataNotification(context.applicationContext, data)
    }

    private fun dataPayloadFromExtras(extras: android.os.Bundle): Map<String, String> {
        val data = linkedMapOf<String, String>()
        for (key in extras.keySet()) {
            if (isFcmReservedKey(key)) continue
            val value = extras.get(key)?.toString()?.trim()
            if (!value.isNullOrEmpty()) data[key] = value
        }
        return data
    }

    private fun isFcmReservedKey(key: String): Boolean {
        return key == "from" ||
            key == "collapse_key" ||
            key.startsWith("google.") ||
            key.startsWith("gcm.") ||
            key.startsWith("android.")
    }

    private fun hasNotificationPayload(extras: android.os.Bundle): Boolean {
        return extras.keySet().any { key ->
            key.startsWith("gcm.n.") || key.startsWith("gcm.notification.")
        }
    }

    private fun showDataNotification(context: Context, data: Map<String, String>) {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            Log.w(tag, "notification skip: POST_NOTIFICATIONS is not granted")
            return
        }

        ensureNotificationChannel(context)
        val launchIntent = (
            context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent(context, MainActivity::class.java)
            ).apply {
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            data["event_id"]?.let { putExtra("matrix_event_id", it) }
            data["room_id"]?.let { putExtra("matrix_room_id", it) }
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            notificationIdFor(data),
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(notificationTitle(data))
            .setContentText(notificationBody(data))
            .setStyle(NotificationCompat.BigTextStyle().bigText(notificationBody(data)))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        NotificationManagerCompat.from(context).notify(notificationIdFor(data), notification)
        Log.i(tag, "notification shown id=${notificationIdFor(data)} channel=$channelId")
    }

    private fun ensureNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(channelId) != null) return
        val channel = NotificationChannel(
            channelId,
            "Direxio messages",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Matrix message notifications"
        }
        manager.createNotificationChannel(channel)
        Log.i(tag, "notification channel created id=$channelId")
    }

    private fun notificationTitle(data: Map<String, String>): String {
        return firstNonBlank(
            data,
            "title",
            "notification_title",
            "sender_display_name",
            "room_name"
        ) ?: "Direxio"
    }

    private fun notificationBody(data: Map<String, String>): String {
        return firstNonBlank(
            data,
            "body",
            "notification_body",
            "content_body",
            "event_body",
            "content.body"
        ) ?: "You have a new message"
    }

    private fun firstNonBlank(data: Map<String, String>, vararg keys: String): String? {
        for (key in keys) {
            val value = data[key]?.trim()
            if (!value.isNullOrEmpty()) return value
        }
        return null
    }

    private fun notificationIdFor(data: Map<String, String>): Int {
        val stableKey = data["event_id"]
            ?: data["google.message_id"]
            ?: data["message_id"]
            ?: data["room_id"]
            ?: data.toString()
        val hash = stableKey.hashCode()
        return if (hash == Int.MIN_VALUE) 0 else abs(hash)
    }

    private companion object {
        const val tag = "DirexioFCM"
        const val channelId = "direxio_matrix_messages"
    }
}
