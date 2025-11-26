# yating_tts.py（把 gpt 回覆文字送給 Yating TTS，取回音檔並播放）
import requests, io
from pydub import AudioSegment
from pydub.playback import play

YATING_TTS_URL = "https://tts.api.yating.tw/v2/tts"  # 假設路徑（用文件上確切 endpoint）
YATING_API_KEY = "你的_YATING_API_KEY"

def synthesize_and_play(text, voice="zh_tw_standard_1"):
    headers = {
        "Authorization": f"Bearer {YATING_API_KEY}",
        "Content-Type": "application/json"
    }
    body = {
        "text": text,
        "voice": voice,
        # 其他參數如 speed, pitch, format 等依 Yating 文件可選
    }
    r = requests.post(YATING_TTS_URL, json=body, headers=headers)
    r.raise_for_status()
    # 假設回傳是二進位 audio (wav/mp3)
    audio_bytes = r.content
    audio = AudioSegment.from_file(io.BytesIO(audio_bytes), format="mp3")  # or 'wav'
    play(audio)

if __name__ == "__main__":
    synthesize_and_play("你好，我是你的模擬教授。請問你想先練習哪個主題？")
