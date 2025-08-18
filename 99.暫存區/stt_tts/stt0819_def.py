import whisper
from opencc import OpenCC
import jieba 
#stt
def load_whisper_model(model_size="medium"):
    model = whisper.load_model(model_size)
    return model

def transcribe_audio(model, file_path):
    result = model.transcribe(file_path)
    return result["text"]

cc = OpenCC('s2twp')
text = '資訊工程系。投票当天需携带投票通知单、国民身分证及印章，若没有收到投票通知书，可以向户籍所在地邻长查 找投票所，印章则是可以用签名代替，至于身分证则是一定要携带。'

print(cc.convert(text))


jieba.set_dictionary("D:\Desktop\-\\testtttt\stt_tts\dict.txt.big")

text = '我來到北京清華大學'
print('預設:', '，'.join(jieba.cut(text, cut_all=False, HMM=True)))
# print('預設:', '，'.join(jieba.cut(text, cut_all=True, HMM=True)))
# print('全關閉:', '，'.join(jieba.cut(text, cut_all=False, HMM=False)))
# print('全關閉:', '，'.join(jieba.cut(text, cut_all=True, HMM=True)))

#輸出
# 預設: 我|來到|北京|清華|大學
# 全關閉: 我|來到|北京|清華|大學
# 全關閉: 我來|來到|北京|清華|華大|大學
# 搜尋引擎: 我|來到|北京|清華|大學

用法： jieba.load_userdict(file_name) # file_name 为文件类对象或自定义词典的路径
词典格式和 dict.txt 一样，一个词占一行；每一行分三部分：词语、词频（可省略）、词性（可省略），用空格隔开，顺序不可颠倒。file_name 若为路径或二进制方式打开的文件，则文件必须为 UTF-8 编码。

from espnet2.bin.tts_inference import Text2Speech
import soundfile
text2speech = Text2Speech.from_pretrained("kan-bayashi/ljspeech_vits")
text = "Hello, this is a text-to-speech test. Does my speech sound good?"
speech = text2speech(text)["wav"]
soundfile.write("output.wav", speech.numpy(), text2speech.fs, "PCM_16")

3. “今天天气 不错”应该被切成“今天 天气 不错”？（以及类似情况）
解决方法：强制调低词频

jieba.suggest_freq(('今天', '天气'), True)

或者直接删除该词 jieba.del_word('今天天气')