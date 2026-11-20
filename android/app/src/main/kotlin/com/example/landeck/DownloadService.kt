package com.example.landeck

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import org.json.JSONObject
import java.io.FileNotFoundException
import java.io.IOException
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.net.URL
import java.net.UnknownHostException
import java.security.SecureRandom
import java.security.cert.X509Certificate
import java.util.concurrent.atomic.AtomicBoolean
import javax.net.ssl.HostnameVerifier
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager

/**
 * Real foreground download worker. One transfer is active at a time; Flutter
 * queues tasks and polls the progress stored here. The service is deliberately
 * independent from the WebView so closing a page does not cancel a download.
 */
class DownloadService : Service() {
    companion object {
        const val ACTION_START = "com.example.landeck.download.START"
        const val ACTION_CANCEL = "com.example.landeck.download.CANCEL"
        const val EXTRA_TASK_ID = "taskId"
        const val EXTRA_URL = "url"
        const val EXTRA_FILE_NAME = "fileName"
        const val EXTRA_MIME = "mimeType"
        const val EXTRA_DESTINATION = "destinationUri"
        const val EXTRA_HEADERS = "headers"

        private const val CHANNEL_ID = "landeck_downloads"
        private const val NOTIFICATION_ID = 7401
        private const val PREFS = "landeck_downloads"

        fun readStatus(context: Context, taskId: String): Map<String, Any?>? {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            if (!prefs.contains("$taskId.status")) return null
            return mapOf(
                "status" to prefs.getString("$taskId.status", "failed"),
                "downloaded" to prefs.getLong("$taskId.downloaded", 0L),
                "total" to prefs.getLong("$taskId.total", -1L),
                "error" to prefs.getString("$taskId.error", null),
            )
        }

        private fun writeStatus(
            context: Context,
            taskId: String,
            status: String,
            downloaded: Long = 0,
            total: Long = -1,
            error: String? = null,
        ) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putString("$taskId.status", status)
                .putLong("$taskId.downloaded", downloaded)
                .putLong("$taskId.total", total)
                .putString("$taskId.error", error)
                .apply()
        }
    }

    private var activeTaskId: String? = null
    private var activeConnection: HttpURLConnection? = null
    private val cancelled = AtomicBoolean(false)
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CANCEL -> {
                val taskId = intent.getStringExtra(EXTRA_TASK_ID)
                if (taskId != null && taskId == activeTaskId) {
                    cancelled.set(true)
                    activeConnection?.disconnect()
                }
                return START_NOT_STICKY
            }
            ACTION_START -> {
                val taskId = intent.getStringExtra(EXTRA_TASK_ID) ?: return START_NOT_STICKY
                if (activeTaskId != null) {
                    // The Flutter queue serializes transfers; reject overlap
                    // rather than corrupting the single foreground service.
                    return START_NOT_STICKY
                }
                val url = intent.getStringExtra(EXTRA_URL) ?: return START_NOT_STICKY
                val destination = intent.getStringExtra(EXTRA_DESTINATION)
                    ?: return START_NOT_STICKY
                val fileName = intent.getStringExtra(EXTRA_FILE_NAME) ?: "download"
                val mimeType = intent.getStringExtra(EXTRA_MIME)
                val headers = parseHeaders(intent.getStringExtra(EXTRA_HEADERS))

                activeTaskId = taskId
                cancelled.set(false)
                startForegroundForTask(taskId, fileName, 0, -1, true)
                writeStatus(this, taskId, "downloading")
                acquireWakeLock()
                Thread {
                    runDownload(taskId, url, destination, fileName, mimeType, headers)
                }.start()
                return START_NOT_STICKY
            }
        }
        return START_NOT_STICKY
    }

    private fun runDownload(
        taskId: String,
        url: String,
        destination: String,
        fileName: String,
        mimeType: String?,
        headers: Map<String, String>,
    ) {
        var connection: HttpURLConnection? = null
        var downloaded = 0L
        var total = -1L
        try {
            connection = URL(url).openConnection() as HttpURLConnection
            activeConnection = connection
            connection.connectTimeout = 15_000
            connection.readTimeout = 30_000
            connection.instanceFollowRedirects = true
            connection.requestMethod = "GET"
            headers.forEach { (key, value) ->
                if (value.isNotEmpty() && !isForbiddenHeader(key)) {
                    connection.setRequestProperty(key, value)
                }
            }
            if (url.startsWith("https://") && isPrivateHost(Uri.parse(url).host)) {
                trustPrivateHost(connection as HttpsURLConnection)
            }

            val code = connection.responseCode
            if (code !in 200..299) {
                throw DownloadHttpException(
                    when (code) {
                        401, 403 -> "认证失败，请在网页中重新登录后重试"
                        404 -> "下载链接已失效（HTTP 404）"
                        in 500..599 -> "服务器错误（HTTP $code）"
                        else -> "下载失败（HTTP $code）"
                    },
                )
            }

            total = connection.contentLengthLong
            val uri = Uri.parse(destination)
            val output = contentResolver.openOutputStream(uri)
                ?: throw DownloadStorageException("保存位置不可用")
            output.use { stream ->
                connection.inputStream.use { input ->
                    val buffer = ByteArray(64 * 1024)
                    var lastUpdate = 0L
                    while (true) {
                        if (cancelled.get()) {
                            throw DownloadCancelledException()
                        }
                        val read = input.read(buffer)
                        if (read <= 0) break
                        stream.write(buffer, 0, read)
                        downloaded += read
                        val now = System.currentTimeMillis()
                        if (now - lastUpdate > 500) {
                            lastUpdate = now
                            writeStatus(this, taskId, "downloading", downloaded, total)
                            startForegroundForTask(taskId, fileName, downloaded, total, true)
                        }
                    }
                    stream.flush()
                }
            }

            writeStatus(this, taskId, "completed", downloaded, total)
            startForegroundForTask(taskId, fileName, downloaded, total, false)
            showCompletedNotification(taskId, fileName, destination, mimeType)
        } catch (_: DownloadCancelledException) {
            writeStatus(this, taskId, "cancelled", downloaded, total, "已取消")
        } catch (error: DownloadHttpException) {
            writeStatus(this, taskId, "failed", downloaded, total, error.message)
            showFailedNotification(fileName, error.message ?: "下载失败")
        } catch (error: SocketTimeoutException) {
            writeStatus(this, taskId, "failed", downloaded, total, "连接超时")
            showFailedNotification(fileName, "连接超时")
        } catch (error: UnknownHostException) {
            writeStatus(this, taskId, "failed", downloaded, total, "无法解析下载地址")
            showFailedNotification(fileName, "无法解析下载地址")
        } catch (error: DownloadStorageException) {
            writeStatus(this, taskId, "failed", downloaded, total, error.message)
            showFailedNotification(fileName, error.message ?: "保存失败")
        } catch (error: FileNotFoundException) {
            writeStatus(this, taskId, "failed", downloaded, total, "保存位置不可用")
            showFailedNotification(fileName, "保存位置不可用")
        } catch (error: IOException) {
            val message = if (cancelled.get()) "已取消" else "网络连接失败"
            writeStatus(
                this,
                taskId,
                if (cancelled.get()) "cancelled" else "failed",
                downloaded,
                total,
                message,
            )
            if (!cancelled.get()) showFailedNotification(fileName, message)
        } catch (error: Exception) {
            writeStatus(this, taskId, "failed", downloaded, total, "下载失败")
            showFailedNotification(fileName, "下载失败")
        } finally {
            activeConnection = null
            try {
                connection?.disconnect()
            } catch (_: Exception) {
                // Best effort.
            }
            releaseWakeLock()
            activeTaskId = null
            ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    private fun startForegroundForTask(
        taskId: String,
        fileName: String,
        downloaded: Long,
        total: Long,
        ongoing: Boolean,
    ) {
        val notification = buildNotification(fileName, downloaded, total, ongoing)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ServiceCompat.startForeground(
                this,
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(
        fileName: String,
        downloaded: Long,
        total: Long,
        ongoing: Boolean,
    ): Notification {
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle(if (ongoing) "正在下载" else "下载完成")
            .setContentText(fileName)
            .setOnlyAlertOnce(true)
            .setOngoing(ongoing)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
        if (ongoing && total > 0) {
            val percent = ((downloaded * 100) / total).toInt().coerceIn(0, 100)
            builder.setProgress(100, percent, false)
            builder.setSubText("$percent%")
        } else if (ongoing) {
            builder.setProgress(0, 0, true)
        }
        return builder.build()
    }

    private fun showCompletedNotification(
        taskId: String,
        fileName: String,
        destination: String,
        mimeType: String?,
    ) {
        val uri = Uri.parse(destination)
        val openIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mimeType ?: "application/octet-stream")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val pending = PendingIntent.getActivity(
            this,
            taskId.hashCode(),
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setContentTitle("下载完成")
            .setContentText(fileName)
            .setContentIntent(pending)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()
        notificationManager().notify(taskId.hashCode(), notification)
    }

    private fun showFailedNotification(fileName: String, message: String) {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_notify_error)
            .setContentTitle("下载失败")
            .setContentText("$fileName · $message")
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()
        notificationManager().notify(fileName.hashCode(), notification)
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            val channel = NotificationChannel(
                CHANNEL_ID,
                "文件下载",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "LANDeck 局域网文件下载进度"
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }
    }

    private fun notificationManager(): NotificationManager =
        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun acquireWakeLock() {
        try {
            val power = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = power.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "LANDeck:download",
            ).apply { acquire(10 * 60 * 1000L) }
        } catch (_: Exception) {
            // A foreground service remains enough for most transfers.
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (_: Exception) {
            // Best effort.
        }
        wakeLock = null
    }

    override fun onDestroy() {
        cancelled.set(true)
        try {
            activeConnection?.disconnect()
        } catch (_: Exception) {
            // Best effort.
        }
        releaseWakeLock()
        super.onDestroy()
    }

    private fun parseHeaders(json: String?): Map<String, String> {
        if (json.isNullOrBlank()) return emptyMap()
        return try {
            val objectValue = JSONObject(json)
            objectValue.keys().asSequence().associateWith { key ->
                objectValue.optString(key, "")
            }
        } catch (_: Exception) {
            emptyMap()
        }
    }

    private fun isForbiddenHeader(name: String): Boolean {
        return name.equals("host", true) ||
            name.equals("content-length", true) ||
            name.equals("connection", true) ||
            name.equals("transfer-encoding", true)
    }

    private fun isPrivateHost(host: String?): Boolean {
        if (host == null) return false
        if (host == "localhost" || host.endsWith(".local")) return true
        val parts = host.split(".")
        if (parts.size != 4) return false
        val bytes = parts.mapNotNull { it.toIntOrNull() }
        if (bytes.size != 4 || bytes.any { it !in 0..255 }) return false
        return bytes[0] == 10 ||
            (bytes[0] == 172 && bytes[1] in 16..31) ||
            (bytes[0] == 192 && bytes[1] == 168) ||
            (bytes[0] == 169 && bytes[1] == 254) ||
            bytes[0] == 127
    }

    private fun trustPrivateHost(connection: HttpsURLConnection) {
        try {
            val trustAll = arrayOf<TrustManager>(
                object : X509TrustManager {
                    override fun checkClientTrusted(chain: Array<X509Certificate>, authType: String) {}
                    override fun checkServerTrusted(chain: Array<X509Certificate>, authType: String) {}
                    override fun getAcceptedIssuers(): Array<X509Certificate> = emptyArray()
                },
            )
            val context = SSLContext.getInstance("TLS")
            context.init(null, trustAll, SecureRandom())
            connection.sslSocketFactory = context.socketFactory
            connection.hostnameVerifier = HostnameVerifier { _, _ -> true }
        } catch (_: Exception) {
            // Fall back to the platform trust store.
        }
    }
}

private class DownloadCancelledException : Exception()
private class DownloadStorageException(message: String) : Exception(message)
private class DownloadHttpException(message: String) : Exception(message)
