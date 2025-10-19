import requests
import time
import os
import base64
import json 
from dotenv import load_dotenv

# --- 關鍵修正：強制設定工作目錄 ---
# 確保無論從哪裡運行，程式碼都能找到同目錄下的 .env 檔案
try:
    # os.path.dirname(__file__) 獲取當前腳本所在的目錄
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    print(f"工作目錄已強制設定為: {os.getcwd()}")
except NameError:
    # 如果在交互式環境中運行 (非腳本)，這條會跳過
    pass
# ------------------------------------

# --- MiniMax Group ID 提取函數 ---
def extract_minimax_group_id(jwt_token):
    """從 MiniMax 的 JWT Token 中解析出 Group ID"""
    try:
        payload_base64 = jwt_token.split('.')[1]
        padding = '=' * (4 - (len(payload_base64) % 4))
        decoded_payload = base64.b64decode(payload_base64 + padding).decode('utf-8')
        payload_data = json.loads(decoded_payload)
        return payload_data.get('GroupID') 
    except Exception:
        # 由於 Key 已確認包含 Group ID: 1955237877264687899
        return "1955237877264687899"


# 載入 .env 檔案中的環境變數
load_dotenv()

# --- 配置區塊：從 .env 讀取 ---
D_ID_API_KEY = os.getenv("D_ID_API_KEY")
MINIMAX_API_KEY = os.getenv("MINIMAX_API_KEY")
INTERVIEWER_IMAGE_URL = os.getenv("INTERVIEWER_IMAGE_URL")
MINIMAX_GROUP_ID = extract_minimax_group_id(MINIMAX_API_KEY)

# --- MiniMax TTS 語音設定 ---
MINIMAX_API_URL = "https://api.minimax.chat/v1/text_to_speech"
TTS_MODEL = "speech-01"
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
            print(f"   ❌ MiniMax API 返回非音訊格式。可能為 Key 或 GroupID 錯誤。")
            print(f"   Response Text: {response.text}")
            return None
            
    except requests.exceptions.HTTPError as http_err:
        print(f"   ❌ MiniMax TTS 請求失敗 (HTTP 錯誤): {http_err}")
        print(f"   狀態碼: {response.status_code}")
        if response.status_code == 401:
            print("   【錯誤診斷】: MiniMax API Key 或 Group ID 無效。")
        return None
    except requests.exceptions.RequestException as e:
        print(f"   ❌ MiniMax TTS 請求失敗 (連線錯誤): {e}")
        return None

def generate_talking_head(image_url, audio_content_base64, api_key):
    """使用 D-ID API 結合圖片和 Base64 音訊生成說話頭像影片"""
    print("\n--- 步驟 2: 正在使用 D-ID API 創建說話頭像影片 ---")
    D_ID_BASE_URL = "https://api.d-id.com/talks"
    
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
             raise Exception("D-ID API 未返回 talk ID。請檢查 Key 或圖片 URL 存取性。")
             
        print(f"   ✅ 影片生成請求成功。Talk ID: {talk_id}")
        return talk_id
        
    except requests.exceptions.HTTPError as http_err:
        print(f"   ❌ D-ID 請求失敗 (HTTP 錯誤): {http_err}")
        if response.status_code == 401:
            print("   【錯誤診斷】: D-ID API Key 無效。")
        elif response.status_code == 400:
            print(f"   【錯誤診斷】: 請求參數錯誤，詳情: {response.json().get('detail', 'N/A')}")
        return None
    except requests.exceptions.RequestException as e:
        print(f"   ❌ D-ID 請求失敗 (連線錯誤): {e}")
        return None


def poll_and_download_video(talk_id, api_key):
    """查詢 D-ID 影片狀態並下載完成的影片"""
    # 邏輯與之前相同，略
    print("\n--- 步驟 3: 查詢影片狀態並下載 (略) ---")
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
            elif status == 'error':
                error_detail = response.json().get('error', '未知錯誤')
                print(f"   ❌ 影片生成失敗: {error_detail}")
                break
            else:
                elapsed = int(time.time() - start_time)
                print(f"   🔄 影片仍在生成中... (已等待 {elapsed} 秒)。")
                time.sleep(5) 
                
        except requests.exceptions.RequestException as e:
            print(f"   ❌ 查詢狀態失敗: {e}")
            break
            

def main():
    """主函數：整合 MiniMax TTS 與 D-ID Talking Head"""
    if not D_ID_API_KEY or not MINIMAX_API_KEY or not INTERVIEWER_IMAGE_URL or not MINIMAX_GROUP_ID:
        print("致命錯誤：配置檢查失敗。請確認所有金鑰和 URL 都在 .env 中。")
        # 由於 Group ID 可能是解析錯誤，如果 Key 存在，我們仍允許繼續，讓 API 報告錯誤
        if not MINIMAX_API_KEY: return
        if not D_ID_API_KEY: return
        
    print(f"正在使用 Group ID: {MINIMAX_GROUP_ID}")

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
        print(f"運行時發生嚴重錯誤: {e}")
            
if __name__ == "__main__":
    main()