# main.py
import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import chat
import config

app = FastAPI(
    title="Grievance AI Assistant API",
    description="LLaMA 3 powered support assistant for Grievance Redressal app",
    version="1.0.0",
)

# Allow Flutter app to call this API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # In production, replace with your domain
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register routers
app.include_router(chat.router)

@app.get("/")
async def root():
    return {
        "status": "Grievance AI Backend is running",
        "endpoints": {
            "POST /chat/": "Send a message to the AI assistant",
            "GET  /chat/health": "Check if Ollama is running",
        }
    }

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host=config.HOST,
        port=config.PORT,
        reload=True,   # auto-restart on code changes
    )