import asyncio 
import numpy as np
import sounddevice as sd
from app.services.minimax_tts import MinimaxTTSWS

async def main():
    tts = MinimaxTTSWS()
    audio_chunks = []

    def on_chunk(chunk):
        if chunk:
            # PCM bytes 直接存到 list
            audio_chunks.append(chunk)
            # 直接播放 PCM
            audio_array = np.frombuffer(chunk, dtype=np.int16)
            sd.play(audio_array, samplerate=32000)
            sd.wait()  # 等每個 chunk 播放完
        else:
            print("✅ TTS 完成")

    await tts.stream_text(
        "你好，這是 AI 面試系統的語音測試。",
        on_chunk=on_chunk
    )

    # 存成 WAV
    import wave
    with wave.open("test_tts.wav", "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)  # int16 -> 2 bytes
        wf.setframerate(32000)
        for c in audio_chunks:
            wf.writeframes(c)

    print("🎵 已輸出 test_tts.wav")

asyncio.run(main())