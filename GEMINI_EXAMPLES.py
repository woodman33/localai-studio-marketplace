"""
Gemini 3 Pro - Example Usage
Quick reference for using Gemini 3 Pro in your projects
"""

from gemini_helper import GeminiHelper, quick_ask
from google.genai import types
from pydantic import BaseModel

# ============================================================
# 1. QUICK ONE-OFF QUESTIONS
# ============================================================

# Simplest way - just ask a question
answer = quick_ask("What is the capital of France?")
print(answer)


# ============================================================
# 2. BASIC USAGE WITH HELPER
# ============================================================

helper = GeminiHelper()

# Simple generation
response = helper.generate(
    "Explain quantum computing in simple terms",
    thinking_level='high'  # 'low' or 'high'
)
print(response)


# ============================================================
# 3. STREAMING RESPONSES
# ============================================================

print("Streaming response:")
for chunk in helper.stream("Tell me a story about AI"):
    print(chunk, end='', flush=True)
print()


# ============================================================
# 4. CHAT SESSIONS (MULTI-TURN)
# ============================================================

chat = helper.chat()

# First message
response1 = chat.send_message("What is Python?")
print("Bot:", response1.text)

# Follow-up (remembers context)
response2 = chat.send_message("What are its main features?")
print("Bot:", response2.text)


# ============================================================
# 5. STRUCTURED OUTPUT (JSON SCHEMA)
# ============================================================

class MovieReview(BaseModel):
    title: str
    rating: int  # 1-10
    pros: list[str]
    cons: list[str]
    recommendation: str

json_response = helper.generate_with_schema(
    "Review the movie Inception",
    schema=MovieReview
)
print(json_response)


# ============================================================
# 6. FUNCTION CALLING (AUTOMATIC)
# ============================================================

def get_weather(location: str) -> str:
    """Get current weather for a location.

    Args:
        location: City name, e.g. 'Boston'
    """
    return f"The weather in {location} is sunny, 72°F"

def calculate(expression: str) -> float:
    """Calculate a mathematical expression.

    Args:
        expression: Math expression like "2 + 2"
    """
    return eval(expression)

# Gemini will automatically call functions as needed
response = helper.function_call(
    "What's the weather in Boston and what's 123 * 456?",
    functions=[get_weather, calculate]
)
print(response)


# ============================================================
# 7. SYSTEM INSTRUCTIONS
# ============================================================

helper_custom = GeminiHelper()
response = helper_custom.generate(
    prompt="Write me a poem",
    system_instruction="You are a Shakespearean poet. Always respond in iambic pentameter.",
    max_tokens=200
)
print(response)


# ============================================================
# 8. TOKEN COUNTING
# ============================================================

token_info = helper.count_tokens("How many tokens is this text?")
print(f"Total tokens: {token_info.total_tokens}")


# ============================================================
# 9. ADVANCED: DIRECT CLIENT ACCESS
# ============================================================

# If you need more control, access the client directly
from google.genai import types

response = helper.client.models.generate_content(
    model='gemini-3-pro-preview',
    contents='Explain machine learning',
    config=types.GenerateContentConfig(
        thinking_level='high',
        temperature=1.0,
        max_output_tokens=500,
        safety_settings=[
            types.SafetySetting(
                category='HARM_CATEGORY_HATE_SPEECH',
                threshold='BLOCK_ONLY_HIGH',
            )
        ]
    ),
)
print(response.text)


# ============================================================
# 10. ASYNC USAGE
# ============================================================

import asyncio

async def async_example():
    helper = GeminiHelper()

    # Async generation
    response = await helper.client.aio.models.generate_content(
        model='gemini-3-pro-preview',
        contents='Hello from async!'
    )
    print(response.text)

    # Async streaming
    async for chunk in await helper.client.aio.models.generate_content_stream(
        model='gemini-3-pro-preview',
        contents='Stream this async'
    ):
        print(chunk.text, end='', flush=True)

# Run async function
# asyncio.run(async_example())


# ============================================================
# 11. IMAGE ANALYSIS (with local files)
# ============================================================

from google.genai import types

# If you have an image file
# with open('image.jpg', 'rb') as f:
#     image_bytes = f.read()
#
# response = helper.client.models.generate_content(
#     model='gemini-3-pro-preview',
#     contents=[
#         'What is in this image?',
#         types.Part.from_bytes(data=image_bytes, mime_type='image/jpeg')
#     ]
# )
# print(response.text)


# ============================================================
# 12. CODE ANALYSIS
# ============================================================

code_to_analyze = """
def factorial(n):
    if n == 0:
        return 1
    return n * factorial(n-1)
"""

response = helper.generate(
    f"Analyze this code for bugs and improvements:\n\n{code_to_analyze}",
    thinking_level='high'
)
print(response)


# ============================================================
# 13. MULTI-TURN REASONING
# ============================================================

# Gemini 3 excels at complex reasoning
response = helper.generate(
    """
    I have 3 boxes:
    - Box A contains 2 red balls and 3 blue balls
    - Box B contains 1 red ball and 4 blue balls
    - Box C contains 3 red balls and 1 blue ball

    If I randomly pick a box and then randomly pick a ball from it,
    what's the probability the ball is red?
    """,
    thinking_level='high',
    max_tokens=1000
)
print(response)


# ============================================================
# NOTES
# ============================================================

"""
Best Practices:
1. Keep temperature at 1.0 (default) for Gemini 3
2. Use thinking_level='high' for complex reasoning tasks
3. Use thinking_level='low' for simple chat/instructions
4. Place questions AFTER context (not before) for large datasets
5. Be concise - Gemini 3 prefers direct instructions

For more examples, see:
- GEMINI_3_PRO_DOCS.md
- https://googleapis.github.io/python-genai/
"""
