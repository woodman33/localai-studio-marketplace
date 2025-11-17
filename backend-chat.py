from fastapi import FastAPI, HTTPException, Cookie, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import uvicorn
import httpx
import subprocess
import json
import asyncio
import os
import sqlite3
import uuid
import stripe
from typing import Optional

app = FastAPI(title="Local AI Studio Backend")

# CORS for frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Ollama configuration
OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")

# Stripe configuration (set these environment variables)
STRIPE_SECRET_KEY = os.getenv("STRIPE_SECRET_KEY", "")
STRIPE_PUBLISHABLE_KEY = os.getenv("STRIPE_PUBLISHABLE_KEY", "")
STRIPE_WEBHOOK_SECRET = os.getenv("STRIPE_WEBHOOK_SECRET", "")

# Initialize Stripe
if STRIPE_SECRET_KEY and not STRIPE_SECRET_KEY.startswith("PLACEHOLDER"):
    stripe.api_key = STRIPE_SECRET_KEY

# Model pricing - $0.99 each (TinyLlama is free)
MODEL_PRICES = {
    "tinyllama:latest": None,  # FREE
    "llama3.2:3b": 0.99,
    "gemma2:2b": 0.99,
    "phi3.5:mini": 0.99,
    "qwen2.5:7b": 0.99,
    "mistral:7b-instruct-v0.3": 0.99,
}

# Database path - use mounted volume for persistence
DB_PATH = os.path.join('/app/data', 'purchases.db')

# Initialize SQLite database for purchases
def init_db():
    """Create purchases database if it doesn't exist"""
    # Ensure data directory exists
    os.makedirs('/app/data', exist_ok=True)

    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS purchases
                 (user_id TEXT NOT NULL,
                  model_id TEXT NOT NULL,
                  purchase_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  stripe_session_id TEXT,
                  PRIMARY KEY (user_id, model_id))''')
    conn.commit()
    conn.close()

# Initialize database on startup
init_db()

class ChatRequest(BaseModel):
    message: str
    model: str = "tinyllama:latest"

class ChatResponse(BaseModel):
    response: str
    model: str

class InstallRequest(BaseModel):
    model: str

@app.get("/api/health")
async def health():
    """Health check endpoint"""
    return {"status": "healthy", "service": "Local AI Studio Backend"}

@app.post("/api/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """
    Chat endpoint that routes to Ollama
    Supports all 9 models defined in Local AI Studio
    """

    # Model mapping (some models may need different names for Ollama)
    model_map = {
        "tinyllama:latest": "tinyllama:latest",
        "llama3.2:3b": "llama3.2:3b",
        "gemma2:2b": "gemma2:2b",
        "phi3.5:mini": "phi3.5:mini",
        "qwen2.5:7b": "qwen2.5:7b",
        "mistral:7b-instruct-v0.3": "mistral:7b-instruct-v0.3",
        # Cloud models fallback to TinyLlama (pre-installed)
        "llama3.3:70b": "tinyllama:latest",
        "qwen2.5:72b": "tinyllama:latest",
        "deepseek:v3": "tinyllama:latest",
        "gpt-4o-mini": "tinyllama:latest",
        "claude-3.5-sonnet": "tinyllama:latest",
        "mistral-large": "tinyllama:latest",
    }

    ollama_model = model_map.get(request.model, "tinyllama:latest")

    try:
        async with httpx.AsyncClient(timeout=120.0) as client:
            # Call Ollama API
            response = await client.post(
                f"{OLLAMA_BASE_URL}/api/generate",
                json={
                    "model": ollama_model,
                    "prompt": request.message,
                    "stream": False
                }
            )

            if response.status_code == 200:
                data = response.json()
                return ChatResponse(
                    response=data.get("response", "No response from model"),
                    model=request.model
                )
            elif response.status_code == 404:
                # Model not found - provide helpful error
                return ChatResponse(
                    response=f"⚠️ Model '{ollama_model}' not found in Ollama.\n\nTo download: ssh to VPS and run:\n  docker exec ollama ollama pull {ollama_model}\n\nCurrently testing with IP: {OLLAMA_BASE_URL}",
                    model=request.model
                )
            else:
                raise HTTPException(status_code=response.status_code, detail="Ollama error")

    except httpx.ConnectError:
        return ChatResponse(
            response=f"⚠️ Cannot connect to Ollama at {OLLAMA_BASE_URL}\n\nMake sure Ollama is running:\n  docker ps | grep ollama\n\nIf not running:\n  docker start ollama",
            model=request.model
        )
    except Exception as e:
        return ChatResponse(
            response=f"⚠️ Error: {str(e)}\n\nBackend is working but Ollama connection failed.",
            model=request.model
        )

@app.get("/api/models")
async def list_models():
    """List available Ollama models with simplified format for frontend"""
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(f"{OLLAMA_BASE_URL}/api/tags")
            if response.status_code == 200:
                data = response.json()
                # Extract model names from Ollama response
                installed = [model['name'] for model in data.get('models', [])]
                return {"installed": installed, "count": len(installed)}
            return {"installed": [], "count": 0}
    except Exception as e:
        return {"installed": [], "count": 0, "error": str(e)}

@app.post("/api/models/install")
async def install_model(request: InstallRequest):
    """
    One-click model installation endpoint
    Triggers 'ollama pull <model>' on the server
    """
    model = request.model

    # Validate model name (basic security)
    if not model or ".." in model or "/" in model.replace(":", "/", 1):
        raise HTTPException(status_code=400, detail="Invalid model name")

    try:
        # Use Ollama's API to pull the model
        async with httpx.AsyncClient(timeout=600.0) as client:
            response = await client.post(
                f"{OLLAMA_BASE_URL}/api/pull",
                json={"name": model},
                timeout=600.0
            )

            if response.status_code == 200:
                return {
                    "status": "success",
                    "message": f"Model {model} installation started",
                    "model": model
                }
            else:
                raise HTTPException(
                    status_code=response.status_code,
                    detail=f"Ollama pull failed: {response.text}"
                )

    except httpx.ConnectError:
        raise HTTPException(
            status_code=503,
            detail=f"Cannot connect to Ollama at {OLLAMA_BASE_URL}"
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/models/status/{model}")
async def check_model_status(model: str):
    """
    Check if a specific model is installed
    """
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(f"{OLLAMA_BASE_URL}/api/tags")
            if response.status_code == 200:
                data = response.json()
                installed = [m['name'] for m in data.get('models', [])]

                # Check if model is installed (handle version tags)
                is_installed = any(
                    m == model or m.startswith(model.split(':')[0])
                    for m in installed
                )

                return {
                    "model": model,
                    "installed": is_installed,
                    "all_installed": installed
                }
            return {"model": model, "installed": False}
    except Exception as e:
        return {"model": model, "installed": False, "error": str(e)}

# ==================== PURCHASE & PAYMENT ENDPOINTS ====================

def get_user_id(user_id_cookie: Optional[str] = None) -> str:
    """Get or create user ID from cookie"""
    if user_id_cookie:
        return user_id_cookie
    return str(uuid.uuid4())

def has_purchased_model(user_id: str, model_id: str) -> bool:
    """Check if user owns this model"""
    # TinyLlama is always free
    if model_id == "tinyllama:latest":
        return True

    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute('SELECT 1 FROM purchases WHERE user_id = ? AND model_id = ?',
              (user_id, model_id))
    result = c.fetchone() is not None
    conn.close()
    return result

def record_purchase(user_id: str, model_id: str, stripe_session_id: str = ""):
    """Record a model purchase"""
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute('''INSERT OR IGNORE INTO purchases
                 (user_id, model_id, stripe_session_id)
                 VALUES (?, ?, ?)''',
              (user_id, model_id, stripe_session_id))
    conn.commit()
    conn.close()

@app.get("/api/models/owned")
async def get_owned_models(user_id: Optional[str] = Cookie(None)):
    """Get list of models this user owns"""
    user_id = get_user_id(user_id)

    # Always include TinyLlama (free)
    owned = ["tinyllama:latest"]

    # Get purchased models
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute('SELECT model_id FROM purchases WHERE user_id = ?', (user_id,))
    purchased = [row[0] for row in c.fetchall()]
    conn.close()

    owned.extend(purchased)

    return {
        "owned": owned,
        "user_id": user_id  # Return for cookie setting
    }

@app.post("/api/models/purchase/{model_id}")
async def create_purchase_intent(
    model_id: str,
    user_id: Optional[str] = Cookie(None)
):
    """
    Create purchase intent - returns Stripe checkout URL
    In test mode (SKIP_PAYMENT=true), instantly grants access
    """
    user_id = get_user_id(user_id)

    # Check if model exists
    if model_id not in MODEL_PRICES:
        raise HTTPException(400, "Model not available")

    # Check if already owned
    if has_purchased_model(user_id, model_id):
        return {
            "status": "already_owned",
            "message": "You already own this model!",
            "user_id": user_id
        }

    price = MODEL_PRICES[model_id]

    # Free model
    if price is None:
        record_purchase(user_id, model_id)
        return {
            "status": "free",
            "message": "TinyLlama is free! Enjoy.",
            "user_id": user_id
        }

    # Test mode - skip payment
    if os.getenv("SKIP_PAYMENT", "false").lower() == "true":
        record_purchase(user_id, model_id, "test_" + str(uuid.uuid4()))
        return {
            "status": "success",
            "message": f"Test purchase successful! (SKIP_PAYMENT mode)",
            "model": model_id,
            "price": price,
            "user_id": user_id
        }

    # Production: Create Stripe checkout session
    if not STRIPE_SECRET_KEY or STRIPE_SECRET_KEY.startswith("PLACEHOLDER"):
        raise HTTPException(500, "Stripe not configured. Set STRIPE_SECRET_KEY or enable SKIP_PAYMENT=true for testing.")

    try:
        # Create Stripe checkout session
        checkout_session = stripe.checkout.Session.create(
            payment_method_types=['card'],
            line_items=[{
                'price_data': {
                    'currency': 'usd',
                    'unit_amount': int(price * 100),  # Convert to cents
                    'product_data': {
                        'name': f'AI Model: {model_id}',
                        'description': f'One-time purchase for {model_id} - download and run locally forever',
                    },
                },
                'quantity': 1,
            }],
            mode='payment',
            success_url=f'{os.getenv("FRONTEND_URL", "http://localhost:3000")}/marketplace?success=true&model={model_id}',
            cancel_url=f'{os.getenv("FRONTEND_URL", "http://localhost:3000")}/marketplace?canceled=true',
            metadata={
                'user_id': user_id,
                'model_id': model_id,
            }
        )

        return {
            "status": "payment_required",
            "checkout_url": checkout_session.url,
            "session_id": checkout_session.id,
            "model": model_id,
            "price": price,
            "user_id": user_id
        }

    except Exception as e:
        raise HTTPException(500, f"Failed to create checkout session: {str(e)}")

@app.post("/api/stripe/webhook")
async def stripe_webhook(request: Request):
    """
    Handle Stripe webhook events for completed payments
    """
    if not STRIPE_SECRET_KEY or not STRIPE_WEBHOOK_SECRET:
        raise HTTPException(501, "Stripe not configured")

    payload = await request.body()
    sig_header = request.headers.get('stripe-signature')

    try:
        # Verify webhook signature
        event = stripe.Webhook.construct_event(
            payload, sig_header, STRIPE_WEBHOOK_SECRET
        )
    except ValueError:
        raise HTTPException(400, "Invalid payload")
    except stripe.error.SignatureVerificationError:
        raise HTTPException(400, "Invalid signature")

    # Handle checkout.session.completed event
    if event['type'] == 'checkout.session.completed':
        session = event['data']['object']

        # Extract metadata
        user_id = session['metadata'].get('user_id')
        model_id = session['metadata'].get('model_id')

        if user_id and model_id:
            # Record the purchase
            record_purchase(user_id, model_id, session['id'])
            print(f"✅ Purchase recorded: {user_id} bought {model_id}")
        else:
            print(f"⚠️ Missing metadata in webhook: {session['metadata']}")

    return {"status": "success"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
