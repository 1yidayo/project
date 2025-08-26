from tts_def import tts_zhmodel, tts_enmodel
lang = input("use [zh] or [en] model?")
if lang.lower() == "zh":
    tts_zhmodel()
else:
    tts_enmodel()