package com.example.landeck

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.net.wifi.WifiManager
import android.provider.DocumentsContract
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null
    private var filePickerResult: MethodChannel.Result? = null
    private var saveFileResult: MethodChannel.Result? = null
    private var folderPickerResult: MethodChannel.Result? = null

    companion object {
        private const val REQUEST_PICK_FILES = 4101
        private const val REQUEST_SAVE_FILE = 4102
        private const val REQUEST_PICK_FOLDER = 4103
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
                "pickFolderFiles" -> {
                    if (filePickerResult != null || folderPickerResult != null) {
                        result.error("picker_busy", "已有文件选择器正在打开", null)
                        return@setMethodCallHandler
                    }
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                        addFlags(
                            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
                        )
                    }
                    folderPickerResult = result
                    try {
                        startActivityForResult(intent, REQUEST_PICK_FOLDER)
                    } catch (error: Exception) {
                        folderPickerResult = null
                        result.error("picker_unavailable", "无法打开文件夹选择器", null)
                    }
                }
                "pickSaveFile" -> {
                    val fileName = call.argument<String>("fileName") ?: "download"
                    try {
                        result.success(createInternalDownloadFile(fileName).toString())
                    } catch (error: Exception) {
                        result.error("storage_unavailable", "无法创建下载文件", error.message)
                    }
                }
                "listInternalFiles" -> {
                    try {
                        result.success(listInternalFiles(call.argument<String>("path")))
                    } catch (error: Exception) {
                        result.error("storage_unavailable", "无法读取下载目录", error.message)
                    }
                }
                "listInternalFilesRecursive" -> {
                    try {
                        result.success(listInternalFilesRecursive(call.argument<String>("path")))
                    } catch (error: Exception) {
                        result.error("storage_unavailable", "无法读取下载目录", error.message)
                    }
                }
                "createInternalFolder" -> {
                    try {
                        result.success(
                            createInternalFolder(
                                call.argument<String>("path"),
                                call.argument<String>("name") ?: "新建文件夹",
                            ),
                        )
                    } catch (error: Exception) {
                        result.error("storage_unavailable", "无法新建文件夹", error.message)
                    }
                }
                "createInternalFile" -> {
                    try {
                        result.success(
                            createInternalFile(
                                call.argument<String>("path"),
                                call.argument<String>("name") ?: "下载文件",
                            ).toString(),
                        )
                    } catch (error: Exception) {
                        result.error("storage_unavailable", "无法新建文件", error.message)
                    }
                }
                "renameInternalEntry" -> {
                    try {
                        result.success(
                            renameInternalEntry(
                                call.argument<String>("path") ?: "",
                                call.argument<String>("newName") ?: "",
                            ),
                        )
                    } catch (error: Exception) {
                        result.error("storage_unavailable", "无法重命名", error.message)
                    }
                }
                "deleteInternalEntry" -> {
                    try {
                        result.success(
                            deleteInternalEntry(call.argument<String>("path") ?: ""),
                        )
                    } catch (error: Exception) {
                        result.error("storage_unavailable", "无法删除", error.message)
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
        // A web page with no accept attribute sends an empty list. Passing an
        // empty EXTRA_MIME_TYPES makes some DocumentsUI builds show "no files".
        // An unknown extension (e.g. firmware .bin) must also degrade to */*
        // instead of silently filtering out every file.
        val unknownExtension = mimeTypes.any {
            it.startsWith(".") && resolveMime(it) == null
        }
        val wildcard = resolved.isEmpty() ||
            resolved.any { it == "*/*" } ||
            unknownExtension
        val type = if (wildcard) "*/*" else resolved.first()
        return Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            this.type = type
            if (!wildcard) {
                putExtra(Intent.EXTRA_MIME_TYPES, resolved.toTypedArray())
            }
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
            REQUEST_PICK_FOLDER -> {
                val pending = folderPickerResult
                folderPickerResult = null
                if (pending == null) return
                if (resultCode != Activity.RESULT_OK || data?.data == null) {
                    pending.success(emptyList<String>())
                    return
                }
                val treeUri = data.data!!
                try {
                    contentResolver.takePersistableUriPermission(
                        treeUri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION,
                    )
                } catch (_: SecurityException) {
                    // The temporary tree grant still allows this upload.
                }
                Thread {
                    val files = collectTreeFiles(treeUri)
                    runOnUiThread { pending.success(files) }
                }.start()
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

    /**
     * WebView cannot consume a directory URI, so expand the chosen tree into
     * the individual document URIs the page's file input can accept. The tree
     * grant itself is kept for the lifetime of the selection.
     */
    private fun collectTreeFiles(treeUri: Uri): List<String> {
        val files = mutableListOf<String>()
        try {
            val rootId = DocumentsContract.getTreeDocumentId(treeUri)
            collectTreeChildren(treeUri, rootId, files, 0)
        } catch (_: Exception) {
            // Unsupported provider: return whatever was collected.
        }
        return files
    }

    private fun collectTreeChildren(
        treeUri: Uri,
        parentId: String,
        files: MutableList<String>,
        depth: Int,
    ) {
        if (depth > 32 || files.size >= 500) return
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            treeUri,
            parentId,
        )
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
        )
        val cursor = contentResolver.query(childrenUri, projection, null, null, null)
            ?: return
        cursor.use { rows ->
            while (rows.moveToNext() && files.size < 500) {
                val documentId = rows.getString(0) ?: continue
                val mimeType = rows.getString(1) ?: ""
                if (mimeType == DocumentsContract.Document.MIME_TYPE_DIR) {
                    collectTreeChildren(treeUri, documentId, files, depth + 1)
                } else {
                    val documentUri = DocumentsContract.buildDocumentUriUsingTree(
                        treeUri,
                        documentId,
                    )
                    try {
                        contentResolver.takePersistableUriPermission(
                            documentUri,
                            Intent.FLAG_GRANT_READ_URI_PERMISSION,
                        )
                    } catch (_: SecurityException) {
                        // The tree grant covers descendants on most providers.
                    }
                    files.add(documentUri.toString())
                }
            }
        }
    }

    private fun internalDownloadsDir(): File {
        val dir = File(getExternalFilesDir(null), "Downloads")
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    private fun createInternalDownloadFile(fileName: String): Uri {
        val dir = internalDownloadsDir()
        val cleaned = fileName.map { char ->
            if (char.code < 32 || char in "\\/:*?\"<>|") '_' else char
        }.joinToString("").trim().trimStart('.').take(120)
        val safe = cleaned.ifBlank { "下载文件" }
        val dot = safe.lastIndexOf('.')
        val stem = if (dot > 0) safe.substring(0, dot) else safe
        val ext = if (dot > 0) safe.substring(dot) else ""
        var file = File(dir, safe)
        var index = 1
        while (file.exists()) {
            file = File(dir, "$stem ($index)$ext")
            index += 1
        }
        file.createNewFile()
        return Uri.fromFile(file)
    }

    private fun listInternalFiles(path: String?): List<Map<String, Any>> {
        val dir = resolveInternal(path)
        if (!dir.isDirectory) throw IllegalArgumentException("目录不存在")
        val base = internalDownloadsDir().canonicalFile
        return dir.listFiles()
            ?.sortedWith(
                compareByDescending<File> { it.isDirectory }
                    .thenBy { it.name.lowercase() },
            )
            ?.map { file ->
                mapOf(
                    "name" to file.name,
                    "path" to file.relativeTo(base).path.replace(File.separatorChar, '/'),
                    "uri" to if (file.isFile) {
                        FileProvider.getUriForFile(
                            this,
                            "$packageName.fileprovider",
                            file,
                        ).toString()
                    } else {
                        ""
                    },
                    "size" to if (file.isFile) file.length() else 0L,
                    "modified" to file.lastModified(),
                    "isDirectory" to file.isDirectory,
                )
            } ?: emptyList()
    }

    private fun listInternalFilesRecursive(path: String?): List<Map<String, Any>> {
        val dir = resolveInternal(path)
        if (!dir.isDirectory) throw IllegalArgumentException("目录不存在")
        val base = internalDownloadsDir().canonicalFile
        return dir.walkTopDown()
            .filter { it.isFile }
            .map { file ->
                mapOf(
                    "name" to file.name,
                    "path" to file.relativeTo(base).path.replace(File.separatorChar, '/'),
                    "uri" to FileProvider.getUriForFile(
                        this,
                        "$packageName.fileprovider",
                        file,
                    ).toString(),
                    "size" to file.length(),
                    "modified" to file.lastModified(),
                    "isDirectory" to false,
                )
            }
            .toList()
    }

    private fun resolveInternal(path: String?): File {
        val base = internalDownloadsDir().canonicalFile
        val requested = File(base, path ?: "").canonicalFile
        if (requested != base &&
            !requested.path.startsWith(base.path + File.separator)
        ) {
            throw IllegalArgumentException("路径越界")
        }
        return requested
    }

    private fun createInternalFile(path: String?, rawName: String): Uri {
        val dir = resolveInternal(path)
        if (!dir.isDirectory) throw IllegalArgumentException("目录不存在")
        val name = sanitizeInternalName(rawName).ifBlank { "下载文件" }
        val dot = name.lastIndexOf('.')
        val stem = if (dot > 0) name.substring(0, dot) else name
        val ext = if (dot > 0) name.substring(dot) else ""
        var file = File(dir, name)
        var index = 1
        while (file.exists()) {
            file = File(dir, "$stem ($index)$ext")
            index += 1
        }
        if (!file.createNewFile()) throw IllegalArgumentException("无法创建文件")
        return Uri.fromFile(file)
    }

    private fun createInternalFolder(path: String?, rawName: String): String {
        val dir = resolveInternal(path)
        if (!dir.isDirectory) throw IllegalArgumentException("目录不存在")
        val name = sanitizeInternalName(rawName)
        if (name.isBlank()) throw IllegalArgumentException("名称不能为空")
        val target = File(dir, name)
        if (target.exists()) throw IllegalArgumentException("同名文件或文件夹已存在")
        if (!target.mkdirs()) throw IllegalArgumentException("无法创建文件夹")
        return target.relativeTo(internalDownloadsDir()).path.replace(File.separatorChar, '/')
    }

    private fun renameInternalEntry(path: String, rawName: String): String {
        val source = resolveInternal(path)
        if (source == internalDownloadsDir().canonicalFile) {
            throw IllegalArgumentException("不能重命名根目录")
        }
        val name = sanitizeInternalName(rawName)
        if (name.isBlank()) throw IllegalArgumentException("名称不能为空")
        val target = File(source.parentFile, name)
        if (source == target) return path
        if (target.exists()) throw IllegalArgumentException("同名文件或文件夹已存在")
        if (!source.renameTo(target)) throw IllegalArgumentException("无法重命名")
        return target.relativeTo(internalDownloadsDir()).path.replace(File.separatorChar, '/')
    }

    private fun deleteInternalEntry(path: String): Boolean {
        val target = resolveInternal(path)
        if (target == internalDownloadsDir().canonicalFile) {
            throw IllegalArgumentException("不能删除根目录")
        }
        if (!target.exists()) return true
        return target.deleteRecursively()
    }

    private fun sanitizeInternalName(raw: String): String {
        return raw.map { char ->
            if (char.code < 32 || char in "\\/:*?\"<>|") '_' else char
        }.joinToString("").trim().trimStart('.').take(120)
    }

    private fun shareableUri(raw: String): Uri {
        if (raw.startsWith("file:")) {
            val path = Uri.parse(raw).path ?: raw.removePrefix("file://")
            return FileProvider.getUriForFile(
                this,
                "$packageName.fileprovider",
                File(path),
            )
        }
        return Uri.parse(raw)
    }

    private fun openFile(uriString: String?, mime: String): Boolean {
        if (uriString.isNullOrBlank()) return false
        return try {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(shareableUri(uriString), mime)
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
                putExtra(Intent.EXTRA_STREAM, shareableUri(uriString))
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
