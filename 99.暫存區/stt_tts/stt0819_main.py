from stt0819_def import load_whisper_model, transcribe_audio, opencc_model, jieba_model

text = transcribe_audio(load_whisper_model("medium"))

cc_output = opencc_model(text)

#英文需要斷句嗎？先判斷語言？
jieba_output = jieba_model(cc_output)



