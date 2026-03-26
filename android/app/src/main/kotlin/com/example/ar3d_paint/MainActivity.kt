package com.example.ar3d_paint

import android.graphics.PixelFormat
import android.os.Bundle
import android.util.Log
import android.widget.Toast
import com.google.ar.core.Config
import com.google.ar.core.Session
import com.google.ar.core.examples.java.common.helpers.CameraPermissionHelper
import com.google.ar.core.examples.java.common.samplerender.SampleRender
import com.google.ar.core.exceptions.CameraNotAvailableException
import com.google.ar.core.exceptions.UnavailableApkTooOldException
import com.google.ar.core.exceptions.UnavailableDeviceNotCompatibleException
import com.google.ar.core.exceptions.UnavailableSdkTooOldException
import com.google.ar.core.exceptions.UnavailableUserDeclinedInstallationException
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.TransparencyMode   // AGGIUNTO
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val TAG = "AR3DPaint"
        const val METHOD_CHANNEL = "ar3d_paint/arcore"
        const val EVENT_CHANNEL = "ar3d_paint/camera_pose"
    }

    lateinit var arCoreSessionHelper: ARCoreSessionLifecycleHelper
    lateinit var renderer: AR3DRenderer
    lateinit var arView: AR3DView

    // AGGIUNTO (modifica chiave)
    override fun getTransparencyMode(): TransparencyMode {
        return TransparencyMode.transparent
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        window.setFormat(PixelFormat.TRANSLUCENT)
        super.onCreate(savedInstanceState)

        arCoreSessionHelper = ARCoreSessionLifecycleHelper(this)
        arCoreSessionHelper.exceptionCallback = { exception ->
            val message = when (exception) {
                is UnavailableUserDeclinedInstallationException -> "Installa Google Play Services for AR"
                is UnavailableApkTooOldException -> "Aggiorna ARCore"
                is UnavailableSdkTooOldException -> "Aggiorna l'app"
                is UnavailableDeviceNotCompatibleException -> "Dispositivo non compatibile con AR"
                is CameraNotAvailableException -> "Camera non disponibile. Riavvia l'app."
                else -> "Errore AR: $exception"
            }

            Log.e(TAG, "ARCore exception: $exception")

            runOnUiThread {
                Toast.makeText(this, message, Toast.LENGTH_LONG).show()
            }
        }

        arCoreSessionHelper.beforeSessionResume = ::configureSession
        lifecycle.addObserver(arCoreSessionHelper)

        renderer = AR3DRenderer(this)
        lifecycle.addObserver(renderer)

        arView = AR3DView(this)
        lifecycle.addObserver(arView)

        SampleRender(arView.surfaceView, renderer, assets)

        window.decorView.post {
            arView.attachToWindow()
        }
    }

    fun configureSession(session: Session) {
        session.configure(
            session.config.apply {
                updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
                planeFindingMode = Config.PlaneFindingMode.HORIZONTAL_AND_VERTICAL
                lightEstimationMode = Config.LightEstimationMode.DISABLED
            }
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ping" -> result.success("pong")
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {

                override fun onListen(a: Any?, sink: EventChannel.EventSink?) {
                    Log.d(TAG, "EventChannel listening")
                    renderer.poseEventSink = sink
                }

                override fun onCancel(a: Any?) {
                    renderer.poseEventSink = null
                }
            })
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        results: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, results)

        if (!CameraPermissionHelper.hasCameraPermission(this)) {
            Toast.makeText(this,"Permesso camera necessario",Toast.LENGTH_LONG).show()

            if (!CameraPermissionHelper.shouldShowRequestPermissionRationale(this)) {
                CameraPermissionHelper.launchPermissionSettings(this)
            }

            finish()
        }
    }
}