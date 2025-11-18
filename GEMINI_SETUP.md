# Gemini 3 Pro Setup Guide

## Quick Start

### 1. Get Your API Key

Get a free API key from Google AI Studio:
https://aistudio.google.com/apikey

### 2. Add API Key to .env

Open `.env` and add your key:
```bash
GEMINI_API_KEY=your_actual_api_key_here
```

### 3. Install Dependencies

```bash
pip install google-genai python-dotenv
```

### 4. Test It!

```bash
# Quick test from command line
python gemini_helper.py "What is the capital of France?"

# Or use in Python
python GEMINI_EXAMPLES.py
```

## Files Created

1. **GEMINI_3_PRO_DOCS.md** - Complete API documentation
2. **gemini_helper.py** - Python helper class for easy usage
3. **GEMINI_EXAMPLES.py** - 13 example use cases
4. **.env** - Your API key storage (updated)

## Basic Usage

### Command Line

```bash
python gemini_helper.py "Your question here"
```

### Python Script

```python
from gemini_helper import quick_ask

answer = quick_ask("Explain quantum computing")
print(answer)
```

### Advanced Usage

```python
from gemini_helper import GeminiHelper

helper = GeminiHelper()

# Simple generation
response = helper.generate(
    "Write a story about AI",
    thinking_level='high',  # or 'low'
    max_tokens=500
)

# Streaming
for chunk in helper.stream("Tell me a joke"):
    print(chunk, end='', flush=True)

# Chat sessions
chat = helper.chat()
response1 = chat.send_message("Hello!")
response2 = chat.send_message("How are you?")

# Function calling
def get_weather(location: str) -> str:
    """Get weather for a location"""
    return f"Sunny in {location}"

response = helper.function_call(
    "What's the weather in Boston?",
    functions=[get_weather]
)

# Structured output
from pydantic import BaseModel

class Person(BaseModel):
    name: str
    age: int
    city: str

json_response = helper.generate_with_schema(
    "Give me a random person",
    schema=Person
)
```

## Key Features

### Thinking Levels

Gemini 3 Pro supports two thinking levels:

- **high** (default): Deep reasoning, slower but more accurate
- **low**: Fast responses, good for simple tasks

```python
# For complex reasoning
helper.generate("Solve this logic puzzle...", thinking_level='high')

# For simple chat
helper.generate("Say hello", thinking_level='low')
```

### Temperature

**Always use temperature=1.0** (the default). Gemini 3 is optimized for this setting.

Lowering temperature may cause:
- Looping behavior
- Degraded reasoning
- Unexpected output

### Token Limits

- **Input**: 1 million tokens
- **Output**: 64k tokens
- **Knowledge cutoff**: January 2025

### Supported Features

✅ Text generation
✅ Streaming
✅ Chat sessions
✅ Function calling (automatic)
✅ Structured JSON output
✅ Image analysis
✅ PDF analysis
✅ Context caching
✅ Batch processing
✅ Async support

❌ Image segmentation (use Gemini 2.5)
❌ Video analysis (coming soon)

## Examples

See `GEMINI_EXAMPLES.py` for 13 complete examples:

1. Quick one-off questions
2. Basic usage
3. Streaming responses
4. Chat sessions (multi-turn)
5. Structured output (JSON)
6. Function calling
7. System instructions
8. Token counting
9. Direct client access
10. Async usage
11. Image analysis
12. Code analysis
13. Multi-turn reasoning

## Troubleshooting

### "No API key found"

Make sure you:
1. Added `GEMINI_API_KEY=your_key` to `.env`
2. The `.env` file is in the same directory as your script
3. Your API key is valid

### Import Errors

```bash
pip install google-genai python-dotenv pydantic
```

### Rate Limits

Free tier limits:
- 15 requests per minute
- 1 million tokens per minute
- 1,500 requests per day

For higher limits, upgrade at:
https://ai.google.dev/pricing

## Best Practices

1. **Be Concise**: Gemini 3 prefers direct, clear instructions
2. **Context Last**: Put questions AFTER providing context
3. **Use High Thinking**: For complex reasoning, use `thinking_level='high'`
4. **Default Temperature**: Keep at 1.0
5. **Anchor Questions**: Start with "Based on the information above..."

## API Costs

Gemini 3 Pro pricing (as of Jan 2025):
- Free tier available
- Paid tier: Check https://ai.google.dev/pricing

## Resources

- **Full Docs**: GEMINI_3_PRO_DOCS.md
- **Examples**: GEMINI_EXAMPLES.py
- **Helper**: gemini_helper.py
- **Google Docs**: https://googleapis.github.io/python-genai/
- **GitHub**: https://github.com/googleapis/python-genai
- **Get API Key**: https://aistudio.google.com/apikey

## Integration with Claude Code

To use Gemini 3 Pro in Claude Code conversations:

```python
from gemini_helper import GeminiHelper

# Ask Gemini a question
helper = GeminiHelper()
gemini_answer = helper.generate("Your question here")

# Use the answer in your Claude Code workflow
print(f"Gemini says: {gemini_answer}")
```

You can also create a custom agent or skill that wraps the Gemini helper for specialized tasks.

## Next Steps

1. Add your API key to `.env`
2. Run `python GEMINI_EXAMPLES.py` to test
3. Check `GEMINI_3_PRO_DOCS.md` for complete API reference
4. Integrate into your workflows!
