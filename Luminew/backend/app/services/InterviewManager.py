# InterviewManager.py
# 專題級面試管理器（STT / LLM / TTS 整合）
import threading
from queue import Queue
from app.services.yating_stt import YatingSTT
from app.services.openai_llm import ask_gpt4_1_nano
from app.services.minimax_tts_ws import MinimaxTTSWS  # 使用 WebSocket 版本
from professor_persona import get_professor_persona

class InterviewManager:
    """
    管理整場模擬面試流程：
    1. 接收學生語音 → STT
    2. LLM 分析 → 回答教授
    3. Minimax TTS WebSocket → 返回音訊 chunk 給前端
    """
    def __init__(self, professor_type="warm_industry_professor"):
        # 取得 persona
        self.professor_persona = get_professor_persona(professor_type)
        self.system_prompt = self.professor_persona.prompt

        # STT
        self.stt = YatingSTT()

        # TTS (WebSocket)
        self.tts = MinimaxTTSWS(
            api_key=None,  # 可從 .env 讀
            default_voice_id=self.professor_persona.voice_id
        )

        # 對話歷史
        self.conversation_history = []

        # 音訊 queue（前端傳音訊 chunk 進來）
        self.audio_queue = Queue()

        # 狀態
        self.interview_running = False

    # --- 啟動面試 ---
    def start_interview(self):
        self.interview_running = True
        print(f"🎓 面試開始（教授: {self.professor_persona.name}）")
        self.stt.start_recording()
        threading.Thread(target=self._process_audio_loop, daemon=True).start()

    # --- 停止面試 ---
    def stop_interview(self):
        self.interview_running = False
        self.stt.stop_recording()
        print("⏹ 面試結束")

    # --- 前端傳入音訊 chunk ---
    def feed_audio_chunk(self, chunk):
        if self.interview_running:
            self.audio_queue.put(chunk)

    # --- 循環處理音訊 STT / LLM / TTS ---
    def _process_audio_loop(self):
        while self.interview_running:
            chunk = self.audio_queue.get()
            if chunk is None:
                continue

            # 1️⃣ STT 轉文字
            text = self.stt.recognize_chunk(chunk)
            if not text:
                continue
            print("[STT] ", text)

            # 保存對話歷史
            self.conversation_history.append({"role": "student", "content": text})

            # 2️⃣ 呼叫 LLM
            prompt = self._build_llm_prompt()
            reply = ask_gpt4_1_nano(prompt, professor_type=self.professor_persona.name)
            print("[Professor] ", reply)

            # 保存對話歷史
            self.conversation_history.append({"role": "professor", "content": reply})

            # 3️⃣ TTS 生成 → WebSocket 即時回傳
            self.tts.speak_stream(
                text=reply,
                voice_id=self.professor_persona.voice_id,
                on_audio_chunk=self._send_audio_chunk_to_frontend
            )

    # --- 建立 LLM prompt（包含歷史對話） ---
    def _build_llm_prompt(self):
        prompt_text = ""
        for turn in self.conversation_history[-5:]:  # 只帶最近幾句
            role = turn["role"]
            content = turn["content"]
            if role == "student":
                prompt_text += f"學生說: {content}\n"
            else:
                prompt_text += f"教授說: {content}\n"
        prompt_text += "請以教授身份回答下一句。\n"
        return prompt_text

    # --- 回傳前端單個音訊 chunk ---
    def _send_audio_chunk_to_frontend(self, audio_bytes):
        """
        callback 給前端，每收到一個 TTS audio chunk 就會呼叫
        """
        # TODO: 改成 WebSocket 或 FastAPI Streaming 回傳
        print("[TTS audio chunk] bytes length:", len(audio_bytes))