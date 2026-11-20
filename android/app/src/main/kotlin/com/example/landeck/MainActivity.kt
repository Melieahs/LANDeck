package com.example.landeck

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.net.wifi.WifiManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null
    private var filePickerResult: MethodChannel.Result? = null
    private var saveFileResult: MethodChannel.Result? = null

    companion object {
        private const val REQUEST_PICK_FILES = 4101
        private const val REQUEST_SAVE_FILE = 4102
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        setupNetworkChannel(flutterEngine)
        setupFileChannel(flutterEngine)
        setupDownloadChannel(flutterEngine)
    }

    private fun setupNetworkChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.landeck/network",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "acquireMulticastLock" -> {
                    try {
                        if (multicastLock == null) {
                            val wifi = applicationContext
                                .getSystemService(Context.WIFI_SERVICE) as WifiManager
                            multicastLock = wifi.createMulticastLock("landeck_mdns").apply {
                                setReferenceCounted(false)
                            }
                        }
                        if (multicastLock?.isHeld != true) {
                            multicastLock?.acquire()
                        }
                        result.success(true)
                    } catch (error: Exception) {
                        result.error("multicast_lock_failed", error.message, null)
                    }
                }
                "releaseMulticastLock" -> {
                    try {
                        if (multicastLock?.isHeld == true) {
                            multicastLock?.release()
                        }
                        result.success(true)
                    } catch (error: Exception) {
                        result.error("multicast_unlock_failed", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun setupFileChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.landeck/files",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickFiles" -> {
                    if (filePickerResult != null) {
                        result.error("picker_busy", "已有文件选择器正在打开", null)
                        return@setMethodCallHandler
                    }
                    val acceptTypes = call.argument<List<String>>("acceptTypes")
                        ?: listOf("*/*")
                    val multiple = call.argument<Boolean>("multiple") ?: false
                    val intent = buildOpenDocumentIntent(acceptTypes, multiple)
                    filePickerResult = result
                    try {
                        startActivityForResult(
                            Intent.createChooser(intent, "选择文件"),
                            REQUEST_PICK_FILES,
                        )
                    } catch (error: Exception) {
                        filePickerResult = null
                        result.error("picker_unavailable", "无法打开系统文件选择器", null)
                    }
                }
                "pickSaveFile" -> {
                    if (saveFileResult != null) {
                        result.error("picker_busy", "已有保存选择器正在打开", null)
                        return@setMethodCallHandler
                    }
                    val fileName = call.argument<String>("fileName") ?: "download"
                    val mimeType = call.argument<String>("mimeType")
                        ?: "application/octet-stream"
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = mimeType
                        putExtra(Intent.EXTRA_TITLE, fileName)
                        addFlags(
                            Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                Intent.FLAG_GRANT_READ_URI_PERMISSION,
                        )
                    }
                    saveFileResult = result
                    try {
                        startActivityForResult(intent, REQUEST_SAVE_FILE)
                    } catch (error: Exception) {
                        saveFileResult = null
                        result.error("picker_unavailable", "无法打开保存位置选择器", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun setupDownloadChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.landeck/downloads",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val taskId = call.argument<String>("taskId")
                    val url = call.argument<String>("url")
                    val destination = call.argument<String>("destinationUri")
                    if (taskId == null || url == null || destination == null) {
                        result.error("bad_args", "下载参数不完整", null)
                        return@setMethodCallHandler
                    }
                    val intent = Intent(this, DownloadService::class.java).apply {
                        action = DownloadService.ACTION_START
                        putExtra(DownloadService.EXTRA_TASK_ID, taskId)
                        putExtra(DownloadService.EXTRA_URL, url)
                        putExtra(
                            DownloadService.EXTRA_FILE_NAME,
                            call.argument<String>("fileName") ?: "download",
                        )
                        putExtra(
                            DownloadService.EXTRA_MIME,
                            call.argument<String>("mimeType"),
                        )
                        putExtra(DownloadService.EXTRA_DESTINATION, destination)
                        putExtra(
                            DownloadService.EXTRA_HEADERS,
                            call.argument<String>("headers"),
                        )
                    }
                    try {
                        ContextCompat.startForegroundService(this, intent)
                        result.success(true)
                    } catch (error: Exception) {
                        result.error("service_unavailable", "无法启动下载服务", null)
                    }
                }
                "cancel" -> {
                    val taskId = call.argument<String>("taskId")
                    if (taskId != null) {
                        val intent = Intent(this, DownloadService::class.java).apply {
                            action = DownloadService.ACTION_CANCEL
                            putExtra(DownloadService.EXTRA_TASK_ID, taskId)
                        }
                        try {
                            startService(intent)
                        } catch (_: Exception) {
                            // The service may already be gone.
                        }
                    }
                    result.success(true)
                }
                "query" -> {
                    val taskId = call.arguments as? String
                    result.success(
                        if (taskId == null) null
                        else DownloadService.readStatus(this, taskId),
                    )
                }
                "open" -> {
                    val uri = call.argument<String>("uri")
                    val mime = call.argument<String>("mimeType")
                        ?: "application/octet-stream"
                    result.success(openFile(uri, mime))
                }
                "share" -> {
                    val uri = call.argument<String>("uri")
                    val mime = call.argument<String>("mimeType")
                        ?: "application/octet-stream"
                    val fileName = call.argument<String>("fileName") ?: "文件"
                    result.success(shareFile(uri, mime, fileName))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun buildOpenDocumentIntent(
        acceptTypes: List<String>,
        multiple: Boolean,
    ): Intent {
        val mimeTypes = acceptTypes
            .flatMap { it.split(',') }
            .map { it.trim() }
            .filter { it.isNotEmpty() }
        val resolved = mimeTypes.mapNotNull { resolveMime(it) }.distinct()
        val type = when {
            resolved.isEmpty() -> "*/*"
            resolved.any { it == "*/*" } -> "*/*"
            else -> resolved.first()
        }
        return Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            this.type = type
            putExtra(Intent.EXTRA_MIME_TYPES, resolved.toTypedArray())
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple)
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
        }
    }

    private fun resolveMime(value: String): String? {
        if (value == "*/*" || value.contains("/")) return value
        if (!value.startsWith(".")) return null
        return when (value.lowercase()) {
            ".jpg", ".jpeg" -> "image/jpeg"
            ".png" -> "image/png"
            ".gif" -> "image/gif"
            ".webp" -> "image/webp"
            ".mp4" -> "video/mp4"
            ".mov" -> "video/quicktime"
            ".mp3" -> "audio/mpeg"
            ".wav" -> "audio/wav"
            ".pdf" -> "application/pdf"
            ".json" -> "application/json"
            ".txt" -> "text/plain"
            ".xml" -> "application/xml"
            ".yaml", ".yml" -> "application/yaml"
            ".zip" -> "application/zip"
            ".apk" -> "application/vnd.android.package-archive"
            ".doc" -> "application/msword"
            ".docx" ->
                "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
            ".xls" -> "application/vnd.ms-excel"
            ".xlsx" ->
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            else -> null
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            REQUEST_PICK_FILES -> {
                val pending = filePickerResult
                filePickerResult = null
                if (pending == null) return
                if (resultCode != Activity.RESULT_OK || data == null) {
                    pending.success(emptyList<String>())
                    return
                }
                val uris = mutableListOf<Uri>()
                val clip = data.clipData
                if (clip != null) {
                    for (index in 0 until clip.itemCount) {
                        clip.getItemAt(index)?.uri?.let { uris.add(it) }
                    }
                } else {
                    data.data?.let { uris.add(it) }
                }
                for (uri in uris) {
                    try {
                        contentResolver.takePersistableUriPermission(
                            uri,
                            Intent.FLAG_GRANT_READ_URI_PERMISSION,
                        )
                    } catch (_: SecurityException) {
                        // Some providers only grant temporary access.
                    }
                }
                pending.success(uris.map { it.toString() })
            }
            REQUEST_SAVE_FILE -> {
                val pending = saveFileResult
                saveFileResult = null
                if (pending == null) return
                if (resultCode != Activity.RESULT_OK || data?.data == null) {
                    pending.success(null)
                    return
                }
                val uri = data.data!!
                try {
                    contentResolver.takePersistableUriPermission(
                        uri,
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                            Intent.FLAG_GRANT_READ_URI_PERMISSION,
                    )
                } catch (_: SecurityException) {
                    // The write grant is still valid for this session.
                }
                pending.success(uri.toString())
            }
        }
    }

    private fun openFile(uriString: String?, mime: String): Boolean {
        if (uriString.isNullOrBlank()) return false
        return try {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(Uri.parse(uriString), mime)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun shareFile(uriString: String?, mime: String, fileName: String): Boolean {
        if (uriString.isNullOrBlank()) return false
        return try {
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = mime
                putExtra(Intent.EXTRA_STREAM, Uri.parse(uriString))
                putExtra(Intent.EXTRA_TITLE, fileName)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(intent, "分享文件"))
            true
        } catch (_: Exception) {
            false
        }
    }
}
