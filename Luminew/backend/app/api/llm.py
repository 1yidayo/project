from fastapi import APIRouter
from pydantic import BaseModel
from app.services.openai_llm import ask_gpt4_1_nano

router = APIRouter()

class LLMRequest(BaseModel):
    text: str
    system_instructions: str = "你是一位台灣大學教授，回答要簡短、清楚、口語。"

class LLMResponse(BaseModel):
    reply: str

@router.post("/chat", response_model=LLMResponse)
def chat(request: LLMRequest):
    reply = ask_gpt4_1_nano(request.text, request.system_instructions)
    return {"reply": reply}
