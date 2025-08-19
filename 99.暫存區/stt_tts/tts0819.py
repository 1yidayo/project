# import torch
# from TTS.utils import radam

# # 將 RAdam 加入 safe globals
# torch.serialization.add_safe_globals([radam.RAdam])

# from TTS.api import TTS #conda tts_env_310

# # 選一個支援多語系與多說話者的模型
# model_name = "tts_models/zh-CN/baker/tacotron2-DDC-GST"

# # 載入模型
# tts = TTS(model_name)

# print("支援的語言：", tts.languages)
# print("支援的說話人：", tts.speakers)

# language = "en"         # 報錯無中文

# # text = "你好，我是AI語音合成系統。"
# text = "Hello, i' m AI voice robot. Nice to meet you."

# output_path = r"D:\Desktop\\-\\testtttt\\tts_stt\\output.wav"

# # 執行 TTS 並輸出檔案
# tts.tts_to_file(text=text, speaker=tts.speakers[0], language=language, file_path=output_path)

# print("語音已儲存到", output_path)

"""
1-28是之前的程式碼
31-48行是範例程式碼 還沒細看 或許能解決之前的報錯
"""

import torch
from TTS.api import TTS

# Get device
device = "cuda" if torch.cuda.is_available() else "cpu"

# List available 🐸TTS models
print(TTS().list_models())

# Init TTS
tts = TTS("tts_models/multilingual/multi-dataset/xtts_v2").to(device)

# Run TTS
# ❗ Since this model is multi-lingual voice cloning model, we must set the target speaker_wav and language
# Text to speech list of amplitude values as output
wav = tts.tts(text="Hello world!", speaker_wav="my/cloning/audio.wav", language="en")
# Text to speech to a file
tts.tts_to_file(text="Hello world!", speaker_wav="my/cloning/audio.wav", language="en", file_path="output.wav")

    #我們可能可以用的TTS模組 
34: tts_models/zh-CN/baker/tacotron2-DDC-GST
50: tts_models/tw_akuapem/openbible/vits
51: tts_models/tw_asante/openbible/vits

    #還沒看API
https://developer.yating.tw/zh-TW/doc/introduction-%E7%94%A2%E5%93%81%E8%88%87%E4%BD%BF%E7%94%A8%E4%BB%8B%E7%B4%B9
https://studio.yating.tw/intro/zh-TW

    #想試試的模組
https://www.youtube.com/watch?v=0PuslZHJQes
https://pyttsx3.readthedocs.io/en/latest/engine.html


https://medium.com/@zzxiang/text-to-speech-in-6-lines-of-python-code-free-no-online-api-a428a163decd
# from espnet2.bin.tts_inference import Text2Speech
# import soundfile
# text2speech = Text2Speech.from_pretrained("kan-bayashi/ljspeech_vits")
# text = "Hello, this is a text-to-speech test. Does my speech sound good?"
# speech = text2speech(text)["wav"]
# soundfile.write("output.wav", speech.numpy(), text2speech.fs, "PCM_16")