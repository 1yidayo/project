from tts_def import tts_zhmodel, tts_enmodel
lang = input("use [zh] or [en] model?")
if lang.lower() == "zh":
    tts_zhmodel()
else:
    tts_enmodel()

# 哈囉這是測試有無加標點符號的文本
# "D:\Desktop\-\testtttt\stt_tts\outpu_test.wav"