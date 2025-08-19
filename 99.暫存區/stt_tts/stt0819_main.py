from stt0819_def import load_whisper_model, transcribe_audio, opencc_model, jieba_model

model = load_whisper_model("medium") 
file_path = r"D:\Desktop\\-\\testtttt\\stt_tts\\0815.mp3"
text = transcribe_audio(model, file_path)
print("> stt辨識結果：", text)

cc_output = opencc_model(text)
print("> 簡轉繁結果：", cc_output)

#英文斷句應該不需要？英文文本就不用跑jieba?先判斷語言嗎
jieba_output = jieba_model(cc_output)
print("> jieba中文斷句結果：", jieba_output)


