# asr_ws.py（把麥克風音訊丟給 Yating，並把 final text 呼叫回處理函式）
import asyncio, websockets, json, sounddevice as sd, numpy as np, requests, threading
from queue import Queue

YATING_API_KEY = "6aa8c608b8541c2886a0e0222aa57ff2090b2b8e"
ASR_TOKEN_URL = "https://asr.api.yating.tw/v1/token"
ASR_WS_URL = "wss://asr.api.yating.tw/ws/v1/"

SAMPLE_RATE = 16000
CHUNK_BYTES = 2000  # 文件建議的 chunk 大小

def get_one_time_token(pipeline="asr-zh-en-std"):
    headers = {"key": YATING_API_KEY, "Content-Type": "application/json"}
    body = {"pipeline": pipeline}
    r = requests.post(ASR_TOKEN_URL, json=body, headers=headers)
    r.raise_for_status()
    return r.json()["auth_token"]

async def asr_stream_loop(on_final_text):
    token = get_one_time_token()
    uri = f"{ASR_WS_URL}?token={token}"
    q = Queue()

    def audio_callback(indata, frames, time, status):
        # indata: float32 between -1..1 or int16 depending on config
        pcm16 = (indata * 32767).astype(np.int16).tobytes()
        q.put(pcm16)

    async with websockets.connect(uri) as ws:
        print("ASR ws connected")
        # start audio recorder in background thread
        stream = sd.InputStream(samplerate=SAMPLE_RATE, channels=1, dtype='float32', callback=audio_callback)
        stream.start()

        async def sender():
            while True:
                chunk = await asyncio.get_event_loop().run_in_executor(None, q.get)
                # send binary frame (Yating expects raw PCM16 chunks)
                await ws.send(chunk)
        send_task = asyncio.create_task(sender())

        # receive messages
        async for message in ws:
            # Yating 返回的是 JSON textual frames about state/result
            try:
                data = json.loads(message)
            except:
                continue
            # 依文件，當 asr_final = true 時為最終結果
            pipe = data.get("pipe", {})
            if pipe.get("asr_final") == True:
                final_text = pipe.get("asr_sentence", "")
                print("[ASR final]", final_text)
                # 將 final text 傳給處理函式（例如呼叫 OpenAI）
                threading.Thread(target=on_final_text, args=(final_text,)).start()

"""if __name__ == "__main__":
    # 範例處理函式，把文字印出（實際會呼叫 OpenAI）
    def handle_final(text):
        print("處理 ASR 結果：", text)
    asyncio.run(asr_stream_loop(handle_final))"""