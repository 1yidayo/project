# app/services/InterviewManager.py
import threading
import asyncio
from queue import Queue
import time

from app.services.yating_stt import YatingSTT
from app.services.openai_llm import ask_gpt4_1_nano
from app.services.minimax_tts import MinimaxTTSWS
from app.services.professor_persona import get_professor_persona


class InterviewManager:
    """
    管理整場模擬面試流程：
    1. 學生語音 → STT
    2. 說完關麥後 → LLM 生成教授回答
    3. TTS PCM 直接播放
    """

    def __init__(self, professor_type="warm_industry_professor"):
        self.professor_persona = get_professor_persona(professor_type)
        self.system_prompt = self.professor_persona.prompt

        # STT
        self.stt = YatingSTT()

        # TTS
        self.tts = MinimaxTTSWS(
            api_key=None,
            default_voice_id=self.professor_persona.voice_id
        )

        # 對話歷史
        self.conversation_history = []

        # 音訊 queue
        self.audio_queue = Queue()

        # 收集學生語音轉文字後的暫存
        self.pending_student_texts = []

        # 面試狀態
        self.interview_running = False

    # ------------------------
    # 啟動面試
    # ------------------------
    def start_interview(self):
        self.interview_running = True
        print(f"🎓 面試開始（教授: {self.professor_persona.name}）")

        # 啟動 STT 背景
        self.stt.start_asr_background(self._on_student_text)
        self.stt.start_recording()

    # ------------------------
    # 停止面試
    # ------------------------
    def stop_interview(self):
        self.interview_running = False
        self.stt.stop_recording()
        print("⏹ 面試結束")

        # 如果還有待處理學生文字，結束一次 LLM 回答
        if self.pending_student_texts:
            self._process_pending_texts()

    # ------------------------
    # STT callback
    # ------------------------
    def _on_student_text(self, text):
        if not self.interview_running:
            return

        print("[ASR final]", text)
        self.pending_student_texts.append(text)

    # ------------------------
    # 關麥觸發 LLM 回答
    # ------------------------
    def process_speech_end(self):
        """學生說完話，手動呼叫關麥，送給 LLM"""
        self.stt.stop_recording()
        if self.pending_student_texts:
            self._process_pending_texts()
            self.pending_student_texts = []

    # ------------------------
    # 處理 pending 文字 → LLM → TTS
    # ------------------------
    def _process_pending_texts(self):
        # 合併 pending 文字
        student_text = " ".join(self.pending_student_texts)
        print("[STT]", student_text)

        # 存歷史
        self.conversation_history.append({
            "role": "student",
            "content": student_text
        })

        # LLM 生成回答
        prompt = self._build_llm_prompt()
        reply = ask_gpt4_1_nano(prompt, professor_type=self.professor_persona.name)
        print("[Professor]", reply)
        self.conversation_history.append({
            "role": "professor",
            "content": reply
        })

        # TTS PCM 播放（收完再播一次完整音訊）
        async def play_tts():
            await self.tts.stream_text(
                text=reply,
                voice_id=self.professor_persona.voice_id,
                on_chunk=lambda chunk: print("[TTS chunk] bytes:", len(chunk) if chunk else "done")
            )

        # asyncio.run 會阻塞，等播放完再提示開麥
        asyncio.run(play_tts())
        print("🔹 TTS 播放完畢，即將自動提示開麥...")

    def process_speech_end(self):
        """學生說完話，手動或自動呼叫關麥，送給 LLM"""
        self.stt.stop_recording()

        # 等 STT 把最後一句文字送進 pending
        time.sleep(0.5)

        if self.pending_student_texts:
            self._process_pending_texts()
            self.pending_student_texts = []

        # 再開啟下一段錄音，方便連續測試
        self.stt.start_recording()

    # ------------------------
    # 建立 LLM prompt
    # ------------------------
    def _build_llm_prompt(self):
        prompt_text = self.system_prompt + "\n\n"
        for turn in self.conversation_history[-5:]:
            role = turn["role"]
            content = turn["content"]
            if role == "student":
                prompt_text += f"學生說: {content}\n"
            else:
                prompt_text += f"教授說: {content}\n"
        prompt_text += "請以教授身份回答下一句。\n"
        return prompt_text