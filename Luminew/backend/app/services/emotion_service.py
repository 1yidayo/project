# emotion_service.py
# 情緒分析核心服務 - 從 Flask app.py 遷移到 FastAPI 架構

import os
import cv2
import torch
import torch.nn as nn
from torchvision import transforms, models
from PIL import Image
from openai import OpenAI
from dotenv import load_dotenv
import traceback
from collections import deque
import uuid
import json

# 載入環境變數
load_dotenv()

# ---------------------------
# 全域設定
# ---------------------------
PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MODEL_PATH = os.path.join(PROJECT_DIR, "models", "test_best_.pth")
VIDEO_STORAGE_DIR = os.path.join(PROJECT_DIR, "static", "videos")
os.makedirs(VIDEO_STORAGE_DIR, exist_ok=True)

# OpenAI Client
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
client = None

if OPENAI_API_KEY:
    client = OpenAI(api_key=OPENAI_API_KEY)
    print(f"🔑 目前系統讀到的 Key 前五碼: {OPENAI_API_KEY[:10]}...")
    print("✅ OpenAI Client 設定成功")
else:
    print("❌ 錯誤：找不到 OPENAI_API_KEY，請檢查 .env 檔案")

# 載入人臉辨識器
HAAR_PATH = os.path.join(PROJECT_DIR, "haarcascade_frontalface_default.xml")
if not os.path.exists(HAAR_PATH):
    print(f"⚠️ 本地找不到 {HAAR_PATH}，嘗試使用 OpenCV 內建路徑...")
    HAAR_PATH = cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'

print(f"📂 正在載入人臉辨識檔：{HAAR_PATH}")
face_cascade = cv2.CascadeClassifier(HAAR_PATH)

if face_cascade.empty():
    print("❌ 嚴重錯誤：無法載入人臉辨識器 (xml 檔案損毀或路徑錯誤)")

# 載入情緒模型 (ResNet18)
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
CLASSES = ['confidence', 'nervous', 'passion', 'relaxed']

model = models.resnet18(pretrained=False)
try:
    checkpoint = torch.load(MODEL_PATH, map_location=device)
    state_dict = checkpoint["state_dict"] if "state_dict" in checkpoint else checkpoint
    
    fc_keys = [k for k in state_dict.keys() if k.startswith("fc.")]
    use_sequential = any(k.startswith("fc.1.") for k in fc_keys)
    
    if use_sequential:
        model.fc = nn.Sequential(nn.Dropout(0.3), nn.Linear(model.fc.in_features, len(CLASSES)))
    else:
        model.fc = nn.Linear(model.fc.in_features, len(CLASSES))
        
    model.load_state_dict(state_dict, strict=False)
    print("✅ 情緒辨識模型載入成功")
except Exception as e:
    print(f"❌ 模型載入失敗: {e}")
    model.fc = nn.Linear(model.fc.in_features, len(CLASSES))

model = model.to(device)
model.eval()

# 影像預處理
transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize([0.5]*3, [0.5]*3)
])


def get_video_storage_dir():
    """取得影片儲存目錄"""
    return VIDEO_STORAGE_DIR


async def analyze_video(video_path: str, save_video: bool = True) -> dict:
    """
    分析影片情緒
    
    Args:
        video_path: 影片檔案路徑
        save_video: 是否保留影片
        
    Returns:
        分析結果 dict
    """
    try:
        cap = cv2.VideoCapture(video_path)
        
        if not cap.isOpened():
            return {"error": "Could not open video"}

        timeline_data = []
        fps = cap.get(cv2.CAP_PROP_FPS)
        if fps == 0 or fps is None:
            fps = 30
        frame_interval = max(1, int(fps / 3))

        session_history = []
        frame_count = 0
        detected_count = 0
        
        orig_w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        orig_h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        print(f"🎥 原始影片尺寸: {orig_w} x {orig_h}")

        smooth_queue = deque(maxlen=5)

        with torch.no_grad():
            while True:
                ret, frame = cap.read()
                if not ret:
                    break
                
                frame_count += 1
                if frame_count % 3 != 0:
                    continue

                found_face_info = None
                rotation_attempts = [None, cv2.ROTATE_90_CLOCKWISE, cv2.ROTATE_90_COUNTERCLOCKWISE]
                
                for rot_code in rotation_attempts:
                    temp_frame = frame.copy()
                    
                    if rot_code is not None:
                        temp_frame = cv2.rotate(temp_frame, rot_code)
                    
                    target_w = 480
                    h_curr, w_curr, _ = temp_frame.shape
                    scale = target_w / w_curr
                    new_h = int(h_curr * scale)
                    temp_frame = cv2.resize(temp_frame, (target_w, new_h))
                    
                    gray = cv2.cvtColor(temp_frame, cv2.COLOR_BGR2GRAY)
                    faces = face_cascade.detectMultiScale(gray, 1.1, 8)
                    
                    if len(faces) > 0:
                        found_face_info = (temp_frame, faces)
                        break
                
                if found_face_info is None:
                    continue

                detected_count += 1
                correct_frame, faces = found_face_info
                (x, y, w, h) = max(faces, key=lambda f: f[2] * f[3])

                if detected_count <= 3:
                    debug_frame = correct_frame.copy()
                    cv2.rectangle(debug_frame, (x, y), (x+w, y+h), (0, 255, 0), 2)
                    cv2.imwrite(f"debug_face_server_{detected_count}.jpg", debug_frame)

                face_crop = correct_frame[y:y+h, x:x+w]

                try:
                    img = cv2.cvtColor(face_crop, cv2.COLOR_BGR2RGB)
                    img = Image.fromarray(img)
                    img_tensor = transform(img).unsqueeze(0).to(device)

                    outputs = model(img_tensor)
                    probs = torch.softmax(outputs, dim=1)[0]
                    
                    smooth_queue.append(probs.cpu())
                    avg_probs = torch.stack(list(smooth_queue), dim=0).mean(dim=0)

                    current_emotions = {}
                    for i, cls in enumerate(CLASSES):
                        current_emotions[cls] = avg_probs[i].item()
                    
                    session_history.append(current_emotions)

                    if frame_count % frame_interval == 0:
                        timeline_entry = {
                            "t": round(frame_count / fps, 1),
                            "c": int(current_emotions['confidence'] * 100),
                            "n": int(current_emotions['nervous'] * 100),
                            "p": int(current_emotions['passion'] * 100),
                            "r": int(current_emotions['relaxed'] * 100)
                        }
                        timeline_data.append(timeline_entry)

                except Exception as img_err:
                    print(f"⚠️ 影像處理錯誤: {img_err}")
                    pass

        cap.release()
        print(f"📊 分析完成：共讀取 {frame_count} 幀，成功辨識 {detected_count} 幀人臉。")
        
        if not session_history:
            return {"error": "No face detected (Server tried 3 rotations but failed). Try better lighting."}

        # 計算平均分數
        avg_scores = {cls: 0.0 for cls in CLASSES}
        for entry in session_history:
            for cls in CLASSES:
                avg_scores[cls] += entry[cls]
                
        final_scores_float = {}
        for cls in CLASSES:
            final_scores_float[cls] = (avg_scores[cls] / len(session_history)) * 100
        
        final_scores_int = {k: int(v) for k, v in final_scores_float.items()}
        print(f"📈 分析結果: {final_scores_int}")

        # 生成 AI 評語
        feedback_json = await generate_ai_feedback(final_scores_float)

        # 處理影片 URL
        video_url = None
        if save_video:
            filename = os.path.basename(video_path)
            video_url = f"http://10.0.2.2:8000/static/videos/{filename}"
        else:
            try:
                os.remove(video_path)
                print(f"🗑️ 已刪除暫存影片: {video_path}")
            except Exception as del_err:
                print(f"⚠️ 刪除暫存影片失敗: {del_err}")

        return {
            "emotions": final_scores_int,
            "timeline": timeline_data,
            "ai_analysis": feedback_json,
            "video_url": video_url
        }

    except Exception as e:
        print(f"❌ 伺服器發生嚴重錯誤: {e}")
        traceback.print_exc()
        return {"error": f"Server Error: {str(e)}"}


async def generate_ai_feedback(final_scores_float: dict) -> dict:
    """生成 AI 評語"""
    feedback_json = {
        "overall_score": 0,
        "comment": "分析完成，正在生成評語...",
        "suggestion": ""
    }
    
    # ★★★ 暫時跳過 OpenAI，直接使用救援評語（避免伺服器當機）★★★
    SKIP_OPENAI = True
    
    try:
        if SKIP_OPENAI:
            raise Exception("暫時跳過 OpenAI，使用本地評語")
            
        model_name = 'gpt-4o-mini'
        
        prompt = f"""
        你是一位頂尖的大學入學面試培訓專家，同時也是一位專業的表達溝通教練。
        你正在一對一指導一位高中生，幫助他在升學面試中脫穎而出。

        【AI 表情分析結果】（本次模擬面試的平均情緒佔比）
        - 自信指數: {final_scores_float.get('confidence', 0):.0f}%
        - 熱忱指數: {final_scores_float.get('passion', 0):.0f}%
        - 放鬆指數: {final_scores_float.get('relaxed', 0):.0f}%
        - 緊張指數: {final_scores_float.get('nervous', 0):.0f}%

        【你的任務】
        請直接對這位學生說話（用「你」稱呼），給他一份**超級實用**的回饋。

        🚫 禁止事項（非常重要！）：
        - 不要只是重複說「你的自信指數是 XX%」這種廢話
        - 不要說「你展現了沈穩的一面」「情緒波動不大」這種沒營養的話
        - 不要泛泛地說「多練習就會進步」

        ✅ 必須做到：
        - 給出**具體到可以今天就執行**的建議（例如：練習時對著鏡子微笑、回答前先深呼吸 3 秒）
        - 針對**面試技巧**給建議（眼神接觸、手勢運用、語速控制、開場白設計）
        - 像一個真正關心學生的教練那樣說話，有溫度但直接

        【輸出格式】
        請只回傳一個 JSON，不要有任何 Markdown 標記：
        {{
            "overall_score": (0-100 整數，根據自信+熱忱的表現給分，緊張高要扣分),
            "comment": (50-80 字的短評，告訴學生他這次表現的亮點和需要改進的地方，要具體、有溫度，不要廢話),
            "suggestion": (一句話的具體行動建議，例如「下次回答問題前，先對面試官微笑並點頭，再開始說話」)
        }}
        """

        if client:
            print(f"🤖 正在呼叫 OpenAI ({model_name})...")
            
            # 使用 asyncio.to_thread 在背景執行同步 OpenAI 呼叫
            import asyncio
            
            def call_openai():
                return client.chat.completions.create(
                    model=model_name,
                    messages=[
                        {"role": "system", "content": "You are a helpful assistant that outputs JSON."},
                        {"role": "user", "content": prompt}
                    ],
                    temperature=0.7,
                    timeout=30,  # 30 秒超時
                )
            
            try:
                response = await asyncio.to_thread(call_openai)
                content = response.choices[0].message.content
                clean_text = content.replace('```json', '').replace('```', '').strip()
                feedback_json = json.loads(clean_text)
                print("📝 AI 評語生成成功！")
            except Exception as openai_err:
                print(f"⚠️ OpenAI 呼叫失敗: {openai_err}")
                raise openai_err
        else:
            raise Exception("OpenAI Client not initialized")

    except Exception as e:
        print(f"⚠️ AI 生成出現狀況 ({e})，正在啟動自動救援模式...")
        
        c_score = int(final_scores_float.get('confidence', 0))
        n_score = int(final_scores_float.get('nervous', 0))
        p_score = int(final_scores_float.get('passion', 0))
        
        calc_score = 70 + (c_score * 0.3) + (p_score * 0.2) - (n_score * 0.2)
        calc_score = int(min(max(calc_score, 65), 96))

        if c_score >= 50:
            fallback_comment = "你的表現相當穩健，眼神接觸充滿自信，給人留下了很好的第一印象。整體氛圍控制得宜，展現了不錯的抗壓性，是一位很有潛力的考生。"
            fallback_suggestion = "可以嘗試在回答時加入更多具體的個人經歷，讓內容更具說服力，並保持目前的自信姿態。"
        elif n_score >= 30:
            fallback_comment = "面試過程中你看起來有些許緊張，導致表情略顯僵硬，這在模擬面試中是很正常的。不過你的態度依然誠懇，只要多加練習，定能克服焦慮。"
            fallback_suggestion = "建議練習深呼吸放鬆法，並試著在鏡子前多練習微笑，增加親和力，避免因緊張而忘詞。"
        elif p_score >= 30:
            fallback_comment = "你談論到相關話題時展現了不錯的熱忱，這點非常吸引人。不過在其他部分可以再放鬆一些，讓整體表現更為自然流暢。"
            fallback_suggestion = "試著將這份熱情延伸到自我介紹中，並注意語速的控制，讓面試官能更清楚接收你的訊息。"
        else:
            fallback_comment = "整場面試表現中規中矩，情緒波動不大，展現了沈穩的一面。雖然沒有太多失誤，但也少了些許記憶點，建議展現更多對該領域的企圖心。"
            fallback_suggestion = "回答問題時可以適度加強語氣的抑揚頓挫，並多運用手勢輔助，讓面試官感受到你的積極度。"

        feedback_json = {
            "overall_score": calc_score,
            "comment": fallback_comment,
            "suggestion": fallback_suggestion
        }
        print(f"✅ 已啟用救援評語 (分數: {calc_score})")
    
    return feedback_json


async def analyze_portfolio(pdf_path: str) -> dict:
    """
    分析學習歷程 PDF
    
    Args:
        pdf_path: PDF 檔案路徑
        
    Returns:
        分析結果 dict
    """
    try:
        # 提取 PDF 文字內容
        try:
            import pdfplumber
            text_content = ""
            with pdfplumber.open(pdf_path) as pdf:
                for page in pdf.pages:
                    page_text = page.extract_text()
                    if page_text:
                        text_content += page_text + "\n"
            
            print(f"📖 提取到 {len(text_content)} 字")
            
            if len(text_content.strip()) < 50:
                os.remove(pdf_path)
                return {"error": "PDF 內容過少或為純圖片格式，無法分析。請上傳包含文字的 PDF。"}
            
        except Exception as pdf_err:
            os.remove(pdf_path)
            print(f"❌ PDF 解析失敗: {pdf_err}")
            return {"error": f"PDF 解析失敗: {str(pdf_err)}。請確認已安裝 pdfplumber"}
        
        if not client:
            os.remove(pdf_path)
            return {"error": "OpenAI API 未設定"}
        
        # 限制文字長度
        max_chars = 10000
        if len(text_content) > max_chars:
            text_content = text_content[:max_chars] + "\n...(內容過長，已截斷)"
        
        prompt = f"""
        你是一位專業的高中升大學輔導專家，同時也是教育部「學習歷程檔案」的審閱委員。
        你正在審閱一位高中生的學習歷程檔案，請給予專業的評價和具體的改進建議。

        【學習歷程內容】
        {text_content}

        【請依照以下格式給予評價】
        請只回傳一個 JSON，不要有任何 Markdown 標記：
        {{
            "overall_score": (0-100 整數，根據內容完整性、個人特色、反思深度給分),
            "strengths": [
                "優點1",
                "優點2",
                "優點3"
            ],
            "weaknesses": [
                "需改進1",
                "需改進2"
            ],
            "comment": (100-150字的整體評語，指出這份學習歷程的亮點和可以加強的地方，要具體、有建設性),
            "suggestions": [
                "具體改進建議1（例如：可以補充實作過程中遇到的困難和解決方法）",
                "具體改進建議2",
                "具體改進建議3"
            ]
        }}
        """
        
        print("🤖 正在呼叫 OpenAI 分析學習歷程...")
        
        response = client.chat.completions.create(
            model='gpt-4o-mini',
            messages=[
                {"role": "system", "content": "You are a helpful assistant that outputs JSON."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.7,
        )
        
        content = response.choices[0].message.content
        clean_text = content.replace('```json', '').replace('```', '').strip()
        result_json = json.loads(clean_text)
        print(f"✅ 學習歷程分析完成！分數: {result_json.get('overall_score', 'N/A')}")
        
        # 刪除暫存 PDF
        os.remove(pdf_path)
        
        return {
            "success": True,
            "analysis": result_json
        }
        
    except Exception as e:
        print(f"❌ 學習歷程分析失敗: {e}")
        traceback.print_exc()
        return {"error": f"分析失敗: {str(e)}"}
