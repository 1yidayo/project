from fastapi import FastAPI
from app.api import stt, llm, tts

app = FastAPI(title="Luminew")

# 加入路由
app.include_router(stt.router, prefix="/stt", tags=["ASR"])
app.include_router(llm.router, prefix="/llm", tags=["LLM"])
app.include_router(tts.router, prefix="/tts", tags=["TTS"])

@app.get("/")
def root():
    return {"message": "Luminew 即時語音練習 API 正在運行"}
