from fastapi import FastAPI
from app.api import ws_asr, chat, tts

app = FastAPI(title="AI Professor Backend")

# REST API
app.include_router(chat.router, prefix="/chat")
app.include_router(tts.router, prefix="/tts")

# WebSocket
app.include_router(ws_asr.router)
