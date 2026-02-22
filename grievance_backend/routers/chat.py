# routers/chat.py
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from groq import Groq
import config

router = APIRouter(prefix="/chat", tags=["chat"])

# Initialize Groq client
client = Groq(api_key=config.GROQ_API_KEY)

# ── Request / Response models ──────────────────────────────────────────────────

class Message(BaseModel):
    role: str
    content: str

class ChatRequest(BaseModel):
    user_id: str
    message: str
    history: Optional[List[Message]] = []

class ChatResponse(BaseModel):
    response: str
    success: bool
    error: Optional[str] = None

# ── Helper: call Groq ──────────────────────────────────────────────────────────

def call_groq(messages: List[dict]) -> str:
    try:
        response = client.chat.completions.create(
            model="llama-3.1-8b-instant",   # ✅ updated model
            messages=messages,
            max_tokens=300,
            temperature=0.7,
        )
        return response.choices[0].message.content.strip()

    except Exception as e:
        error_msg = str(e)
        if "api_key" in error_msg.lower():
            raise HTTPException(
                status_code=401,
                detail="Invalid Groq API key. Check your .env file."
            )
        if "rate_limit" in error_msg.lower():
            raise HTTPException(
                status_code=429,
                detail="Too many requests. Please wait a moment and try again."
            )
        raise HTTPException(
            status_code=500,
            detail=f"Groq error: {error_msg}"
        )

# ── Main chat endpoint ─────────────────────────────────────────────────────────

@router.post("/", response_model=ChatResponse)
async def chat(request: ChatRequest):
    if not request.message or not request.message.strip():
        raise HTTPException(status_code=400, detail="Message cannot be empty")

    if len(request.message) > 2000:
        raise HTTPException(status_code=400, detail="Message too long (max 2000 chars)")

    # Build message list: system prompt + history + new user message
    messages = [{"role": "system", "content": config.SYSTEM_PROMPT}]

    # Add conversation history (last 10 messages)
    for msg in (request.history or [])[-10:]:
        messages.append({"role": msg.role, "content": msg.content})

    # Add new user message
    messages.append({"role": "user", "content": request.message.strip()})

    # Call Groq
    reply = call_groq(messages)

    return ChatResponse(response=reply, success=True)

# ── Health check ───────────────────────────────────────────────────────────────

@router.get("/health")
async def health_check():
    try:
        test = client.chat.completions.create(
            model="llama-3.1-8b-instant",   # ✅ updated model
            messages=[{"role": "user", "content": "hi"}],
            max_tokens=5,
        )
        return {
            "status": "running",
            "provider": "Groq",
            "model": "llama-3.1-8b-instant",   # ✅ updated model
            "api_key_valid": True,
        }
    except Exception as e:
        return {
            "status": "error",
            "provider": "Groq",
            "error": str(e),
        }