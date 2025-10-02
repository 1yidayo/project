from stt_def import load_whisper_model, transcribe_audio, opencc_model, jieba_model, convert_to_wav

file_path = convert_to_wav()

text = transcribe_audio(load_whisper_model("medium"), file_path)

cc_output = opencc_model(text)

jieba_output = jieba_model(cc_output)



