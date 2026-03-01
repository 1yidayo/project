import asyncio
from app.services.minimax_tts import MinimaxTTSWS
import os
from dotenv import load_dotenv

load_dotenv()  # 確保環境變數生效

async def main():
    tts = MinimaxTTSWS()  # 使用預設 voice 和 model

    audio_chunks = []

    def on_chunk(chunk):
        if chunk:
            audio_chunks.append(chunk)
            print(f"收到 chunk，大小: {len(chunk)} bytes")
        else:
            print("✅ TTS 完成")

    await tts.stream_text("大家好，我是保羅。大家好，我是保羅。大家好，我是保羅。", on_chunk=on_chunk)

    # 存成 mp3
    if audio_chunks:
        with open("test_output.mp3", "wb") as f:
            for c in audio_chunks:
                f.write(c)
        print("🎵 已儲存 test_output.mp3")
    else:
        print("❌ 沒收到任何音訊")

asyncio.run(main())