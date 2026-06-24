package com.direxio.ai

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private data class PendingSave(
        val bytes: ByteArray?,
        val path: String?,
        val fileName: String,
        val mimeType: String,
        val video: Boolean,
        val result: MethodChannel.Result
    )

    private var pendingSave: PendingSave? = null
    private val videoToolsExecutor = Executors.newSingleThreadExecutor()

    override fun getRenderMode(): RenderMode = RenderMode.texture

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "p2p_im/save_image"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "savePng" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val fileName = call.argument<String>("fileName")
                    if (bytes == null || bytes.isEmpty() || fileName.isNullOrBlank()) {
                        result.error("invalid_args", "Image bytes and fileName are required.", null)
                        return@setMethodCallHandler
                    }
                    if (needsLegacyStoragePermission()) {
                        pendingSave = PendingSave(
                            bytes = bytes,
                            path = null,
                            fileName = fileName,
                            mimeType = "image/png",
                            video = false,
                            result = result
                        )
                        requestPermissions(
                            arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                            saveImagePermissionRequestCode
                        )
                        return@setMethodCallHandler
                    }
                    try {
                        saveBytesToGallery(bytes, fileName, "image/png", video = false)
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("save_failed", error.localizedMessage, null)
                    }
                }
                "saveMediaFile" -> {
                    val path = call.argument<String>("path")
                    val fileName = call.argument<String>("fileName")
                    val mimeType = call.argument<String>("mimeType")
                    if (path.isNullOrBlank() || fileName.isNullOrBlank() || mimeType.isNullOrBlank()) {
                        result.error("invalid_args", "path, fileName and mimeType are required.", null)
                        return@setMethodCallHandler
                    }
                    val file = File(path)
                    if (!file.exists() || !file.isFile) {
                        result.error("media_not_found", "The media file does not exist.", path)
                        return@setMethodCallHandler
                    }
                    val isVideo = mimeType.lowercase().startsWith("video/")
                    if (needsLegacyStoragePermission()) {
                        pendingSave = PendingSave(
                            bytes = null,
                            path = path,
                            fileName = fileName,
                            mimeType = mimeType,
                            video = isVideo,
                            result = result
                        )
                        requestPermissions(
                            arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                            saveImagePermissionRequestCode
                        )
                        return@setMethodCallHandler
                    }
                    try {
                        saveFileToGallery(file, fileName, mimeType, isVideo)
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("save_failed", error.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "p2p_im/file_actions"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "previewFile" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error(
                            "file_preview_invalid_path",
                            "A non-empty file path is required.",
                            null
                        )
                        return@setMethodCallHandler
                    }
                    try {
                        previewFile(path)
                        result.success(null)
                    } catch (error: ActivityNotFoundException) {
                        result.error(
                            "file_preview_no_viewer",
                            "No app is available to preview this file.",
                            path
                        )
                    } catch (error: Exception) {
                        result.error(
                            "file_preview_failed",
                            error.localizedMessage,
                            path
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "p2p_im/video_tools"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "createThumbnail" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error(
                            "video_thumbnail_invalid_path",
                            "A non-empty video path is required.",
                            null
                        )
                        return@setMethodCallHandler
                    }
                    createVideoThumbnail(path, result)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode != saveImagePermissionRequestCode) {
            super.onRequestPermissionsResult(requestCode, permissions, grantResults)
            return
        }
        val save = pendingSave
        pendingSave = null
        if (save == null) {
            super.onRequestPermissionsResult(requestCode, permissions, grantResults)
            return
        }
        if (grantResults.firstOrNull() != PackageManager.PERMISSION_GRANTED) {
            save.result.error("permission_denied", "Storage permission was denied.", null)
            return
        }
        try {
            val bytes = save.bytes
            val path = save.path
            if (bytes != null) {
                saveBytesToGallery(bytes, save.fileName, save.mimeType, save.video)
            } else if (path != null) {
                saveFileToGallery(File(path), save.fileName, save.mimeType, save.video)
            } else {
                throw IllegalStateException("No pending media to save.")
            }
            save.result.success(null)
        } catch (error: Exception) {
            save.result.error("save_failed", error.localizedMessage, null)
        }
    }

    private fun needsLegacyStoragePermission(): Boolean {
        return Build.VERSION.SDK_INT in Build.VERSION_CODES.M until Build.VERSION_CODES.Q &&
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) !=
            PackageManager.PERMISSION_GRANTED
    }

    private fun saveBytesToGallery(
        bytes: ByteArray,
        fileName: String,
        mimeType: String,
        video: Boolean
    ) {
        saveToGallery(fileName, mimeType, video) { output ->
            output.write(bytes)
        }
    }

    private fun saveFileToGallery(
        file: File,
        fileName: String,
        mimeType: String,
        video: Boolean
    ) {
        if (!file.exists() || !file.isFile) {
            throw IllegalArgumentException("The media file does not exist.")
        }
        saveToGallery(fileName, mimeType, video) { output ->
            file.inputStream().use { input -> input.copyTo(output) }
        }
    }

    private fun saveToGallery(
        fileName: String,
        mimeType: String,
        video: Boolean,
        write: (java.io.OutputStream) -> Unit
    ) {
        val resolver = applicationContext.contentResolver
        val collection = if (video) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            }
        } else {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            }
        }
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
            put(MediaStore.Images.Media.MIME_TYPE, mimeType)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val directory = if (video) {
                    Environment.DIRECTORY_MOVIES
                } else {
                    Environment.DIRECTORY_PICTURES
                }
                put(
                    MediaStore.Images.Media.RELATIVE_PATH,
                    "$directory/P2P IM"
                )
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }
        val uri = resolver.insert(collection, values)
            ?: throw IllegalStateException("Failed to create gallery item.")
        try {
            resolver.openOutputStream(uri)?.use { output ->
                write(output)
            } ?: throw IllegalStateException("Failed to open gallery item.")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
            }
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            throw error
        }
    }

    private fun previewFile(path: String) {
        val file = File(path)
        if (!file.exists() || !file.isFile) {
            throw IllegalArgumentException("The file does not exist.")
        }
        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            file
        )
        val mimeType = mimeTypeFor(file.name)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mimeType)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(intent, file.name))
    }

    private fun createVideoThumbnail(path: String, result: MethodChannel.Result) {
        val file = File(path)
        if (!file.exists() || !file.isFile) {
            result.error("video_thumbnail_not_found", "The video file does not exist.", path)
            return
        }

        videoToolsExecutor.execute {
            try {
                val thumbnail = readVideoThumbnail(file)
                runOnUiThread { result.success(thumbnail) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("video_thumbnail_failed", error.localizedMessage, null)
                }
            }
        }
    }

    private fun readVideoThumbnail(file: File): Map<String, Any> {
        val retriever = android.media.MediaMetadataRetriever()
        try {
            retriever.setDataSource(file.absolutePath)
            val durationMs = retriever
                .extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull()
                ?.coerceAtLeast(0L)
                ?: 0L
            val frame = retriever.getFrameAtTime(
                0,
                android.media.MediaMetadataRetriever.OPTION_CLOSEST_SYNC
            )?.let { scaleBitmapToMaxSide(it, videoThumbnailMaxSide) }
                ?: throw IllegalStateException("Failed to decode video frame.")

            val output = ByteArrayOutputStream()
            if (!frame.compress(Bitmap.CompressFormat.JPEG, 78, output)) {
                throw IllegalStateException("Failed to encode video thumbnail.")
            }
            return mapOf(
                "bytes" to output.toByteArray(),
                "mimeType" to "image/jpeg",
                "width" to frame.width,
                "height" to frame.height,
                "durationMs" to durationMs.toInt()
            )
        } finally {
            retriever.release()
        }
    }

    private fun scaleBitmapToMaxSide(bitmap: Bitmap, maxSide: Int): Bitmap {
        val width = bitmap.width
        val height = bitmap.height
        val longest = maxOf(width, height)
        if (longest <= maxSide || longest <= 0) return bitmap
        val scale = maxSide.toFloat() / longest.toFloat()
        val targetWidth = (width * scale).toInt().coerceAtLeast(1)
        val targetHeight = (height * scale).toInt().coerceAtLeast(1)
        return Bitmap.createScaledBitmap(bitmap, targetWidth, targetHeight, true)
    }

    private fun mimeTypeFor(fileName: String): String {
        val extension = fileName.substringAfterLast('.', "").lowercase()
        if (extension.isBlank()) return "*/*"
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension) ?: "*/*"
    }

    private companion object {
        const val saveImagePermissionRequestCode = 9402
        const val videoThumbnailMaxSide = 720
    }
}
