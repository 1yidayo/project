# app/services/minimax_tts.py
import os
import json
import asyncio
import websockets
import sounddevice as sd
import numpy as np

class MinimaxTTSWS:
    """
    MiniMax TTS WebSocket / Voice Cloning
    支援即時 chunk callback (bytes)，最後播放完整 PCM。
    """

    def __init__(
        self,
        api_key=None,
        ws_url=None,
        model="speech-02-turbo",
        default_voice_id="male-qn-qingse",
    ):
        self.api_key = api_key or os.getenv("MINIMAX_API_KEY")
        self.ws_url = ws_url or os.getenv("MINIMAX_WS_URL")
        self.model = model
        self.default_voice_id = default_voice_id

    async def stream_text(self, text: str, voice_id: str = None, on_chunk=None):
        """
        將文字透過 WebSocket 轉成語音，收集所有 PCM chunk 後一次播放。
        :param text: 要轉語音的文字
        :param voice_id: 可使用 clone voice ID
        :param on_chunk: callback，參數 bytes (None 表示完成)
        """
        if on_chunk is None:
            on_chunk = lambda chunk: None

        if voice_id is None:
            voice_id = self.default_voice_id

        headers = {"Authorization": f"Bearer {self.api_key}"}
        all_audio_bytes = bytearray()

        try:
            async with websockets.connect(self.ws_url, extra_headers=headers) as ws:
                # 等待連線成功
                msg = json.loads(await ws.recv())
                if msg.get("event") != "connected_success":
                    print("❌ 連線失敗:", msg)
                    return

                # 發送 task_start
                await ws.send(json.dumps({
                    "event": "task_start",
                    "model": self.model,
                    "voice_setting": {
                        "voice_id": voice_id,
                        "speed": 1,
                        "vol": 1,
                        "pitch": 0
                    },
                    "audio_setting": {
                        "sample_rate": 32000,
                        "format": "pcm_s16le",
                        "channel": 1
                    }
                }))

                msg = json.loads(await ws.recv())
                if msg.get("event") != "task_started":
                    print("❌ 任務啟動失敗:", msg)
                    return

                # 發送文字
                await ws.send(json.dumps({"event": "task_continue", "text": text}))

                # 告訴它文字結束
                await ws.send(json.dumps({"event": "task_finish"}))

                # 接收音訊 chunk
                while True:
                    try:
                        msg = json.loads(await ws.recv())
                    except websockets.exceptions.ConnectionClosedOK:
                        break

                    if "data" in msg and "audio" in msg["data"]:
                        hex_audio = msg["data"]["audio"]
                        if hex_audio:
                            chunk = bytes.fromhex(hex_audio)
                            all_audio_bytes.extend(chunk)
                            on_chunk(chunk)  # callback

                    if msg.get("event") == "task_finished":
                        break

            # 收完所有 PCM chunk 後播放一次完整音訊
            if all_audio_bytes:
                try:
                    audio_array = np.frombuffer(all_audio_bytes, dtype=np.int16)
                    sd.play(audio_array, samplerate=32000)
                    sd.wait()  # 阻塞直到播放完
                except Exception as e:
                    print("❌ 播放錯誤:", e)

        except Exception as e:
            print("❌ TTS WebSocket Error:", e)
        finally:
            on_chunk(None)  # 表示完成