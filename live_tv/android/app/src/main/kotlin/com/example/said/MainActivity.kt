package com.example.said

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.RenderersFactory
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.audio.AudioSink
import androidx.media3.exoplayer.audio.DefaultAudioSink
import androidx.media3.common.audio.AudioProcessor
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import androidx.media3.common.util.UnstableApi

@UnstableApi
class MainActivity : AudioServiceActivity() {
    private val METHOD_CHANNEL = "audio_control"
    private val EVENT_CHANNEL = "audio_control_events"
    
    private var exoPlayer: ExoPlayer? = null
    private lateinit var channelMixingAudioProcessor: ChannelMixingAudioProcessor
    private var eventSink: EventChannel.EventSink? = null
    private val handler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channelMixingAudioProcessor = ChannelMixingAudioProcessor()

        val renderersFactory = object : DefaultRenderersFactory(this) {
            override fun buildAudioSink(
                context: android.content.Context,
                enableFloatOutput: Boolean,
                enableAudioTrackPlaybackParams: Boolean
            ): AudioSink? {
                return DefaultAudioSink.Builder(context)
                    .setAudioProcessors(arrayOf(channelMixingAudioProcessor) as Array<AudioProcessor>)
                    .build()
            }
        }

        exoPlayer = ExoPlayer.Builder(this)
            .setRenderersFactory(renderersFactory)
            .build()

        exoPlayer?.addListener(object : Player.Listener {
            override fun onIsPlayingChanged(isPlaying: Boolean) {
                eventSink?.success(mapOf("event" to "isPlayingChanged", "isPlaying" to isPlaying))
            }
            override fun onPlaybackStateChanged(playbackState: Int) {
                eventSink?.success(mapOf("event" to "playbackStateChanged", "state" to playbackState))
            }
            override fun onPositionDiscontinuity(
                oldPosition: Player.PositionInfo,
                newPosition: Player.PositionInfo,
                reason: Int
            ) {
                eventSink?.success(mapOf("event" to "queueIndexChanged", "index" to (exoPlayer?.currentMediaItemIndex ?: 0)))
            }
        })

        // Polling for position updates
        handler.post(object : Runnable {
            override fun run() {
                if (exoPlayer?.isPlaying == true) {
                    eventSink?.success(mapOf(
                        "event" to "positionChanged", 
                        "position" to (exoPlayer?.currentPosition ?: 0),
                        "duration" to (exoPlayer?.duration ?: 0)
                    ))
                }
                handler.postDelayed(this, 1000)
            }
        })

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
            
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setBalance" -> {
                    val balance = call.arguments as Double
                    channelMixingAudioProcessor.setBalance(balance.toFloat())
                    result.success(null)
                }
                "setMono" -> {
                    val isMono = call.arguments as Boolean
                    channelMixingAudioProcessor.setMono(isMono)
                    result.success(null)
                }
                "setVolume" -> {
                    val volume = call.arguments as Double
                    exoPlayer?.volume = volume.toFloat()
                    result.success(null)
                }
                "loadPlaylist" -> {
                    val args = call.arguments as Map<String, Any>
                    val urls = args["urls"] as List<String>
                    val index = args["index"] as Int
                    
                    val items = urls.map { MediaItem.fromUri(it) }
                    exoPlayer?.setMediaItems(items, index, 0L)
                    exoPlayer?.prepare()
                    result.success(null)
                }
                "play" -> {
                    exoPlayer?.play()
                    result.success(null)
                }
                "pause" -> {
                    exoPlayer?.pause()
                    result.success(null)
                }
                "skipToNext" -> {
                    exoPlayer?.seekToNextMediaItem()
                    result.success(null)
                }
                "skipToPrevious" -> {
                    exoPlayer?.seekToPreviousMediaItem()
                    result.success(null)
                }
                "stop" -> {
                    exoPlayer?.stop()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tv_boot_control").setMethodCallHandler { call, result ->
            when (call.method) {
                "setAutoLaunch" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    // Use same namespace as BootReceiver: "app_prefs" / "auto_launch_enabled"
                    val prefs = getSharedPreferences("app_prefs", android.content.Context.MODE_PRIVATE)
                    prefs.edit().putBoolean("auto_launch_enabled", enabled).apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        exoPlayer?.release()
        super.onDestroy()
    }
}
