# yating_tts.py（把 gpt 回覆文字送給 Yating TTS，取回音檔並播放）
import requests, io, base64
from pydub import AudioSegment
# from pydub.playback import play
import simpleaudio as sa

def play_audiosegment(audio: AudioSegment):
    """用 simpleaudio 播放 AudioSegment，不需臨時檔"""
    play_obj = sa.play_buffer(
        audio.raw_data,
        num_channels=audio.channels,
        bytes_per_sample=audio.sample_width,
        sample_rate=audio.frame_rate
    )
    play_obj.wait_done()

# 建立一個可寫暫存檔
"""with tempfile.NamedTemporaryFile(delete=True, suffix=".wav", dir=".") as f:
    audio.export(f.name, format="wav")
    play(AudioSegment.from_file(f.name))"""

YATING_TTS_URL = "https://tts.api.yating.tw/v2/speeches/short"
YATING_API_KEY = "6aa8c608b8541c2886a0e0222aa57ff2090b2b8e"

def synthesize_and_play(text):
    headers = {
        "key": YATING_API_KEY,  # 🔥 注意這裡是錯，我改回正確 ↓
        # It should be:
        # "key": YATING_API_KEY,
        "Content-Type": "application/json"
    }

    body = {
        "input": { "type": "text", "text": text },
        "voice": {
            "model":"zh_en_female_2",
            "speed":0.8,
            "pitch":1.3,
            "energy":1.0
        },
        "audioConfig": {
            "encoding": "MP3",
            "sampleRate": "16K"
        }
    }

    r = requests.post(YATING_TTS_URL, json=body, headers={
        "key": YATING_API_KEY,
        "Content-Type": "application/json"
    })
    r.raise_for_status()

    resp = r.json()
    audio_bytes = base64.b64decode(resp["audioContent"])
    audio = AudioSegment.from_file(io.BytesIO(audio_bytes), format="mp3")
    play_audiosegment(audio)

if __name__ == "__main__":
    synthesize_and_play("你好，我是你的模擬教授。請問你想先練習哪個主題？")


