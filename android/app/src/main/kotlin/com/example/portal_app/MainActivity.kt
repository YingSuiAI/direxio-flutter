package com.example.portal_app

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private data class PendingSave(
        val bytes: ByteArray,
        val fileName: String,
        val result: MethodChannel.Result
    )

    private var pendingSave: PendingSave? = null

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
                        pendingSave = PendingSave(bytes, fileName, result)
                        requestPermissions(
                            arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                            saveImagePermissionRequestCode
                        )
                        return@setMethodCallHandler
                    }
                    try {
                        savePngToPictures(bytes, fileName)
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
            savePngToPictures(save.bytes, save.fileName)
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

    private fun savePngToPictures(bytes: ByteArray, fileName: String) {
        val resolver = applicationContext.contentResolver
        val imageCollection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        }
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(
                    MediaStore.Images.Media.RELATIVE_PATH,
                    "${Environment.DIRECTORY_PICTURES}/P2P IM"
                )
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }
        val uri = resolver.insert(imageCollection, values)
            ?: throw IllegalStateException("Failed to create gallery item.")
        try {
            resolver.openOutputStream(uri)?.use { output ->
                output.write(bytes)
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

    private fun mimeTypeFor(fileName: String): String {
        val extension = fileName.substringAfterLast('.', "").lowercase()
        if (extension.isBlank()) return "*/*"
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension) ?: "*/*"
    }

    private companion object {
        const val saveImagePermissionRequestCode = 9402
    }
}
