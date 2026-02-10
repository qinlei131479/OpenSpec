import os
from http import HTTPStatus
from dashscope import Application
from ragflow_sdk import RAGFlow
from dotenv import load_dotenv

load_dotenv()

RAGFLOW_API_KEY = os.getenv("RAGFLOW_API_KEY", "")
RAGFLOW_BASE_URL = os.getenv("RAGFLOW_BASE_URL", "")

rag_object = RAGFlow(api_key=RAGFLOW_API_KEY, base_url=RAGFLOW_BASE_URL)
assistant = rag_object.list_chats()
assistant = assistant[0]
session = assistant.create_session()

print("\n==================== Miss R =====================\n")
print("Hello. What can I do for you?")

while True:
    question = input("\n==================== User =====================\n`> ")
    print("\n==================== Miss R =====================\n")

    cont = ""
    for ans in session.ask(question, stream=True):
        print(ans.content[len(cont):], end='', flush=True)
        cont = ans.content
