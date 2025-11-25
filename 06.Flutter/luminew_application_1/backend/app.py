# fileName: app.py
import os
import cv2
import torch
import torch.nn as nn
from torchvision import transforms, models
from PIL import Image
from flask import Flask, request, jsonify
import google.generativeai as genai
import sys

app = Flask(__name__)

# -----------------------------
# 1. 設定專案路徑與 API Key
# -----------------------------
PROJECT_DIR = r"C:\MicroExpressionProject"

# ★ 請確認您的模型檔名是否正確
MODEL_PATH = os.path.join(PROJECT_DIR, "models", "test_best_.pth") 
HAAR_CASCADE_PATH = os.path.join(PROJECT_DIR, "data", "haarcascade_frontalface_default.xml")

# ★★★ 您的 GOOGLE API Key ★★★
GOOGLE_API_KEY = "AIzaSyD6795y_wZdy-3nyioKwTS5OHFj4uIvIOs"

# 設定 Google API
try:
    genai.configure(api_key=GOOGLE_API_KEY)
except Exception as e:
    print(f"⚠️ Google API 設定失敗，請檢查 Key: {e}")

# -----------------------------
# 2. 檢查檔案與載入模型
# -----------------------------
if not os.path.exists(MODEL_PATH):
    print(f"❌ 找不到模型檔：{MODEL_PATH}")
    sys.exit(1)

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"▶ 正在載入模型... (使用設備: {device})")

checkpoint = torch.load(MODEL_PATH, map_location=device)
state_dict = checkpoint["state_dict"] if "state_dict" in checkpoint else checkpoint

# 定義類別
CLASSES = ['confidence', 'nervous', 'passion', 'relaxed'] 

model = models.resnet18(pretrained=False)
fc_keys = [k for k in state_dict.keys() if k.startswith("fc.")]
use_sequential = any(k.startswith("fc.1.") for k in fc_keys)

if use_sequential:
    model.fc = nn.Sequential(nn.Dropout(0.3), nn.Linear(model.fc.in_features, len(CLASSES)))
else:
    model.fc = nn.Linear(model.fc.in_features, len(CLASSES))
    
try:
    model.load_state_dict(state_dict)
except:
    model.load_state_dict(state_dict, strict=False)
    
model = model.to(device)
model.eval()

# 載入人臉辨識
if not os.path.exists(HAAR_CASCADE_PATH):
    HAAR_CASCADE_PATH = cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
print(f"Face Cascade Path: {HAAR_CASCADE_PATH}")
face_cascade = cv2.CascadeClassifier(HAAR_CASCADE_PATH)

# 影像預處理
transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize([0.5]*3, [0.5]*3)
])

# -----------------------------
# 3. 處理 API 請求 (手機上傳影片)
# -----------------------------
@app.route('/analyze', methods=['POST'])
def analyze_video():
    if 'video' not in request.files:
        return jsonify({"error": "No video file provided"}), 400
    
    video_file = request.files['video']
    save_path = os.path.join(PROJECT_DIR, "temp_upload.mp4")
    video_file.save(save_path)
    
    print("📥 收到影片，開始分析...")
    cap = cv2.VideoCapture(save_path)
    session_history = []
    
    frame_count = 0
    detected_count = 0

    # 用來記住最佳的旋轉角度，之後的每一幀就不用一直試了，加速運算
    best_rotation = None 

    with torch.no_grad():
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            
            frame_count += 1
            if frame_count % 3 != 0: continue # 加速：每3幀只測1幀

            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            faces = []
            
            # --- 超強自動旋轉偵測邏輯 ---
            
            # 1. 如果已經知道最佳角度，直接轉
            if best_rotation is not None:
                frame_rotated = cv2.rotate(frame, best_rotation)
                gray_rotated = cv2.cvtColor(frame_rotated, cv2.COLOR_BGR2GRAY)
                faces = face_cascade.detectMultiScale(gray_rotated, 1.1, 5)
                if len(faces) > 0:
                    frame = frame_rotated # 更新畫面

            # 2. 如果還不知道，或是轉了之後突然找不到，就暴力嘗試所有角度
            if len(faces) == 0:
                # 定義要嘗試的旋轉代碼：[原始(跳過), 90度, 270度, 180度]
                rotations = [
                    (None, "原始"),
                    (cv2.ROTATE_90_CLOCKWISE, "90度"),
                    (cv2.ROTATE_90_COUNTERCLOCKWISE, "270度"),
                    (cv2.ROTATE_180, "180度")
                ]
                
                for code, name in rotations:
                    if code is None:
                        # 試原始
                        check_frame = frame
                        check_gray = gray
                    else:
                        # 試旋轉
                        check_frame = cv2.rotate(frame, code)
                        check_gray = cv2.cvtColor(check_frame, cv2.COLOR_BGR2GRAY)
                    
                    found_faces = face_cascade.detectMultiScale(check_gray, 1.1, 5)
                    
                    if len(found_faces) > 0:
                        faces = found_faces
                        frame = check_frame
                        if code is not None:
                            best_rotation = code # 記住這個角度！
                            # print(f"💡 鎖定旋轉角度: {name}")
                        break # 找到了就跳出迴圈

            if len(faces) == 0:
                continue 

            detected_count += 1
            
            # 取最大的人臉
            (x, y, w, h) = max(faces, key=lambda f: f[2] * f[3])
            face_crop = frame[y:y+h, x:x+w]
            
            try:
                img = cv2.cvtColor(face_crop, cv2.COLOR_BGR2RGB)
                img = Image.fromarray(img)
                img_tensor = transform(img).unsqueeze(0).to(device)

                outputs = model(img_tensor)
                probs = torch.softmax(outputs, dim=1)[0]

                current_emotions = {}
                for i, cls in enumerate(CLASSES):
                    current_emotions[cls] = probs[i].item()
                session_history.append(current_emotions)
            except Exception as e:
                pass

    cap.release()
    print(f"📊 分析完成：共讀取 {frame_count} 幀，成功辨識 {detected_count} 幀人臉。")
    
    # 計算辨識率
    if frame_count > 0:
        rate = (detected_count / (frame_count/3)) * 100 # 除以3是因為我們有跳幀
        print(f"🎯 辨識率約: {rate:.1f}%")

    if not session_history:
        return jsonify({"error": "No face detected (請試著拿遠一點或確認光線)"}), 400

    # 計算分數
    avg_scores = {cls: 0.0 for cls in CLASSES}
    for entry in session_history:
        for cls in CLASSES:
            avg_scores[cls] += entry[cls]
            
    final_scores_float = {}
    for cls in CLASSES:
        final_scores_float[cls] = (avg_scores[cls] / len(session_history)) * 100
    
    final_scores_int = {k: int(v) for k, v in final_scores_float.items()}

    print("-" * 40)
    print(f"📈 情緒分佈統計: {final_scores_float}")
    print("-" * 40)

    # -----------------------------
    # 4. 生成 AI 評語
    # -----------------------------
    feedback_json = {
        "overall_score": 0, 
        "comment": "AI 分析失敗", 
        "suggestion": "請稍後再試"
    }
    
    try:
        print("🤖 正在呼叫 Google Gemini AI 面試官...")
        
        prompt = f"""
        你是一位專業的大學入學面試教練。你剛剛觀察了一位高中生的模擬面試表現。
        以下是透過 AI 微表情分析系統偵測到的情緒數據（整場面試的平均佔比）：

        【情緒數據】
        - Confidence (自信): {final_scores_float.get('confidence', 0):.1f}%
        - Passion (熱忱): {final_scores_float.get('passion', 0):.1f}%
        - Relaxed (沈穩/基準線): {final_scores_float.get('relaxed', 0):.1f}%
        - Nervous (緊張/焦慮): {final_scores_float.get('nervous', 0):.1f}%

        【情緒定義參考】
        1. Confidence: 眼神堅定、有自信。
        2. Passion: 談論興趣時展現的熱情。
        3. Relaxed: 專注聆聽或情緒平穩（基準線）。
        4. Nervous: 焦慮、僵硬或不自然。

        【任務】
        請根據以上數據，直接對著這位考生（使用「你」來稱呼），生成一份簡短有力的「面試表現分析報告」。
        
        ⚠️【重要格式要求】⚠️
        因為我是透過 API 呼叫你，請你 **務必** 只回傳一個 JSON 格式的字串，不要有任何 Markdown 標記 (如 ```json)。
        JSON 格式如下：
        {{
            "overall_score": (根據自信與熱忱比例給出的 0-100 整數總分),
            "comment": (針對整體表現與數據洞察的一段話，語氣要像資深親切的教授),
            "suggestion": (針對最弱部分給出的具體改進行動)
        }}
        """

        model_gen = genai.GenerativeModel('gemini-2.0-flash')
        response = model_gen.generate_content(prompt)
        
        clean_text = response.text.replace('```json', '').replace('```', '').strip()
        import json
        feedback_json = json.loads(clean_text)
        
        print("\n📝 AI 回應成功！")
        
    except Exception as e:
        print(f"❌ AI 生成失敗: {e}")

    return jsonify({
        "emotions": final_scores_int,
        "ai_analysis": feedback_json
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)