from fastapi import APIRouter, WebSocket

router = APIRouter()

@router.websocket("/ws/asr")
async def asr_ws(ws: WebSocket):
    await ws.accept()
    await ws.send_text("ASR WebSocket connected")

    while True:
        data = await ws.receive_text()
        print("收到前端資料：", data)
