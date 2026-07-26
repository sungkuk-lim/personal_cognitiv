package com.theNext.personal_cognitive

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var pendingPickerResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BACKUP_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickJsonBackup" -> openJsonPicker(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun openJsonPicker(result: MethodChannel.Result) {
        if (pendingPickerResult != null) {
            result.error("busy", "Picker already open", null)
            return
        }
        pendingPickerResult = result
        val intent =
            Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "application/json"
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
        try {
            @Suppress("DEPRECATION")
            startActivityForResult(intent, REQUEST_PICK_JSON)
        } catch (e: Exception) {
            pendingPickerResult = null
            result.error("picker_failed", e.message, null)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_PICK_JSON) {
            val callback = pendingPickerResult
            pendingPickerResult = null
            if (callback == null) {
                super.onActivityResult(requestCode, resultCode, data)
                return
            }
            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                callback.success(null)
                return
            }
            try {
                val text =
                    contentResolver.openInputStream(data.data!!)?.bufferedReader()?.use { it.readText() }
                callback.success(text)
            } catch (e: Exception) {
                callback.error("read_failed", e.message, null)
            }
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    companion object {
        private const val BACKUP_CHANNEL = "com.thenext.personal_cognitive/backup"
        private const val REQUEST_PICK_JSON = 48291
    }
}
