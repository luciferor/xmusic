import requests
import sys
import os

def generate_code(prompt, api_key):
    headers = {"Authorization": f"Bearer {api_key}"}
    data = {
        "model": "deepseek-chat",
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.3
    }
    response = requests.post("https://api.deepseek.com/v1/chat/completions", json=data, headers=headers)
    return response.json()["choices"][0]["message"]["content"]

if __name__ == "__main__":
    API_KEY = "sk-4f5e2d4e15274b7ea64620b93bf35723"  # 替换为你的 Key
    print("离火AI已启动，输入'exit' 退出。\n")
    while True:
        try:
            # 持续获取输入（严格匹配退出指令）
            code_prompt = input(">>").strip()  # .strip() 移除首尾空白字符
            if not code_prompt:  # 处理空输入
                continue
            if code_prompt.lower() in ('exit', 'quit'):
                print("正在退出...")
                break
            
            # 调用并打印结果
            result = generate_code(code_prompt, API_KEY)
            print("\n【结果】\n", result, "\n")

        except KeyboardInterrupt:
            print("\n已通过 Ctrl+C 退出。")
            break
        except Exception as e:
            print(f"发生错误: {e}\n")

    # 确保程序终止
    print("程序已结束。")
    exit(0)

if sys.platform == "win32":
    # Windows: 结束终端进程（需根据实际终端类型调整）
    os.system("taskkill /f /im powershell.exe")
else:
    # Linux/Mac: 结束终端进程（示例为 Bash）
    os.system("kill -9 $PPID")