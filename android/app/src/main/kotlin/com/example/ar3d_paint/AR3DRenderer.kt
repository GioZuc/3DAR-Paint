package com.example.ar3d_paint

import android.util.Log
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import com.google.ar.core.TrackingState
import com.google.ar.core.examples.java.common.helpers.DisplayRotationHelper
import com.google.ar.core.examples.java.common.samplerender.SampleRender
import com.google.ar.core.examples.java.common.samplerender.arcore.BackgroundRenderer
import com.google.ar.core.exceptions.CameraNotAvailableException
import io.flutter.plugin.common.EventChannel

class AR3DRenderer(val activity: MainActivity):
SampleRender.Renderer,DefaultLifecycleObserver{

companion object{const val TAG="AR3DRenderer"}

var poseEventSink:EventChannel.EventSink?=null

private var backgroundRenderer:BackgroundRenderer?=null
private var rendererReady=false
private val displayRotationHelper=DisplayRotationHelper(activity)
private var hasSetTextureNames=false
private var lastPoseSentMs=0L

val session get()=activity.arCoreSessionHelper.session

override fun onResume(owner:LifecycleOwner){
displayRotationHelper.onResume()
hasSetTextureNames=false
}

override fun onPause(owner:LifecycleOwner){
displayRotationHelper.onPause()
}

override fun onSurfaceCreated(render:SampleRender){
rendererReady=false
try{
backgroundRenderer=BackgroundRenderer(render)
backgroundRenderer!!.setUseDepthVisualization(render,false)
backgroundRenderer!!.setUseOcclusion(render,false)
rendererReady=true
}catch(e:Exception){
Log.e(TAG,"Renderer error $e")
}
}

override fun onSurfaceChanged(render:SampleRender,width:Int,height:Int){
displayRotationHelper.onSurfaceChanged(width,height)
}

override fun onDrawFrame(render:SampleRender){

if(!rendererReady)return
val bg=backgroundRenderer?:return
val session=session?:return

if(!hasSetTextureNames){
session.setCameraTextureNames(intArrayOf(bg.cameraColorTexture.textureId))
hasSetTextureNames=true
}

displayRotationHelper.updateSessionIfNeeded(session)

val frame=try{
session.update()
}catch(e:CameraNotAvailableException){
return
}

bg.updateDisplayGeometry(frame)

if(frame.timestamp!=0L){
bg.drawBackground(render)
}

val camera=frame.camera

if(camera.trackingState!=TrackingState.TRACKING)return

val now=System.currentTimeMillis()

if(now-lastPoseSentMs<33)return
lastPoseSentMs=now

val viewMatrix=FloatArray(16)
camera.getViewMatrix(viewMatrix,0)

val projMatrix=FloatArray(16)
camera.getProjectionMatrix(projMatrix,0,0.1f,100f)

val pos=camera.pose.translation

val z=camera.pose.zAxis

val data=HashMap<String,Any>()

data["view"]=viewMatrix.toList()
data["proj"]=projMatrix.toList()

data["pos"]=listOf(
pos[0],
pos[1],
pos[2]
)

data["forward"]=listOf(
-z[0],
-z[1],
-z[2]
)

activity.runOnUiThread{
poseEventSink?.success(data)
}

}
}