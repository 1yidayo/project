# call_openai.py（把 ASR 的文字送給 gpt-4.1-nano）
import requests
OPENAI_API_KEY = "你的_OPENAI_API_KEY"
OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses"

def ask_gpt4_1_nano(prompt, system_instructions=None):
    headers = {
        "Authorization": f"Bearer {OPENAI_API_KEY}",
        "Content-Type": "application/json"
    }
    payload = {
        "model": "gpt-4.1-nano",
        "input": [
            {"role": "system", "content": system_instructions or "你現在是一位溫和的台灣教授。"},
            {"role": "user", "content": prompt}
        ]
    }
    r = requests.post(OPENAI_RESPONSES_URL, json=payload, headers=headers)
    r.raise_for_status()
    data = r.json()
    # 根據 Responses API 回傳格式擷取文字（不同版本回傳結構會不同）
    # 下面為通用示例：找第一個 text content
    outputs = data.get("output", None) or data.get("choices", None) or data
    # 嘗試抓常見欄位
    text = ""
    if isinstance(outputs, dict) and outputs.get("content"):
        # 可能是 content list or text
        content = outputs.get("content")
        if isinstance(content, list) and content:
            # 找出 type=text
            for c in content:
                if c.get("type") == "output_text" or c.get("type") == "text":
                    text = c.get("text") or c.get("content")
                    break
    # fallback: try to get 'message' or 'choices'
    if not text:
        # openai older style
        choices = data.get("choices")
        if choices and len(choices) > 0:
            text = choices[0].get("message", {}).get("content", "")
    return text

# 測試
if __name__ == "__main__":
    print(ask_gpt4_1_nano("請用台灣腔簡短回覆：你可以介紹自己嗎？"))