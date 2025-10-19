import requests
import time
import os
import base64
import json # 新增：用於解析 JWT 中的 Group ID
from dotenv import load_dotenv

# --- MiniMax Group ID 提取函數 ---
def extract_minimax_group_id(jwt_token):
    """從 MiniMax 的 JWT Token 中解析出 Group ID"""
    try:
        # JWT 格式為 header.payload.signature。我們需要解析 payload (第二部分)。
        payload_base64 = jwt_token.split('.')[1]
        
        # Base64 解碼時，長度必須是 4 的倍數，不足的部分用 '=' 補齊
        padding = '=' * (4 - (len(payload_base64) % 4))
        decoded_payload = base64.b64decode(payload_base64 + padding).decode('utf-8')
        
        payload_data = json.loads(decoded_payload)
        return payload_data.get('GroupID') # 注意：鍵名是 'GroupID'
    except Exception as e:
        print(f"解析 MiniMax Group ID 失敗: {e}")
        return None


# 載入 .env 檔案中的環境變數
load_dotenv()

# --- 配置區塊：從 .env 讀取 ---
D_ID_API_KEY = os.getenv("D_ID_API_KEY")
MINIMAX_API_KEY = os.getenv("MINIMAX_API_KEY")
INTERVIEWER_IMAGE_URL = os.getenv("INTERVIEWER_IMAGE_URL")

# --- MiniMax TTS 語音設定 ---
# 透過解析 Key 獲取 Group ID
MINIMAX_GROUP_ID = extract_minimax_group_id(MINIMAX_API_KEY)

MINIMAX_API_URL = "https://api.minimax.chat/v1/text_to_speech"
TTS_MODEL = "speech-01"
# 聲線 ID：使用一個常見的中文聲線，請根據您的需求和 MiniMax 文檔確認
TTS_VOICE_ID = "v2_qingxin" 

# 您要讓面試官說的台詞
INTERVIEWER_SCRIPT = "您好，歡迎來到我們的 AI 模擬面試。今天我們將專注於測試您的溝通技巧與解決問題的能力。準備好了嗎？"

# --- API 核心函數 ---

def text_to_speech_minimax(text, voice_id, api_key, group_id):
    """使用 MiniMax TTS API 將文字轉為 Base64 編碼的音訊內容"""
    print("--- 步驟 1: 正在使用 MiniMax TTS 轉換文字為音訊 ---")
    
    headers = {
        'Authorization': f'Bearer {api_key}', 
        'Content-Type': 'application/json'
    }
    
    data = {
        "text": text,
        "voice_id": voice_id,
        "model": TTS_MODEL,
        "audio_format": "mp3"
    }

    try:
        url = f"{MINIMAX_API_URL}?GroupId={group_id}"
        response = requests.post(url, headers=headers, json=data)
        response.raise_for_status()
        
        if response.headers.get('Content-Type') == 'audio/mpeg':
            audio_content_base64 = base64.b64encode(response.content).decode('utf-8')
            print("   ✅ 音訊生成並 Base64 編碼成功。")
            return audio_content_base64
        else:
            print(f"   ❌ MiniMax API 返回非音訊格式。可能為參數錯誤。")
            print(f"   Response Text: {response.text}")
            return None
            
    except requests.exceptions.RequestException as e:
        print(f"   ❌ MiniMax TTS 請求失敗: {e}")
        return None

def generate_talking_head(image_url, audio_content_base64, api_key):
    """使用 D-ID API 結合圖片和 Base64 音訊生成說話頭像影片"""
    print("\n--- 步驟 2: 正在使用 D-ID API 創建說話頭像影片 ---")
    D_ID_BASE_URL = "https://api.d-id.com/talks"
    
    # D-ID 身份驗證：將 API Key 進行 Base64 編碼 (Basic Auth)
    encoded_key = base64.b64encode(f"{api_key}:".encode('utf-8')).decode('utf-8')
    headers = {
        'Authorization': f'Basic {encoded_key}', 
        'Content-Type': 'application/json'
    }
    
    data = {
        "source_url": image_url,
        "script": {
            "type": "audio",
            "input": audio_content_base64,
            "provider": {"type": "base64"}
        }
    }

    try:
        response = requests.post(D_ID_BASE_URL, headers=headers, json=data)
        response.raise_for_status()
        
        talk_id = response.json().get('id')
        if not talk_id:
             print(f"D-ID 詳情: {response.json().get('detail', '無詳細資訊')}")
             raise Exception("D-ID API 未返回 talk ID。請檢查 API Key 或圖片 URL 存取性。")
             
        print(f"   ✅ 影片生成請求成功。Talk ID: {talk_id}")
        return talk_id
        
    except requests.exceptions.RequestException as e:
        print(f"   ❌ D-ID 請求失敗: {e}")
        return None


def poll_and_download_video(talk_id, api_key):
    """查詢 D-ID 影片狀態並下載完成的影片"""
    print("\n--- 步驟 3: 查詢影片狀態並下載 ---")
    D_ID_BASE_URL = "https://api.d-id.com/talks"
    
    encoded_key = base64.b64encode(f"{api_key}:".encode('utf-8')).decode('utf-8')
    headers = {'Authorization': f'Basic {encoded_key}'}
    video_url = f"{D_ID_BASE_URL}/{talk_id}"
    
    start_time = time.time()
    while True:
        try:
            response = requests.get(video_url, headers=headers)
            response.raise_for_status()
            status = response.json().get('status')
            
            if status == 'done':
                print(f"   ✅ 影片生成完成！耗時 {int(time.time() - start_time)} 秒。")
                
                video_download_url = response.json().get('result_url')
                video_data = requests.get(video_download_url)
                
                output_filename = f"interviewer_intro_{talk_id}.mp4"
                with open(output_filename, 'wb') as f:
                    f.write(video_data.content)
                    
                print(f"   💾 影片已儲存為：{output_filename}")
                break
                
            elif status == 'started' or status == 'in_progress':
                elapsed = int(time.time() - start_time)
                print(f"   🔄 影片仍在生成中... (已等待 {elapsed} 秒)。")
                time.sleep(5)  # 每 5 秒查詢一次
            
            elif status == 'error':
                error_detail = response.json().get('error', '未知錯誤')
                print(f"   ❌ 影片生成失敗: {error_detail}")
                break
                
            else:
                print(f"   ❓ 未知的狀態: {status}")
                time.sleep(5)
                
        except requests.exceptions.RequestException as e:
            print(f"   ❌ 查詢狀態失敗: {e}")
            break
            

def main():
    """主函數：整合 MiniMax TTS 與 D-ID Talking Head"""
    if not D_ID_API_KEY or not MINIMAX_API_KEY or not INTERVIEWER_IMAGE_URL or not MINIMAX_GROUP_ID:
        print("致命錯誤：請檢查 .env 檔案或 Group ID 提取。確保所有金鑰和 URL 已填入。")
        return

    try:
        # 1. MiniMax 文字轉語音
        audio_base64 = text_to_speech_minimax(INTERVIEWER_SCRIPT, TTS_VOICE_ID, MINIMAX_API_KEY, MINIMAX_GROUP_ID)

        if audio_base64:
            # 2. 創建 D-ID 說話頭像請求
            talk_id = generate_talking_head(INTERVIEWER_IMAGE_URL, audio_base64, D_ID_API_KEY)
            
            if talk_id:
                # 3. 查詢狀態並下載影片
                poll_and_download_video(talk_id, D_ID_API_KEY)
                
    except Exception as e:
        print(f"運行時發生未知錯誤: {e}")
            
if __name__ == "__main__":
    main()