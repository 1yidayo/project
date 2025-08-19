import whisper #stt

def load_whisper_model(model_size="medium"):
    model = whisper.load_model(model_size)
    return model

def transcribe_audio(model, file_path):
    result = model.transcribe(file_path)
    return result["text"]

from opencc import OpenCC #簡轉繁

def opencc_model(text):
    cc = OpenCC('s2twp') 
    cc_output = cc.convert(text)
    return cc_output

import jieba #jieba斷句

def jieba_model(text):
    jieba.set_dictionary("D:\Desktop\-\\testtttt\stt_tts\dict.txt.big") #繁體詞庫
    jieba_output = '，'.join(jieba.cut(text, cut_all=False, HMM=True))
    return jieba_output

"""
可指定自己的词典 用法： jieba.load_userdict(file_name) # file_name 为文件类对象或自定义词典的路径
词典格式和 dict.txt 一样，一个词占一行；每一行分三部分：词语、词频（可省略）、词性（可省略），用空格隔开，顺序不可颠倒。
file_name 若为路径或二进制方式打开的文件，则文件必须为 UTF-8 编码。
"""
# text = '我來到北京清華大學'
# print('預設:', '，'.join(jieba.cut(text, cut_all=False, HMM=True))) #用著個
# print('預設:', '，'.join(jieba.cut(text, cut_all=True, HMM=True)))
# print('全關閉:', '，'.join(jieba.cut(text, cut_all=False, HMM=False)))
# print('全關閉:', '，'.join(jieba.cut(text, cut_all=True, HMM=True)))

# “今天天气 不错”应该被切成“今天 天气 不错”？（以及类似情况）
# 解决方法：强制调低词频 jieba.suggest_freq(('今天', '天气'), True)
# 或者直接删除该词 jieba.del_word('今天天气')
# 使用 add_word(word, freq=None, tag=None) 和 del_word(word) 可在程序中动态修改词典。
# 使用 suggest_freq(segment, tune=True) 可调节单个词语的词频，使其能（或不能）被分出来。

