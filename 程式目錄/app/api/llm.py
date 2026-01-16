from fastapi import APIRouter
from pydantic import BaseModel
from app.services.openai_llm import ask_llm

router = APIRouter()

class ChatRequest(BaseModel):
    text: str

@router.post("/reply")
def chat_reply(req: ChatRequest):
    reply = ask_llm(
        req.text,
        system_prompt="你是一位台灣大學教授，回答要簡短、口語。"
    )
    return {"reply": reply}
