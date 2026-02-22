# app/services/minimax_tts_ws.py
import os
import json
import base64
import asyncio
import websockets

class MinimaxTTSWS:
    """
    MiniMax TTS WebSocket / Voice Cloning
    支援即時 chunk callback。
    """

    def __init__(self, api_key=None, ws_url=None, model="t2a_v2"):
        self.api_key = api_key or os.getenv("MINIMAX_API_KEY")
        self.ws_url = ws_url or os.getenv("MINIMAX_WS_URL")
        self.model = model

    async def stream_text(self, text: str, voice_id: str = None, on_chunk=None):
        """
        將文字透過 WebSocket 轉成語音，回傳 chunk。
        :param text: 要轉語音的文字
        :param voice_id: 可使用 clone voice ID
        :param on_chunk: callback，參數 bytes (None 表示結束)
        """
        if on_chunk is None:
            on_chunk = lambda chunk: None

        headers = {"Authorization": f"Bearer {self.api_key}"}
        async with websockets.connect(self.ws_url, extra_headers=headers) as ws:
            # 發送初始請求
            payload = {
                "model": self.model,
                "text": text,
            }
            if voice_id:
                payload["voice_id"] = voice_id

            await ws.send(json.dumps(payload))

            # 等待並讀取 chunk
            try:
                async for message in ws:
                    data = json.loads(message)
                    audio_b64 = data.get("audio_chunk")
                    if audio_b64:
                        audio_bytes = base64.b64decode(audio_b64)
                        on_chunk(audio_bytes)
                    if data.get("event") == "done":
                        break
            except Exception as e:
                print("TTS WebSocket Error:", e)
            finally:
                on_chunk(None)  # 表示完成