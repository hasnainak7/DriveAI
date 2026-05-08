# from fastapi import FastAPI
# from pydantic import BaseModel
# import pandas as pd
# import numpy as np
# from sklearn.ensemble import IsolationForest
# import uvicorn
# import google.generativeai as genai # <--- NEW IMPORT

# app = FastAPI(title="AI Engine Anomaly Detector & Mechanic")

# # --- CONFIGURE YOUR AI (Get a free key from aistudio.google.com) ---

# genai.configure(api_key="AIzaSyCwR7PME97KGX5PU9VtwiFKpsJpHyas1Fw")

# llm_model = genai.GenerativeModel('gemini-3.1-flash-lite')

# # --- DATA MODELS ---
# class TelemetryData(BaseModel):
#     rpm: float
#     speed: float
#     load: float
#     coolant: float
#     intake: float
#     throttle: float

# # NEW: Data model for the Chatbot Request
# class DtcChatRequest(BaseModel):
#     car_year: int
#     car_make: str
#     car_model: str
#     dtc_codes: list[str]
#     user_message: str = "" # Optional follow-up questions

# # ... (Keep your existing Isolation Forest code and /analyze endpoint here) ...

# # --- NEW: URDU AI MECHANIC ENDPOINT ---
# @app.post("/mechanic/chat")
# def ai_mechanic_chat(req: DtcChatRequest):
#     # 1. First automatic scan (Keep it short!)
#     if req.user_message == "":
#         codes_str = ", ".join(req.dtc_codes)
#         prompt = f"""
#         You are an expert car mechanic. 
#         The user owns a {req.car_year} {req.car_make} {req.car_model}.
#         Diagnostic Trouble Codes (DTCs) found: {codes_str}.
        
#         TASK: Explain ONLY what these codes mean in simple terms.
#         Keep the answer extremely short and to the point (maximum 3 sentences).
#         Do NOT explain causes or fixes yet.
        
#         CRITICAL RULE: You MUST write your entire response in the Urdu language (using Urdu script).
#         """
#     else:
#         # 2. Follow-up questions (Causes, Fixes, etc.)
#         prompt = f"""
#         You are an expert car mechanic talking to the owner of a {req.car_year} {req.car_make} {req.car_model} with active codes {req.dtc_codes}.
#         The user is asking: "{req.user_message}".
        
#         TASK: Answer their question directly and concisely. Use bullet points to keep it easy to read.
#         CRITICAL RULE: You MUST answer entirely in the Urdu language (using Urdu script).
#         """

#     try:
#         response = llm_model.generate_content(prompt)
#         return {"status": "success", "reply": response.text}
#     except Exception as e:
#         return {"status": "error", "reply": f"Sorry, the AI mechanic is currently unavailable. Error: {str(e)}"}

# if __name__ == "__main__":
#     uvicorn.run(app, host="0.0.0.0", port=8000)


from fastapi import FastAPI
from pydantic import BaseModel
import pandas as pd
import numpy as np
from sklearn.ensemble import IsolationForest
import uvicorn
import google.generativeai as genai

app = FastAPI(title="AI Engine Anomaly Detector & Mechanic")

# --- CONFIGURE YOUR AI ---
genai.configure(api_key="AIzaSyCwR7PME97KGX5PU9VtwiFKpsJpHyas1Fw")
llm_model = genai.GenerativeModel('gemini-3.1-flash-lite')

# --- DATA MODELS ---
class TelemetryData(BaseModel):
    rpm: float
    speed: float
    load: float
    coolant: float
    intake: float
    throttle: float

class DtcChatRequest(BaseModel):
    car_year: int
    car_make: str
    car_model: str
    dtc_codes: list[str]
    user_message: str = ""

# NEW: Data model for the Home Screen Chat
class GeneralChatRequest(BaseModel):
    prompt: str
    context: str

# --- ENDPOINTS ---

# 1. Your Existing DTC Mechanic Endpoint
@app.post("/mechanic/chat")
def ai_mechanic_chat(req: DtcChatRequest):
    if req.user_message == "":
        codes_str = ", ".join(req.dtc_codes)
        prompt = f"""
        You are an expert car mechanic. 
        The user owns a {req.car_year} {req.car_make} {req.car_model}.
        Diagnostic Trouble Codes (DTCs) found: {codes_str}.
        
        TASK: Explain ONLY what these codes mean in simple terms.
        Keep the answer extremely short and to the point (maximum 3 sentences).
        Do NOT explain causes or fixes yet.
        
        CRITICAL RULE: You MUST write your entire response in the Urdu language (using Urdu script).
        """
    else:
        prompt = f"""
        You are an expert car mechanic talking to the owner of a {req.car_year} {req.car_make} {req.car_model} with active codes {req.dtc_codes}.
        The user is asking: "{req.user_message}".
        
        TASK: Answer their question directly and concisely. Use bullet points to keep it easy to read.
        CRITICAL RULE: You MUST answer entirely in the Urdu language (using Urdu script).
        """

    try:
        response = llm_model.generate_content(prompt)
        return {"status": "success", "reply": response.text}
    except Exception as e:
        return {"status": "error", "reply": f"Sorry, the AI mechanic is currently unavailable. Error: {str(e)}"}


# 2. NEW: Home Screen General Chat Endpoint
@app.post("/chat")
def general_ai_chat(req: GeneralChatRequest):
    prompt = f"""
    You are DriveAI, an expert and friendly automotive mechanic assistant.
    You are having a casual conversation with the car owner.
    
    Context about their car: {req.context}
    
    User Question: {req.prompt}
    
    TASK: Answer their question accurately and concisely. Be helpful and professional.
    CRITICAL RULE: You MUST provide your explanation primarily in English, followed by a brief summary in Urdu (using Urdu script).
    """

    try:
        response = llm_model.generate_content(prompt)
        return {"status": "success", "response": response.text}
    except Exception as e:
        return {"status": "error", "response": f"Sorry, the AI mechanic is currently unavailable. Error: {str(e)}"}


# --- RUNNER ---
if __name__ == "__main__":
    # The reload=True flag forces the server to update immediately when you hit Save!
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)