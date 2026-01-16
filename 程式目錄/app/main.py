from fastapi import FastAPI
from app.api import stt, llm, tts

app = FastAPI(title="AI Professor Backend")

# REST API
app.include_router(llm.router, prefix="/llm")
app.include_router(tts.router, prefix="/tts")

# WebSocket
app.include_router(stt.router)
