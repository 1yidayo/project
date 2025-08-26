import torch
import collections
from TTS.utils import radam
from TTS.utils.manage import ModelManager
from TTS.api import TTS

def tts_zhmodel():
     model_name = "tts_models/zh-CN/baker/tacotron2-DDC-GST"
     
     # 下載模型或找到本地路徑
     manager = ModelManager()
     checkpoint_file = manager.download_model(model_name)[0]  # 直接就是 model_file.pth
     # print("checkpoint 路徑:", checkpoint_file)

     # 列出 checkpoint 中的不安全 globals
     unsafe_globals = torch.serialization.get_unsafe_globals_in_checkpoint(checkpoint_file)
     # print("Unsafe globals in checkpoint:", unsafe_globals)

     # 加入 safe globals
     torch.serialization.add_safe_globals([dict, collections.defaultdict, radam.RAdam])

     # 載入 checkpoint
     checkpoint = torch.load(checkpoint_file, map_location="cpu", weights_only=True)
     # print("Checkpoint 成功載入！")

     text = input("plz input text:")
     output_path = input("plz input the output path, press 'd' if u want to use the default path:").strip('"')
     if output_path.lower() == "d":
          output_path = r"D:\Desktop\\-\\testtttt\stt_tts\\zh_output.wav"
     
     # 初始化 TTS 並生成語音
     tts = TTS(model_name)  # TTS 內部會自動使用 safe globals
     tts.tts_to_file(text=text, file_path=output_path)
     return print(f"> 語音已儲存到：{output_path}")

     """
     | > sample_rate:22050
     | > resample:False
     | > num_mels:80
     | > log_func:np.log10
     | > min_level_db:-100
     | > frame_shift_ms:None
     | > frame_length_ms:None
     | > ref_level_db:0
     | > fft_size:1024
     | > power:1.5
     | > preemphasis:0.0
     | > griffin_lim_iters:60
     | > signal_norm:True
     | > symmetric_norm:True
     | > mel_fmin:50.0
     | > mel_fmax:7600.0
     | > pitch_fmin:0.0
     | > pitch_fmax:640.0
     | > spec_gain:1.0
     | > stft_pad_mode:reflect
     | > max_norm:4.0
     | > clip_norm:True
     | > do_trim_silence:True
     | > trim_db:60
     | > do_sound_norm:False
     | > do_amp_to_db_linear:True
     | > do_amp_to_db_mel:True
     | > do_rms_norm:False
     | > db_level:None
     | > stats_path:C:\Users\Yi\AppData\Local\tts\tts_models--zh-CN--baker--tacotron2-DDC-GST\scale_stats.npy
     | > base:10
     | > hop_length:256
     | > win_length:1024
     > Model's reduction rate `r` is set to: 2
     > Text splitted to sentences."""

def tts_enmodel():
     model_name = "tts_models/multilingual/multi-dataset/your_tts"
     # language = "en" 
     # 下載模型或找到本地路徑
     manager = ModelManager()
     checkpoint_file = manager.download_model(model_name)[0]  # 直接就是 model_file.pth
     # print("checkpoint 路徑:", checkpoint_file)

     # 列出 checkpoint 中的不安全 globals
     unsafe_globals = torch.serialization.get_unsafe_globals_in_checkpoint(checkpoint_file)
     # print("Unsafe globals in checkpoint:", unsafe_globals)

     # 加入 safe globals
     torch.serialization.add_safe_globals([dict, collections.defaultdict, radam.RAdam])

     # 載入 checkpoint
     checkpoint = torch.load(checkpoint_file, map_location="cpu", weights_only=True)
     # print("Checkpoint 成功載入！")

     text = input("plz input text:")
     output_path = input("plz input the output path, press 'd' if u want to use the default path:").strip('"')
     if output_path.lower() == "d":
          output_path = r"D:\Desktop\\-\\testtttt\stt_tts\\en_output.wav"
     
     # 初始化 TTS 並生成語音
     tts = TTS(model_name)  # TTS 內部會自動使用 safe globals
     tts.tts_to_file(text=text, speaker=tts.speakers[0], language="en", file_path=output_path)
     return print(f"> 語音已儲存到：{output_path}")

     """
     | > sample_rate:16000
     | > resample:False
     | > num_mels:80
     | > log_func:np.log10
     | > min_level_db:0
     | > frame_shift_ms:None
     | > frame_length_ms:None
     | > ref_level_db:None
     | > fft_size:1024
     | > power:None
     | > preemphasis:0.0
     | > griffin_lim_iters:None
     | > signal_norm:None
     | > symmetric_norm:None
     | > mel_fmin:0
     | > mel_fmax:None
     | > pitch_fmin:None
     | > pitch_fmax:None
     | > spec_gain:20.0
     | > stft_pad_mode:reflect
     | > max_norm:1.0
     | > clip_norm:True
     | > do_trim_silence:False
     | > trim_db:60
     | > do_sound_norm:False
     | > do_amp_to_db_linear:True
     | > do_amp_to_db_mel:True
     | > do_rms_norm:False
     | > db_level:None
     | > stats_path:None
     | > base:10
     | > hop_length:256
     | > win_length:1024
     > Model fully restored. 
     > Setting up Audio Processor...
     
     """



#還沒看API 有stt也有tts
# https://developer.yating.tw/zh-TW/doc/introduction-%E7%94%A2%E5%93%81%E8%88%87%E4%BD%BF%E7%94%A8%E4%BB%8B%E7%B4%B9
# https://studio.yating.tw/intro/zh-TW

#想試試的模組
# https://www.youtube.com/watch?v=0PuslZHJQes
# https://pyttsx3.readthedocs.io/en/latest/engine.html

#想試試的模組
# https://medium.com/@zzxiang/text-to-speech-in-6-lines-of-python-code-free-no-online-api-a428a163decd
# from espnet2.bin.tts_inference import Text2Speech
# import soundfile
# text2speech = Text2Speech.from_pretrained("kan-bayashi/ljspeech_vits")
# text = "Hello, this is a text-to-speech test. Does my speech sound good?"
# speech = text2speech(text)["wav"]
# soundfile.write("output.wav", speech.numpy(), text2speech.fs, "PCM_16")