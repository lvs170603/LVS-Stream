package com.example.said

import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.audio.AudioProcessor.UnhandledAudioFormatException
import androidx.media3.common.util.UnstableApi
import java.nio.ByteBuffer
import java.nio.ByteOrder

@UnstableApi
class ChannelMixingAudioProcessor : AudioProcessor {
    private var isActive = false
    private var pendingAudioFormat = AudioProcessor.AudioFormat.NOT_SET
    private var activeAudioFormat = AudioProcessor.AudioFormat.NOT_SET
    
    private var outputBuffer: ByteBuffer = AudioProcessor.EMPTY_BUFFER
    private var buffer: ByteBuffer = AudioProcessor.EMPTY_BUFFER
    private var inputEnded = false

    private var balance: Float = 0.0f
    private var isMono: Boolean = false

    fun setBalance(value: Float) {
        balance = value.coerceIn(-1.0f, 1.0f)
    }

    fun setMono(mono: Boolean) {
        isMono = mono
    }

    override fun configure(inputAudioFormat: AudioProcessor.AudioFormat): AudioProcessor.AudioFormat {
        if (inputAudioFormat.encoding != androidx.media3.common.C.ENCODING_PCM_16BIT) {
            throw UnhandledAudioFormatException(inputAudioFormat)
        }
        pendingAudioFormat = inputAudioFormat
        isActive = inputAudioFormat.channelCount == 2
        return if (isActive) inputAudioFormat else AudioProcessor.AudioFormat.NOT_SET
    }

    override fun isActive(): Boolean = isActive

    override fun queueInput(inputBuffer: ByteBuffer) {
        val position = inputBuffer.position()
        val limit = inputBuffer.limit()
        val size = limit - position
        
        if (buffer.capacity() < size) {
            buffer = ByteBuffer.allocateDirect(size).order(ByteOrder.nativeOrder())
        } else {
            buffer.clear()
        }

        val leftVol = if (balance < 0) 1.0f else 1.0f - balance
        val rightVol = if (balance > 0) 1.0f else 1.0f + balance

        while (inputBuffer.position() < limit) {
            var leftSample = inputBuffer.short.toFloat()
            var rightSample = inputBuffer.short.toFloat()

            if (isMono) {
                val mixed = (leftSample * 0.5f) + (rightSample * 0.5f)
                leftSample = mixed
                rightSample = mixed
            } else {
                leftSample *= leftVol
                rightSample *= rightVol
            }

            buffer.putShort(leftSample.coerceIn(Short.MIN_VALUE.toFloat(), Short.MAX_VALUE.toFloat()).toInt().toShort())
            buffer.putShort(rightSample.coerceIn(Short.MIN_VALUE.toFloat(), Short.MAX_VALUE.toFloat()).toInt().toShort())
        }

        inputBuffer.position(limit)
        buffer.flip()
        outputBuffer = buffer
    }

    override fun queueEndOfStream() {
        inputEnded = true
        buffer = AudioProcessor.EMPTY_BUFFER
    }

    override fun getOutput(): ByteBuffer {
        val output = outputBuffer
        outputBuffer = AudioProcessor.EMPTY_BUFFER
        return output
    }

    override fun isEnded(): Boolean = inputEnded && outputBuffer === AudioProcessor.EMPTY_BUFFER

    override fun flush() {
        outputBuffer = AudioProcessor.EMPTY_BUFFER
        inputEnded = false
        activeAudioFormat = pendingAudioFormat
    }

    override fun reset() {
        flush()
        pendingAudioFormat = AudioProcessor.AudioFormat.NOT_SET
        activeAudioFormat = AudioProcessor.AudioFormat.NOT_SET
        buffer = AudioProcessor.EMPTY_BUFFER
    }
}
