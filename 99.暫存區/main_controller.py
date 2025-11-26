# main_controller.py
from asr_ws import asr_stream_loop
from call_openai import ask_gpt4_1_nano
from yating_tts import synthesize_and_play

def handle_final_text(asr_text):
    print("[主控] ASR final:", asr_text)
    # 呼叫 LLM
    reply = ask_gpt4_1_nano(asr_text, system_instructions="你是一位台灣教授，回答要簡短且鼓勵。")
    print("[主控] GPT 回覆:", reply)
    # 呼叫 TTS 並播放
    synthesize_and_play(reply)

if __name__ == "__main__":
    import asyncio
    asyncio.run(asr_stream_loop(handle_final_text))
