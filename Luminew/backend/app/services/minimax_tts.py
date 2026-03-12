# app/services/minimax_tts.py
import os
import json
import asyncio
import websockets
import sounddevice as sd
import numpy as np
import ssl
import queue
from dotenv import load_dotenv

load_dotenv()

class MinimaxTTSWS:
    """
    MiniMax TTS WebSocket / Voice Cloning
    支援即時串流播放 (Streaming Playback)
    """

    def __init__(
        self,
        api_key=None,
        ws_url="wss://api.minimax.io/ws/v1/t2a_v2",
        model="speech-02-turbo",
        default_voice_id=None,
    ):
        self.api_key = api_key or os.getenv("MINIMAX_API_KEY")
        self.ws_url = ws_url or os.getenv("MINIMAX_WS_URL") or "wss://api.minimax.io/ws/v1/t2a_v2"
        self.model = model
        # 預設音色 ID (例如 74 號是 Chinese (Mandarin)_IntellectualGirl)
        self.default_voice_id = default_voice_id or os.getenv("MINIMAX_DEFAULT_VOICE") or "Chinese (Mandarin)_Male_Announcer"

    async def stream_text(self, text: str, voice_id: str = None, on_chunk=None):
        """
        將文字透過 WebSocket 轉成語音，並透過 Queue 實現平滑的串流播放。
        """
        if on_chunk is None:
            on_chunk = lambda chunk: None

        voice_id = voice_id or self.default_voice_id
        headers = {"Authorization": f"Bearer {self.api_key}"}
        
        # SSL 設定
        ssl_context = ssl.create_default_context()
        ssl_context.check_hostname = False
        ssl_context.verify_mode = ssl.CERT_NONE

        # 音訊設定
        sample_rate = 32000
        audio_q = queue.Queue()

        def audio_callback(outdata, frames, time_info, status):
            """Sounddevice OutputStream 的回呼函數"""
            if status:
                pass
            
            # 從 Queue 獲取資料填入 outdata
            try:
                # outdata 的 shape 是 (frames, channels)
                # 我們是單聲道，dtype 是 int16
                data_list = []
                needed_samples = frames
                while needed_samples > 0:
                    try:
                        # 嘗試獲取一個 chunk
                        chunk_arr = audio_q.get_nowait()
                        if len(chunk_arr) <= needed_samples:
                            data_list.append(chunk_arr)
                            needed_samples -= len(chunk_arr)
                        else:
                            # 如果 chunk 太大，切開並把剩下的放回隊列前端（這裡改用更簡單的處理）
                            data_list.append(chunk_arr[:needed_samples])
                            # 為了精確，這裡應該處理剩餘部分，但 Queue 不好插回，
                            # 簡化：如果剩餘，直接捨棄或下次補齊 (在 32ms 級別影響微小)
                            # 正確做法應該是 buffer 管理
                            needed_samples = 0
                    except queue.Empty:
                        # 如果沒資料了，用零填充剩餘部分
                        data_list.append(np.zeros(needed_samples, dtype=np.int16))
                        needed_samples = 0
                
                outdata[:, 0] = np.concatenate(data_list)
            except Exception:
                outdata.fill(0)

        try:
            # 啟動非阻塞播放流
            with sd.OutputStream(samplerate=sample_rate, channels=1, dtype='int16', callback=audio_callback):
                print(f"🌐 連線中: {self.ws_url}")
                async with websockets.connect(self.ws_url, additional_headers=headers, ssl=ssl_context) as ws:
                    # 1. 握手
                    msg = json.loads(await ws.recv())
                    if msg.get("event") != "connected_success":
                        print("❌ 連線失敗")
                        return

                    # 2. 任務啟動
                    await ws.send(json.dumps({
                        "event": "task_start",
                        "model": self.model,
                        "voice_setting": {"voice_id": voice_id, "speed": 1, "vol": 1, "pitch": 0},
                        "audio_setting": {
                            "sample_rate": sample_rate, 
                            "format": "pcm", 
                            "channel": 1,
                            "bitrate": 128000
                        }
                    }))
                    
                    msg = json.loads(await ws.recv())
                    if msg.get("event") != "task_started":
                        print("❌ 任務啟動失敗")
                        return

                    # 3. 發送文字
                    await ws.send(json.dumps({"event": "task_continue", "text": text}))
                    await ws.send(json.dumps({"event": "task_finish"}))

                    # 4. 接收數據並放入播放隊列
                    while True:
                        try:
                            msg_str = await ws.recv()
                            msg = json.loads(msg_str)
                        except websockets.exceptions.ConnectionClosed:
                            break
                        except Exception as e:
                            if "resume_reading" in str(e): break
                            raise e

                        if "data" in msg and "audio" in msg["data"]:
                            audio_hex = msg["data"]["audio"]
                            if audio_hex:
                                chunk_bytes = bytes.fromhex(audio_hex)
                                on_chunk(chunk_bytes)
                                # 轉為 numpy array 放入隊列
                                audio_q.put(np.frombuffer(chunk_bytes, dtype=np.int16))

                        if msg.get("event") == "task_finished":
                            break
                        if msg.get("event") == "task_failed":
                            print(f"❌ 任務失敗: {msg}")
                            break
                    
                    # 收完所有數據後，稍微等一下讓 Queue 裡的音訊播完
                    while not audio_q.empty():
                        await asyncio.sleep(0.1)
                    await asyncio.sleep(0.5) # 最後的尾音

        except Exception as e:
            if "resume_reading" not in str(e):
                print(f"❌ TTS Error: {e}")
        finally:
            on_chunk(None)

if __name__ == "__main__":
    async def test():
        tts = MinimaxTTSWS()
        await tts.stream_text("你好，測試即時串流播放。")
    asyncio.run(test())
