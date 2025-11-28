# call_openai.py（把 ASR 的文字送給 gpt-4.1-nano）
import requests

OPENAI_API_KEY = "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"
OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses"

def ask_gpt4_1_nano(prompt, system_instructions=None):
    headers = {
        "Authorization": f"Bearer {OPENAI_API_KEY}",
        "Content-Type": "application/json"
    }

    payload = {
        "model": "gpt-4.1-nano",
        "input": [
            {"role": "system", "content": system_instructions or "你是溫和的台灣教授。"},
            {"role": "user", "content": prompt}
        ]
    }

    r = requests.post(OPENAI_RESPONSES_URL, json=payload, headers=headers)
    r.raise_for_status()
    data = r.json()

    # 🔥 -----------------------------
    # 正確解析：output -> content -> text
    # 🔥 -----------------------------
    try:
        text = data["output"][0]["content"][0]["text"]
    except:
        text = "(解析失敗，無法取得文字)"

    return text

# 測試
if __name__ == "__main__":
    reply = ask_gpt4_1_nano("請用台灣腔說：你好我是教授。")
    print("GPT 回覆：", reply)