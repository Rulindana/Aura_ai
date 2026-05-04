package com.example.aura_ai

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Handler
import android.os.HandlerThread
import android.util.DisplayMetrics
import android.view.WindowManager
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer

object AuraScreenCaptureManager {
    private var projectionResultCode: Int? = null
    private var projectionData: Intent? = null
    private var mediaProjection: MediaProjection? = null
    private var imageReader: ImageReader? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var captureThread: HandlerThread? = null
    private var captureHandler: Handler? = null

    fun isReady(): Boolean {
        return projectionResultCode != null && projectionData != null
    }

    fun saveProjectionConsent(resultCode: Int, data: Intent?) {
        projectionResultCode = resultCode
        projectionData = data
        mediaProjection?.stop()
        mediaProjection = null
    }

    fun clearSession() {
        projectionResultCode = null
        projectionData = null
        mediaProjection?.stop()
        mediaProjection = null
        cleanupCaptureResources()
    }

    fun captureAndLaunch(context: Context): Boolean {
        val resultCode = projectionResultCode ?: return false
        val resultData = projectionData ?: return false

        val appContext = context.applicationContext
        val projectionManager =
            appContext.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        if (mediaProjection == null) {
            mediaProjection = projectionManager.getMediaProjection(resultCode, resultData)
        }
        val projection = mediaProjection ?: return false

        val windowManager = appContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        windowManager.defaultDisplay.getRealMetrics(metrics)

        cleanupCaptureResources()
        imageReader = ImageReader.newInstance(
            metrics.widthPixels,
            metrics.heightPixels,
            PixelFormat.RGBA_8888,
            2,
        )
        captureThread = HandlerThread("AuraScreenCapture").also { it.start() }
        captureHandler = Handler(captureThread!!.looper)

        imageReader?.setOnImageAvailableListener({ reader ->
            val image = reader.acquireLatestImage() ?: return@setOnImageAvailableListener
            try {
                val plane = image.planes.firstOrNull() ?: return@setOnImageAvailableListener
                val buffer: ByteBuffer = plane.buffer
                val pixelStride = plane.pixelStride
                val rowStride = plane.rowStride
                val rowPadding = rowStride - pixelStride * metrics.widthPixels
                val bitmap = Bitmap.createBitmap(
                    metrics.widthPixels + rowPadding / pixelStride,
                    metrics.heightPixels,
                    Bitmap.Config.ARGB_8888,
                )
                bitmap.copyPixelsFromBuffer(buffer)
                val cropped = Bitmap.createBitmap(bitmap, 0, 0, metrics.widthPixels, metrics.heightPixels)
                val outputFile = File(
                    appContext.cacheDir,
                    "aura_screen_capture_${System.currentTimeMillis()}.png",
                )
                FileOutputStream(outputFile).use { stream ->
                    cropped.compress(Bitmap.CompressFormat.PNG, 100, stream)
                }

                val launchIntent = Intent(appContext, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    putExtra("aura_screen_capture_path", outputFile.absolutePath)
                    putExtra("aura_screen_capture_auto_analyze", true)
                }
                appContext.startActivity(launchIntent)

            } catch (_: Exception) {
            } finally {
                image.close()
                cleanupCaptureResources()
            }
        }, captureHandler)

        virtualDisplay = projection.createVirtualDisplay(
            "AuraScreenCapture",
            metrics.widthPixels,
            metrics.heightPixels,
            metrics.densityDpi,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            imageReader?.surface,
            null,
            captureHandler,
        )
        return true
    }

    private fun cleanupCaptureResources() {
        virtualDisplay?.release()
        virtualDisplay = null
        imageReader?.close()
        imageReader = null
        captureThread?.quitSafely()
        captureThread = null
        captureHandler = null
    }
}
