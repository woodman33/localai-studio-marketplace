from fastapi import FastAPI, HTTPException, Cookie, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
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

# Demo mode - disable model installation on public demo
DEMO_MODE = os.getenv("DEMO_MODE", "false").lower() == "true"

# Stripe configuration (set these environment variables)
STRIPE_SECRET_KEY = os.getenv("STRIPE_SECRET_KEY", "")
STRIPE_PUBLISHABLE_KEY = os.getenv("STRIPE_PUBLISHABLE_KEY", "")
STRIPE_WEBHOOK_SECRET = os.getenv("STRIPE_WEBHOOK_SECRET", "")

# Initialize Stripe
if STRIPE_SECRET_KEY and not STRIPE_SECRET_KEY.startswith("PLACEHOLDER"):
    stripe.api_key = STRIPE_SECRET_KEY

# Gumroad configuration for instant monetization
try:
    GUMROAD_API_KEY = os.getenv("GUMROAD_API_KEY", "").strip().strip('"').strip("'")
    GUMROAD_PRODUCT_PERMALINK = os.getenv("GUMROAD_PRODUCT_PERMALINK", "udody").strip().strip('"').strip("'")

    # Print config on startup for debugging
    print(f"[CONFIG] Gumroad Key Raw: '{os.getenv('GUMROAD_API_KEY', '')}'")
    print(f"[CONFIG] Gumroad Key Configured: {'Yes' if GUMROAD_API_KEY else 'No'}")
    print(f"[CONFIG] Gumroad Permalink: {GUMROAD_PRODUCT_PERMALINK}")
except Exception as e:
    print(f"[CONFIG] ERROR loading Gumroad config: {e}")
    GUMROAD_API_KEY = ""
    GUMROAD_PRODUCT_PERMALINK = "udody"

# License key cache (upgrade to DB later if needed)
VALID_LICENSES = set()

# Free tier models (3 models)
FREE_MODELS = ["tinyllama:latest", "llama3.2:3b", "gemma2:2b"]

# Pro tier models (all 11 - synced with frontend Ollama models)
PRO_MODELS = [
    "tinyllama:latest",
    "llama3.2:3b",
    "gemma2:2b",
    "llama3.1:8b",
    "codellama:7b",
    "mistral:7b-instruct",
    "phi3:medium",
    "gemma2:9b",
    "phi3.5:mini",
    "qwen2.5:7b",
    "deepseek-coder:6.7b"
]

# Model pricing - OLD SYSTEM (keeping for reference, not used with Gumroad)
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
async def install_model_post(request: InstallRequest):
    """
    One-click model installation endpoint with REAL Ollama streaming
    Streams download progress via Server-Sent Events (SSE)
    POST version for API calls
    """
    model = request.model

    print(f"\n[MODEL INSTALL] Starting installation: {model}")
    return await _install_model_stream(model)

@app.get("/api/models/install")
async def install_model_get(model: str):
    """
    One-click model installation endpoint with REAL Ollama streaming
    Streams download progress via Server-Sent Events (SSE)
    GET version for EventSource compatibility
    """
    print(f"\n[MODEL INSTALL] Starting installation (GET): {model}")
    return await _install_model_stream(model)

async def _install_model_stream(model: str):
    """
    Internal function to handle model installation streaming
    Shared by both POST and GET endpoints
    """
    # Block model installation in demo mode
    if DEMO_MODE:
        print(f"[MODEL INSTALL] Blocked - demo mode enabled")
        raise HTTPException(
            status_code=403,
            detail="Model installation disabled on public demo. Download Local AI Studio to install models on your own machine."
        )

    # Validate model name (basic security)
    # Allow format: name:tag or name (no path traversal)
    if not model or ".." in model or "/" in model:
        print(f"[MODEL INSTALL] Invalid model name: {model}")
        raise HTTPException(status_code=400, detail="Invalid model name")

    try:
        async def generate_progress():
            """Stream real-time progress from Ollama's pull API"""
            try:
                print(f"[MODEL INSTALL] Connecting to Ollama at {OLLAMA_BASE_URL}")

                async with httpx.AsyncClient(timeout=600.0) as client:
                    async with client.stream(
                        'POST',
                        f'{OLLAMA_BASE_URL}/api/pull',
                        json={"name": model},
                    ) as response:
                        print(f"[MODEL INSTALL] Ollama response status: {response.status_code}")

                        if response.status_code != 200:
                            error_text = await response.aread()
                            print(f"[MODEL INSTALL] Error response: {error_text.decode()}")
                            yield f"data: {json.dumps({'status': 'error', 'error': error_text.decode()})}\n\n"
                            return

                        # Stream progress line by line from Ollama
                        async for line in response.aiter_lines():
                            if line.strip():
                                try:
                                    progress_data = json.loads(line)

                                    # Log progress for debugging
                                    status = progress_data.get('status', '')
                                    if 'total' in progress_data and 'completed' in progress_data:
                                        total = progress_data['total']
                                        completed = progress_data['completed']
                                        percent = (completed / total * 100) if total > 0 else 0
                                        print(f"[MODEL INSTALL] Progress: {status} - {percent:.1f}% ({completed}/{total} bytes)")
                                    else:
                                        print(f"[MODEL INSTALL] Status: {status}")

                                    # Forward progress to frontend
                                    yield f"data: {json.dumps(progress_data)}\n\n"

                                except json.JSONDecodeError as e:
                                    print(f"[MODEL INSTALL] JSON decode error: {e} - line: {line}")
                                    continue

                # Send completion event
                print(f"[MODEL INSTALL] Installation complete: {model}")
                yield f"data: {json.dumps({'status': 'success', 'message': f'Model {model} installed successfully'})}\n\n"

            except httpx.ConnectError as e:
                print(f"[MODEL INSTALL] Connection error: {str(e)}")
                yield f"data: {json.dumps({'status': 'error', 'error': f'Cannot connect to Ollama at {OLLAMA_BASE_URL}'})}\n\n"
            except Exception as e:
                print(f"[MODEL INSTALL] Unexpected error: {type(e).__name__}: {str(e)}")
                import traceback
                print(f"[MODEL INSTALL] Traceback: {traceback.format_exc()}")
                yield f"data: {json.dumps({'status': 'error', 'error': str(e)})}\n\n"

        return StreamingResponse(
            generate_progress(),
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
                "X-Accel-Buffering": "no"  # Disable nginx buffering
            }
        )

    except Exception as e:
        print(f"[MODEL INSTALL] Fatal error: {str(e)}")
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

# ==================== GUMROAD LICENSE SYSTEM ====================

class LicenseRequest(BaseModel):
    license_key: str

@app.post("/api/license/validate")
async def validate_license(request: LicenseRequest):
    """
    Validate license key via Gumroad API
    Instant monetization - no Stripe approval needed
    """
    license_key = request.license_key.strip()

    print(f"\n[LICENSE VALIDATE] Received key: {license_key[:20]}..." if len(license_key) > 20 else f"\n[LICENSE VALIDATE] Received key: {license_key}")

    # Development mode - accept DEV- keys for testing
    if license_key.startswith("DEV-"):
        VALID_LICENSES.add(license_key)
        print(f"[LICENSE VALIDATE] Development key accepted: {license_key}")
        return JSONResponse({
            "valid": True,
            "tier": "pro",
            "message": "Development key activated"
        })

    # Check if already validated (cache)
    if license_key in VALID_LICENSES:
        print(f"[LICENSE VALIDATE] Key found in cache: {license_key[:20]}...")
        return JSONResponse({"valid": True, "tier": "pro", "message": "License already validated"})

    # Production: Validate with Gumroad API
    if not GUMROAD_API_KEY or GUMROAD_API_KEY == "":
        print("[LICENSE VALIDATE] ERROR: Gumroad API key not configured")
        return JSONResponse({
            "valid": False,
            "message": "Gumroad not configured. Use DEV-TEST-KEY for testing."
        })

    try:
        print(f"[LICENSE VALIDATE] Calling Gumroad API...")
        print(f"[LICENSE VALIDATE] Product permalink: {GUMROAD_PRODUCT_PERMALINK}")
        print(f"[LICENSE VALIDATE] API key configured: {GUMROAD_API_KEY[:10]}...")

        async with httpx.AsyncClient(timeout=10.0) as client:
            # Try license key verification first
            response = await client.post(
                "https://api.gumroad.com/v2/licenses/verify",
                data={
                    "product_permalink": GUMROAD_PRODUCT_PERMALINK,
                    "license_key": license_key
                },
                headers={"Authorization": f"Bearer {GUMROAD_API_KEY}"}
            )

            # If license verification fails, try order ID lookup
            if response.status_code != 200 or not response.json().get("success", False):
                print(f"[LICENSE VALIDATE] License verification failed, trying order ID lookup...")
                
                # Note: We don't pass product_id here because we only have the permalink
                # and v2/sales expects a product ID (not permalink) for filtering.
                # We'll verify the product in the response instead.
                sales_response = await client.get(
                    "https://api.gumroad.com/v2/sales",
                    params={
                        "order_id": license_key
                    },
                    headers={"Authorization": f"Bearer {GUMROAD_API_KEY}"}
                )

                print(f"[LICENSE VALIDATE] Sales lookup status: {sales_response.status_code}")
                print(f"[LICENSE VALIDATE] Sales lookup body: {sales_response.text[:1000]}")

                if sales_response.status_code == 200:
                    sales_data = sales_response.json()
                    if sales_data.get("success") and len(sales_data.get("sales", [])) > 0:
                        sale = sales_data["sales"][0]
                        
                        # Verify this sale is for our product
                        sale_permalink = sale.get("product_permalink", "")
                        print(f"[LICENSE VALIDATE] Found sale for product: {sale_permalink}")
                        
                        # Handle case where permalink might be full URL or just the slug
                        if GUMROAD_PRODUCT_PERMALINK in sale_permalink:
                            print(f"[LICENSE VALIDATE] ✅ Valid order ID: {license_key}")
                            VALID_LICENSES.add(license_key)
                            return JSONResponse({
                                "valid": True,
                                "tier": "pro",
                                "purchaser_email": sale.get("email", "unknown"),
                                "message": "Valid Pro license (verified via order ID)"
                            })
                        else:
                            print(f"[LICENSE VALIDATE] ❌ Order found but for different product: {sale_permalink} (expected {GUMROAD_PRODUCT_PERMALINK})")
                    else:
                         print(f"[LICENSE VALIDATE] ❌ Sales lookup successful but no sales found for ID")

                # DEBUG: List recent sales to see what's going on (Run this if we haven't returned yet)
                print(f"[LICENSE VALIDATE] DEBUG: Fetching recent sales to verify format...")
                recent_sales_response = await client.get(
                     "https://api.gumroad.com/v2/sales",
                     headers={"Authorization": f"Bearer {GUMROAD_API_KEY}"}
                )
                if recent_sales_response.status_code == 200:
                     recent_data = recent_sales_response.json()
                     sales = recent_data.get("sales", [])
                     print(f"[LICENSE VALIDATE] DEBUG: Found {len(sales)} recent sales.")
                     for i, s in enumerate(sales[:5]):
                         print(f"[LICENSE VALIDATE] Sale {i+1}: Order ID='{s.get('order_id')}', Product='{s.get('product_permalink')}', Price='{s.get('formatted_total_price')}'")
                else:
                     print(f"[LICENSE VALIDATE] DEBUG: Failed to fetch recent sales: {recent_sales_response.status_code}")

                print(f"[LICENSE VALIDATE] Both license key and order ID validation failed")
                return JSONResponse({
                    "valid": False,
                    "message": "Invalid license key or order ID"
                })

            print(f"[LICENSE VALIDATE] Gumroad response status: {response.status_code}")
            print(f"[LICENSE VALIDATE] Gumroad response body: {response.text[:500]}")

            if response.status_code == 200:
                data = response.json()

                # Check if purchase/subscription is valid
                purchase = data.get("purchase", {})
                success = data.get("success", False)
                refunded = purchase.get("refunded", True)
                cancelled = purchase.get("subscription_cancelled_at")
                failed = purchase.get("subscription_failed_at")

                print(f"[LICENSE VALIDATE] Gumroad validation - success: {success}, refunded: {refunded}, cancelled: {cancelled}, failed: {failed}")

                if (success and
                    refunded == False and
                    cancelled is None and
                    failed is None):

                    # Cache valid license
                    VALID_LICENSES.add(license_key)
                    buyer_email = purchase.get("email", "")
                    print(f"[LICENSE VALIDATE] ✅ Valid license! Buyer: {buyer_email}")

                    return JSONResponse({
                        "valid": True,
                        "tier": "pro",
                        "buyer_email": buyer_email,
                        "message": "Pro license activated!"
                    })
                else:
                    print(f"[LICENSE VALIDATE] ❌ Invalid license - failed validation checks")

            print(f"[LICENSE VALIDATE] ❌ Invalid license - bad status code or data")
            return JSONResponse({
                "valid": False,
                "message": "Invalid or refunded license key"
            })

    except httpx.TimeoutException as e:
        print(f"[LICENSE VALIDATE] ⚠️ Timeout error: {str(e)}")
        return JSONResponse({
            "valid": False,
            "message": "Gumroad API timeout. Please try again."
        })
    except Exception as e:
        print(f"[LICENSE VALIDATE] ❌ Exception: {type(e).__name__}: {str(e)}")
        import traceback
        print(f"[LICENSE VALIDATE] Traceback: {traceback.format_exc()}")
        return JSONResponse({
            "valid": False,
            "message": f"Validation error: {str(e)}"
        })

from fastapi import FastAPI, HTTPException, Cookie, Request, Query

# ... (imports remain the same)

@app.get("/api/license/check")
async def check_license(license_key: Optional[str] = Query(None), cookie_key: Optional[str] = Cookie(None, alias="license_key")):
    """
    Check user's current tier based on license key
    Returns available models for their tier

    Frontend can pass license key via query param (from localStorage) or cookie
    """
    # Prefer query param (from localStorage), fallback to cookie
    final_key = license_key if license_key else cookie_key
    
    print(f"\n[LICENSE CHECK] Checking license status...")
    print(f"[LICENSE CHECK] License key: {final_key[:20] + '...' if final_key and len(final_key) > 20 else final_key}")

    # No license = free tier
    if not final_key:
        print("[LICENSE CHECK] No license key provided - returning free tier")
        return JSONResponse({
            "tier": "free",
            "models": FREE_MODELS,
            "message": "Free tier (3 models)"
        })

    # Check cache first
    if final_key in VALID_LICENSES:
        print(f"[LICENSE CHECK] ✅ License key found in cache - returning pro tier")
        return JSONResponse({
            "tier": "pro",
            "models": PRO_MODELS,
            "message": "Pro tier (all 11 models)"
        })

    print(f"[LICENSE CHECK] License key not in cache, validating with Gumroad...")

    # Validate license (adds to cache if valid)
    try:
        validation_result = await validate_license(LicenseRequest(license_key=final_key))
        # ... rest of function ...



        # Extract JSON from JSONResponse if needed
        if isinstance(validation_result, JSONResponse):
            import json
            validation_data = json.loads(validation_result.body.decode())
        else:
            validation_data = validation_result

        if validation_data.get("valid"):
            print(f"[LICENSE CHECK] ✅ License validated successfully - returning pro tier")
            return JSONResponse({
                "tier": "pro",
                "models": PRO_MODELS,
                "message": "Pro tier (all 11 models)"
            })
    except Exception as e:
        print(f"[LICENSE CHECK] ❌ Validation error: {str(e)}")

    # Invalid license = free tier
    print("[LICENSE CHECK] ❌ Invalid license - returning free tier")
    return JSONResponse({
        "tier": "free",
        "models": FREE_MODELS,
        "message": "Free tier (3 models)"
    })

@app.get("/api/debug/config")
async def debug_config():
    """
    Debug endpoint to check environment configuration
    """
    return {
        "gumroad_key_configured": bool(GUMROAD_API_KEY),
        "gumroad_key_length": len(GUMROAD_API_KEY) if GUMROAD_API_KEY else 0,
        "gumroad_key_preview": f"{GUMROAD_API_KEY[:5]}..." if GUMROAD_API_KEY else "None",
        "gumroad_permalink": GUMROAD_PRODUCT_PERMALINK,
        "frontend_url": FRONTEND_URL,
        "skip_payment": SKIP_PAYMENT
    }

@app.get("/api/models/available")
async def get_available_models(license_key: Optional[str] = Cookie(None)):
    """
    Get list of models available to user based on license
    Used by frontend to show/hide pro models
    """
    print(f"\n[MODELS AVAILABLE] Checking available models for user...")

    license_check_result = await check_license(license_key)

    # Extract JSON from JSONResponse if needed
    if isinstance(license_check_result, JSONResponse):
        import json
        license_data = json.loads(license_check_result.body.decode())
    else:
        license_data = license_check_result

    tier = license_data.get("tier", "free")
    models = license_data.get("models", FREE_MODELS)

    print(f"[MODELS AVAILABLE] Tier: {tier}, Models: {len(models)}")

    return JSONResponse({
        "tier": tier,
        "models": models,
        "total": len(models)
    })

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
