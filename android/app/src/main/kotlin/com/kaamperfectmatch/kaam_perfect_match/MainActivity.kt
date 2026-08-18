package com.kaamperfectmatch.kaam_perfect_match

import android.app.Activity
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.InstallStateUpdatedListener
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.InstallStatus
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var updates: AppUpdateManager
    private var events: EventChannel.EventSink? = null
    private val listener = InstallStateUpdatedListener { state ->
        events?.success(when (state.installStatus()) {
            InstallStatus.DOWNLOADED -> "downloaded"
            InstallStatus.DOWNLOADING, InstallStatus.PENDING -> "in_progress"
            else -> "unavailable"
        })
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        updates = AppUpdateManagerFactory.create(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.kaamperfectmatch.kaam/play_updates")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "check" -> updates.appUpdateInfo
                        .addOnSuccessListener { info -> result.success(availability(info.updateAvailability(), info.installStatus())) }
                        .addOnFailureListener { result.success("unavailable") }
                    "start" -> {
                        val immediate = call.argument<String>("type") == "immediate"
                        updates.appUpdateInfo.addOnSuccessListener { info ->
                            val type = if (immediate) AppUpdateType.IMMEDIATE else AppUpdateType.FLEXIBLE
                            if (info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE && info.isUpdateTypeAllowed(type)) {
                                updates.startUpdateFlowForResult(info, this, AppUpdateOptions.newBuilder(type).build(), REQUEST_UPDATE)
                                result.success(true)
                            } else result.success(false)
                        }.addOnFailureListener { result.success(false) }
                    }
                    "completeFlexible" -> { updates.completeUpdate(); result.success(true) }
                    else -> result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.kaamperfectmatch.kaam/play_update_status")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) { events = sink; updates.registerListener(listener) }
                override fun onCancel(arguments: Any?) { updates.unregisterListener(listener); events = null }
            })
    }

    override fun onResume() {
        super.onResume()
        if (!::updates.isInitialized) return
        updates.appUpdateInfo.addOnSuccessListener { info ->
            if (info.updateAvailability() == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS) {
                updates.startUpdateFlowForResult(info, this, AppUpdateOptions.newBuilder(AppUpdateType.IMMEDIATE).build(), REQUEST_UPDATE)
            }
            events?.success(availability(info.updateAvailability(), info.installStatus()))
        }
    }

    private fun availability(availability: Int, status: Int): String = when {
        status == InstallStatus.DOWNLOADED -> "downloaded"
        availability == UpdateAvailability.UPDATE_AVAILABLE -> "available"
        availability == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS -> "in_progress"
        else -> "unavailable"
    }

    companion object { private const val REQUEST_UPDATE = 7121 }
}
