package de.ffuf.in_app_update

import android.app.Activity
import android.app.Activity.RESULT_OK
import android.content.Intent
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleObserver
import androidx.lifecycle.OnLifecycleEvent
import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.InstallStatus
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.lifecycle.FlutterLifecycleAdapter
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.common.PluginRegistry.Registrar

class InAppUpdatePlugin(private val activity: Activity) : MethodCallHandler,
  PluginRegistry.ActivityResultListener, FlutterPlugin {

  companion object {
    @JvmStatic
    fun registerWith(registrar: Registrar) {
      val channel = MethodChannel(registrar.messenger(), "in_app_update")
      val instance = InAppUpdatePlugin(registrar.activity())
      registrar.addActivityResultListener(instance)
      channel.setMethodCallHandler(instance)
    }

    private const val REQUEST_CODE_START_UPDATE = 1388276
  }

  inner class CustomObserver: LifecycleObserver {
    @OnLifecycleEvent(Lifecycle.Event.ON_RESUME)
    fun onResume() {
      appUpdateManager
              .appUpdateInfo
              .addOnSuccessListener { appUpdateInfo ->
                if (appUpdateInfo.updateAvailability()
                        == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS
                ) {
                  appUpdateManager.startUpdateFlowForResult(
                          appUpdateInfo,
                          AppUpdateType.IMMEDIATE,
                          activity,
                          REQUEST_CODE_START_UPDATE
                  )
                }
              }
    }
  }

  private var lifecycleObserver: CustomObserver? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    val lifecycle = FlutterLifecycleAdapter.getLifecycle(binding)
    lifecycleObserver = CustomObserver()

    lifecycle.addObserver(lifecycleObserver!!)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    val lifecycle = FlutterLifecycleAdapter.getLifecycle(binding)

    if (lifecycleObserver != null) lifecycle.removeObserver(lifecycleObserver!!)
  }

  private var updateResult: Result? = null
  private var appUpdateInfo: AppUpdateInfo? = null

  // Creates instance of the manager.
  private val appUpdateManager by lazy {
    AppUpdateManagerFactory.create(activity)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when {
      call.method == "checkForUpdate" -> checkForUpdate(result)
      call.method == "performImmediateUpdate" -> performImmediateUpdate(result)
      call.method == "startFlexibleUpdate" -> startFlexibleUpdate(result)
      call.method == "completeFlexibleUpdate" -> completeFlexibleUpdate(result)
      else -> result.notImplemented()
    }
  }

  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
    if (requestCode == REQUEST_CODE_START_UPDATE) {
      requireNotNull(updateResult) {
        "Fix your code!"
      }
      if (resultCode != RESULT_OK) {
        updateResult?.error("Update failed", resultCode.toString(), null)
      } else {
        updateResult?.success(null)
      }
      return true
    }
    return false
  }


  private fun performImmediateUpdate(result: Result) {
    requireNotNull(appUpdateInfo) {
      result.error("Call checkForUpdate first!", null, null)
    }

    updateResult = result
    appUpdateManager.startUpdateFlowForResult(
      appUpdateInfo,
      AppUpdateType.IMMEDIATE,
      activity,
      REQUEST_CODE_START_UPDATE
    )
  }

  private fun startFlexibleUpdate(result: Result) {
    requireNotNull(appUpdateInfo) {
      result.error("Call checkForUpdate first!", null, null)
    }

    updateResult = result
    appUpdateManager.startUpdateFlowForResult(
      appUpdateInfo,
      AppUpdateType.FLEXIBLE,
      activity,
      REQUEST_CODE_START_UPDATE
    )
    appUpdateManager.registerListener { state ->
      if (state.installStatus() == InstallStatus.DOWNLOADED) {
        result.success(null)
      } else if (state.installErrorCode() != null) {
        result.error("Error during installation", state.installErrorCode().toString(), null)
      }
    }
  }

  private fun completeFlexibleUpdate(result: Result) {
    requireNotNull(appUpdateInfo) {
      result.error("Call checkForUpdate first!", null, null)
    }

    appUpdateManager.completeUpdate()
  }

  private fun checkForUpdate(result: Result) {

    // Returns an intent object that you use to check for an update.
    val appUpdateInfoTask = appUpdateManager.appUpdateInfo

    // Checks that the platform will allow the specified type of update.
    appUpdateInfoTask.addOnSuccessListener { info ->
      appUpdateInfo = info
      if (info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE) {
        result.success(
          mapOf(
            "updateAvailable" to true,
            "immediateAllowed" to info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE),
            "flexibleAllowed" to info.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE)
          )
        )
      } else {
        result.success(
          mapOf(
            "updateAvailable" to true,
            "immediateAllowed" to false,
            "flexibleAllowed" to false
          )
        )
      }
    }
    appUpdateInfoTask.addOnFailureListener {
      result.error(it.message, null, null)
    }
  }
}
