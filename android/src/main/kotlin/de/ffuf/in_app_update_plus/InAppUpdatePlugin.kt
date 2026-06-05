package de.ffuf.in_app_update_plus

import android.app.Activity
import android.app.Activity.RESULT_CANCELED
import android.app.Activity.RESULT_OK
import android.app.Application
import android.content.Intent
import android.content.IntentSender.SendIntentException
import android.os.Bundle
import android.util.Log
import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.InstallState
import com.google.android.play.core.install.InstallStateUpdatedListener
import com.google.android.play.core.install.model.ActivityResult
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.InstallErrorCode
import com.google.android.play.core.install.model.InstallStatus
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

interface ActivityProvider {
    fun addActivityResultListener(callback: PluginRegistry.ActivityResultListener)
    fun removeActivityResultListener(callback: PluginRegistry.ActivityResultListener)
    fun activity(): Activity
}

class InAppUpdatePlugin : FlutterPlugin, MethodCallHandler,
    PluginRegistry.ActivityResultListener, Application.ActivityLifecycleCallbacks, ActivityAware,
    EventChannel.StreamHandler {

    companion object {
        private const val REQUEST_CODE_START_UPDATE = 1276
        private const val LOG_TAG = "in_app_update_plus"
    }

    private lateinit var channel: MethodChannel
    private lateinit var event: EventChannel
    private lateinit var installStateUpdatedListener: InstallStateUpdatedListener
    private var installStateSink: EventChannel.EventSink? = null

    private var activityProvider: ActivityProvider? = null
    private var activityResultListenerRegistered = false
    private var registeredApplication: Application? = null

    private var updateResult: Result? = null
    private var appUpdateType: Int? = null
    private var appUpdateInfo: AppUpdateInfo? = null
    private var appUpdateManager: AppUpdateManager? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "de.ffuf.in_app_update_plus/methods")
        channel.setMethodCallHandler(this)

        event = EventChannel(flutterPluginBinding.binaryMessenger, "de.ffuf.in_app_update_plus/stateEvents")
        event.setStreamHandler(this)

        installStateUpdatedListener = InstallStateUpdatedListener { installState ->
            onInstallStateUpdated(installState)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appUpdateManager?.unregisterListener(installStateUpdatedListener)
        removeActivityCallbacks()
        channel.setMethodCallHandler(null)
        event.setStreamHandler(null)
        appUpdateManager = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        installStateSink = events
    }

    override fun onCancel(arguments: Any?) {
        installStateSink = null
    }

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
        if (requestCode != REQUEST_CODE_START_UPDATE) {
            return false
        }

        when (appUpdateType) {
            AppUpdateType.IMMEDIATE -> {
                when (resultCode) {
                    RESULT_CANCELED -> finishPendingUpdateWithError(
                        "USER_DENIED_UPDATE",
                        resultCode.toString()
                    )
                    RESULT_OK -> finishPendingUpdateWithSuccess()
                    ActivityResult.RESULT_IN_APP_UPDATE_FAILED -> finishPendingUpdateWithError(
                        "IN_APP_UPDATE_FAILED",
                        "Some other error prevented either the user from providing consent or the update to proceed."
                    )
                    else -> finishPendingUpdateWithError(
                        "IN_APP_UPDATE_FAILED",
                        "Update flow finished with unexpected result code $resultCode."
                    )
                }
                return true
            }
            AppUpdateType.FLEXIBLE -> {
                when (resultCode) {
                    RESULT_CANCELED -> finishPendingUpdateWithError(
                        "USER_DENIED_UPDATE",
                        resultCode.toString()
                    )
                    ActivityResult.RESULT_IN_APP_UPDATE_FAILED -> finishPendingUpdateWithError(
                        "IN_APP_UPDATE_FAILED",
                        resultCode.toString()
                    )
                }
                return true
            }
        }

        return false
    }

    override fun onAttachedToActivity(activityPluginBinding: ActivityPluginBinding) {
        activityProvider = createActivityProvider(activityPluginBinding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        removeActivityCallbacks()
        activityProvider = null
    }

    override fun onReattachedToActivityForConfigChanges(activityPluginBinding: ActivityPluginBinding) {
        activityProvider = createActivityProvider(activityPluginBinding)
    }

    override fun onDetachedFromActivity() {
        removeActivityCallbacks()
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
                    try {
                        appUpdateManager?.startUpdateFlowForResult(
                            appUpdateInfo,
                            activity,
                            AppUpdateOptions.defaultOptions(AppUpdateType.IMMEDIATE),
                            REQUEST_CODE_START_UPDATE
                        )
                    } catch (e: SendIntentException) {
                        Log.e(LOG_TAG, "Could not resume immediate update flow", e)
                    }
                }
            }
    }

    private fun createActivityProvider(activityPluginBinding: ActivityPluginBinding): ActivityProvider {
        return object : ActivityProvider {
            override fun addActivityResultListener(callback: PluginRegistry.ActivityResultListener) {
                activityPluginBinding.addActivityResultListener(callback)
            }

            override fun removeActivityResultListener(callback: PluginRegistry.ActivityResultListener) {
                activityPluginBinding.removeActivityResultListener(callback)
            }

            override fun activity(): Activity {
                return activityPluginBinding.activity
            }
        }
    }

    private fun performImmediateUpdate(result: Result) = withAppState(result) { manager, info, activity ->
        startUpdateFlow(manager, info, activity, AppUpdateType.IMMEDIATE, result)
    }

    private fun startFlexibleUpdate(result: Result) = withAppState(result) { manager, info, activity ->
        startUpdateFlow(manager, info, activity, AppUpdateType.FLEXIBLE, result)
    }

    private fun completeFlexibleUpdate(result: Result) = withAppState(result) { manager, _, _ ->
        manager.completeUpdate()
            .addOnSuccessListener {
                result.success(null)
            }
            .addOnFailureListener {
                result.error("IN_APP_UPDATE_FAILED", it.message, null)
            }
    }

    private fun checkForUpdate(result: Result) {
        val provider = activityProvider
        if (provider == null) {
            result.error(
                "REQUIRE_FOREGROUND_ACTIVITY",
                "in_app_update_plus requires a foreground activity",
                null
            )
            return
        }

        ensureActivityCallbacksRegistered(provider)

        appUpdateManager?.unregisterListener(installStateUpdatedListener)
        appUpdateManager = AppUpdateManagerFactory.create(provider.activity())
        appUpdateManager?.registerListener(installStateUpdatedListener)

        val appUpdateInfoTask = appUpdateManager!!.appUpdateInfo
        appUpdateInfoTask.addOnSuccessListener { info ->
            appUpdateInfo = info
            result.success(
                mapOf(
                    "updateAvailability" to info.updateAvailability(),
                    "immediateAllowed" to info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE),
                    "immediateAllowedPreconditions" to info.getFailedUpdatePreconditions(
                        AppUpdateOptions.defaultOptions(AppUpdateType.IMMEDIATE)
                    ).map { it.toInt() }.toList(),
                    "flexibleAllowed" to info.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE),
                    "flexibleAllowedPreconditions" to info.getFailedUpdatePreconditions(
                        AppUpdateOptions.defaultOptions(AppUpdateType.FLEXIBLE)
                    ).map { it.toInt() }.toList(),
                    "availableVersionCode" to info.availableVersionCode(),
                    "installStatus" to info.installStatus(),
                    "packageName" to info.packageName(),
                    "clientVersionStalenessDays" to info.clientVersionStalenessDays(),
                    "updatePriority" to info.updatePriority()
                )
            )
        }
        appUpdateInfoTask.addOnFailureListener {
            result.error("TASK_FAILURE", it.message, null)
        }
    }

    private fun startUpdateFlow(
        manager: AppUpdateManager,
        info: AppUpdateInfo,
        activity: Activity,
        updateType: Int,
        result: Result
    ) {
        if (updateResult != null) {
            result.error(
                "UPDATE_ALREADY_IN_PROGRESS",
                "An in-app update flow is already in progress.",
                null
            )
            return
        }

        appUpdateType = updateType
        updateResult = result
        try {
            manager.startUpdateFlowForResult(
                info,
                activity,
                AppUpdateOptions.defaultOptions(updateType),
                REQUEST_CODE_START_UPDATE
            )
        } catch (e: SendIntentException) {
            finishPendingUpdateWithError(
                "IN_APP_UPDATE_FAILED",
                "Could not start update flow: ${e.message}"
            )
        }
    }

    private fun withAppState(
        result: Result,
        block: (AppUpdateManager, AppUpdateInfo, Activity) -> Unit
    ) {
        val info = appUpdateInfo
        if (info == null) {
            result.error("REQUIRE_CHECK_FOR_UPDATE", "Call checkForUpdate first!", null)
            return
        }

        val manager = appUpdateManager
        if (manager == null) {
            result.error("REQUIRE_CHECK_FOR_UPDATE", "Call checkForUpdate first!", null)
            return
        }

        val provider = activityProvider
        if (provider == null) {
            result.error(
                "REQUIRE_FOREGROUND_ACTIVITY",
                "in_app_update_plus requires a foreground activity",
                null
            )
            return
        }

        block(manager, info, provider.activity())
    }

    private fun ensureActivityCallbacksRegistered(provider: ActivityProvider) {
        if (!activityResultListenerRegistered) {
            provider.addActivityResultListener(this)
            activityResultListenerRegistered = true
        }

        val application = provider.activity().application
        if (registeredApplication !== application) {
            registeredApplication?.unregisterActivityLifecycleCallbacks(this)
            application.registerActivityLifecycleCallbacks(this)
            registeredApplication = application
        }
    }

    private fun removeActivityCallbacks() {
        if (activityResultListenerRegistered) {
            activityProvider?.removeActivityResultListener(this)
            activityResultListenerRegistered = false
        }
        registeredApplication?.unregisterActivityLifecycleCallbacks(this)
        registeredApplication = null
    }

    private fun onInstallStateUpdated(installState: InstallState) {
        addState(installState.installStatus())

        if (appUpdateType != AppUpdateType.FLEXIBLE) {
            return
        }

        when {
            installState.installStatus() == InstallStatus.DOWNLOADED -> {
                finishPendingUpdateWithSuccess()
            }
            installState.installErrorCode() != InstallErrorCode.NO_ERROR -> {
                finishPendingUpdateWithError(
                    "IN_APP_UPDATE_FAILED",
                    installState.installErrorCode().toString()
                )
            }
        }
    }

    private fun addState(status: Int) {
        installStateSink?.success(status)
    }

    private fun finishPendingUpdateWithSuccess() {
        updateResult?.success(null)
        updateResult = null
        appUpdateType = null
    }

    private fun finishPendingUpdateWithError(code: String, message: String) {
        updateResult?.error(code, message, null)
        updateResult = null
        appUpdateType = null
    }
}
