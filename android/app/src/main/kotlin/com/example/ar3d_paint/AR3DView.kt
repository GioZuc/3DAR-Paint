package com.example.ar3d_paint

import android.graphics.PixelFormat
import android.opengl.GLSurfaceView
import android.widget.FrameLayout
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner

class AR3DView(val activity: MainActivity) : DefaultLifecycleObserver {

    val surfaceView: GLSurfaceView = GLSurfaceView(activity).apply {
        preserveEGLContextOnPause = true
        setEGLContextClientVersion(2)
        setEGLConfigChooser(8, 8, 8, 8, 16, 0)
        holder.setFormat(PixelFormat.TRANSLUCENT)
        setZOrderOnTop(false)
    }

    fun attachToWindow() {
        // Aspetta che Flutter abbia già aggiunto il suo FlutterView al decorView,
        // poi inseriamo la GLSurfaceView in posizione 0 (sotto tutto).
        val decorView = activity.window.decorView as FrameLayout
        val params = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
        decorView.addView(surfaceView, 0, params)
    }

    override fun onResume(owner: LifecycleOwner) {
        surfaceView.onResume()
    }

    override fun onPause(owner: LifecycleOwner) {
        surfaceView.onPause()
    }
}
