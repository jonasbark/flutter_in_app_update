package de.ffuf.in_app_update

import android.app.Activity
import android.app.Activity.RESULT_OK
import android.app.Application
import android.content.Intent
import android.os.Bundle
import androidx.annotation.NonNull
import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.InstallStatus
import com.google.android.play.core.install.model.InstallErrorCode
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

interface ActivityProvider {
    fun addActivityResultListener(callback: PluginRegistry.ActivityResultListener)
    fun activity(): Activity?
}

class InAppUpdatePlugin : FlutterPlugin, MethodCallHandler,
    PluginRegistry.ActivityResultListener, Application.ActivityLifecycleCallbacks, ActivityAware {

    companion object {
        private const val REQUEST_CODE_START_UPDATE = 1276
    }

    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(
          flutterPluginBinding.binaryMessenger,
          "in_app_update"
        )
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    private var activityProvider: ActivityProvider? = null

    private var updateResult: Result? = null
    private var appUpdateType: Int? = null
    private var appUpdateInfo: AppUpdateInfo? = null
    private var appUpdateManager: AppUpdateManager? = null

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
          "checkForUpdate" -> checkForUpdate(result)
          "performImmediateUpdate" -> performImmediateUpdate(result)
          "startFlexibleUpdate" -> startFlexibleUpdate(result)
          "completeFlexibleUpdate" -> completeFlexibleUpdate(result)
            else -> result.notImplemented()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == REQUEST_CODE_START_UPDATE && appUpdateType == AppUpdateType.IMMEDIATE) {
            if (resultCode != RESULT_OK) {
                updateResult?.error("Update failed", resultCode.toString(), null)
            } else {
                updateResult?.success(null)
            }
            updateResult = null
            return true
        }
        return false
    }


    override fun onAttachedToActivity(activityPluginBinding: ActivityPluginBinding) {
        activityProvider = object : ActivityProvider {
            override fun addActivityResultListener(callback: PluginRegistry.ActivityResultListener) {
                activityPluginBinding.addActivityResultListener(callback)
            }

            override fun activity(): Activity? {
                return activityPluginBinding.activity
            }
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityProvider = null
    }

    override fun onReattachedToActivityForConfigChanges(activityPluginBinding: ActivityPluginBinding) {
        activityProvider = object : ActivityProvider {
            override fun addActivityResultListener(callback: PluginRegistry.ActivityResultListener) {
                activityPluginBinding.addActivityResultListener(callback)
            }

            override fun activity(): Activity? {
                return activityPluginBinding.activity
            }
        }
    }

    override fun onDetachedFromActivity() {
        activityProvider = null
    }

    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {}

    override fun onActivityPaused(activity: Activity) {}

    override fun onActivityStarted(activity: Activity) {}

    override fun onActivityDestroyed(activity: Activity) {}

    override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}

    override fun onActivityStopped(activity: Activity) {}

    override fun onActivityResumed(activity: Activity) {
        appUpdateManager
            ?.appUpdateInfo
            ?.addOnSuccessListener { appUpdateInfo ->
                if (appUpdateInfo.updateAvailability()
                    == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS
                    && appUpdateType == AppUpdateType.IMMEDIATE
                ) {
                    appUpdateManager?.startUpdateFlowForResult(
                      appUpdateInfo,
                      AppUpdateType.IMMEDIATE,
                      activity,
                      REQUEST_CODE_START_UPDATE
                    )
                }
            }
    }

    private fun performImmediateUpdate(result: Result) = checkAppState(result) {
        appUpdateType = AppUpdateType.IMMEDIATE
        updateResult = result
        appUpdateManager?.startUpdateFlowForResult(
          appUpdateInfo,
          AppUpdateType.IMMEDIATE,
          activityProvider?.activity(),
          REQUEST_CODE_START_UPDATE
        )
    }

    private fun checkAppState(result: Result, block: () -> Unit) {
        requireNotNull(appUpdateInfo) {
            result.error("Call checkForUpdate first!", null, null)
        }
        requireNotNull(activityProvider?.activity()) {
            result.error("in_app_update requires a foreground activity", null, null)
        }
        requireNotNull(appUpdateManager) {
            result.error("Call checkForUpdate first!", null, null)
        }
        block()
    }

    private fun startFlexibleUpdate(result: Result) = checkAppState(result) {
        appUpdateType = AppUpdateType.FLEXIBLE
        updateResult = result
        appUpdateManager?.startUpdateFlowForResult(
          appUpdateInfo,
          AppUpdateType.FLEXIBLE,
          activityProvider?.activity(),
          REQUEST_CODE_START_UPDATE
        )
        appUpdateManager?.registerListener { state ->
            if (state.installStatus() == InstallStatus.DOWNLOADED) {
                updateResult?.success(null)
                updateResult = null
            } else if (state.installErrorCode() != InstallErrorCode.NO_ERROR) {
                updateResult?.error(
                  "Error during installation",
                  state.installErrorCode().toString(),
                  null
                )
                updateResult = null
            }
        }
    }

    private fun completeFlexibleUpdate(result: Result) = checkAppState(result) {
        appUpdateManager?.completeUpdate()
    }

    private fun checkForUpdate(result: Result) {
        requireNotNull(activityProvider?.activity()) {
            result.error("in_app_update requires a foreground activity", null, null)
        }

        activityProvider?.addActivityResultListener(this)
        activityProvider?.activity()?.application?.registerActivityLifecycleCallbacks(this)

        appUpdateManager = AppUpdateManagerFactory.create(activityProvider?.activity())

        // Returns an intent object that you use to check for an update.
        val appUpdateInfoTask = appUpdateManager!!.appUpdateInfo

        // Checks that the platform will allow the specified type of update.
        appUpdateInfoTask.addOnSuccessListener { info ->
            appUpdateInfo = info
            result.success(
                  mapOf(
                    "updateAvailability" to info.updateAvailability(),
                    "immediateAllowed" to info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE),
                    "flexibleAllowed" to info.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE),
                    "availableVersionCode" to info.availableVersionCode(),
                    "installStatus" to info.installStatus(),
                    "packageName" to info.packageName(),
                    "clientVersionStalenessDays" to info.clientVersionStalenessDays(),
                    "updatePriority" to info.updatePriority()
                  )
            )
        }
        appUpdateInfoTask.addOnFailureListener {
            result.error(it.message, null, null)
        }
    }
}
