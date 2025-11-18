# Gemini 3 Pro - Complete Documentation

## Quick Start

```python
from google import genai
from google.genai import types

client = genai.Client(api_key='YOUR_API_KEY')

response = client.models.generate_content(
    model="gemini-3-pro-preview",
    contents="Find the race condition in this multi-threaded C++ snippet: [code here]",
)

print(response.text)
```

```javascript
import { GoogleGenAI } from "@google/genai";

const ai = new GoogleGenAI({});

async function run() {
  const response = await ai.models.generateContent({
    model: "gemini-3-pro-preview",
    contents="Find the race condition in this multi-threaded C++ snippet: [code here]",
  });

  console.log(response.text);
}

run();
```

```bash
curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-preview:generateContent" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H 'Content-Type: application/json' \
  -X POST \
  -d '{
    "contents": [{
      "parts": [{"text": "Find the race condition in this multi-threaded C++ snippet: [code here]"}]
    }]
  }'
```

## Thinking Level

The `thinking_level` parameter controls the maximum depth of the model's internal reasoning process before it produces a response. Gemini 3 treats these levels as relative allowances for thinking rather than strict token guarantees. If `thinking_level` is not specified, Gemini 3 Pro will default to **high**.

- **low**: Minimizes latency and cost. Best for simple instruction following, chat, or high-throughput applications
- **medium**: (Coming soon), not supported at launch
- **high** (Default): Maximizes reasoning depth. The model may take significantly longer to reach a first token, but the output will be more carefully reasoned.

**Warning**: You cannot use both `thinking_level` and the legacy `thinking_budget` parameter in the same request. Doing so will return a 400 error.

## Media Resolution

Gemini 3 introduces granular control over multimodal vision processing via the `media_resolution` parameter. Higher resolutions improve the model's ability to read fine text or identify small details, but increase token usage and latency.

### Recommended Settings

| Media Type | Recommended Setting | Max Tokens | Usage Guidance |
|------------|---------------------|------------|----------------|
| Images | media_resolution_high | 1120 | Recommended for most image analysis tasks to ensure maximum quality. |
| PDFs | media_resolution_medium | 560 | Optimal for document understanding; quality typically saturates at medium. |
| Video (General) | media_resolution_low | 70 (per frame) | Sufficient for most action recognition and description tasks. |
| Video (Text-heavy) | media_resolution_high | 280 (per frame) | Required for reading dense text (OCR) or small details within video frames. |

```bash
curl "https://generativelanguage.googleapis.com/v1alpha/models/gemini-3-pro-preview:generateContent" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H 'Content-Type: application/json' \
  -X POST \
  -d '{
    "contents": [{
      "parts": [
        { "text": "What is in this image?" },
        {
          "inlineData": {
            "mimeType": "image/jpeg",
            "data": "..."
          },
          "mediaResolution": {
            "level": "media_resolution_high"
          }
        }
      ]
    }]
  }'
```

## Temperature

For Gemini 3, we **strongly recommend keeping the temperature parameter at its default value of 1.0**.

While previous models often benefited from tuning temperature to control creativity versus determinism, Gemini 3's reasoning capabilities are optimized for the default setting. Changing the temperature (setting it below 1.0) may lead to unexpected behavior, such as looping or degraded performance.

## Thought Signatures

Gemini 3 uses **Thought signatures** to maintain reasoning context across API calls. These signatures are encrypted representations of the model's internal thought process.

- **Function Calling (Strict)**: The API enforces strict validation on the "Current Turn". Missing signatures will result in a 400 error.
- **Text/Chat**: Validation is not strictly enforced, but omitting signatures will degrade the model's reasoning and answer quality.

**Success**: If you use the official SDKs (Python, Node, Java) and standard chat history, Thought Signatures are handled automatically.

### Migrating from Other Models

If you are transferring a conversation from another model or injecting a custom function call, use this dummy string to bypass validation:

```json
"thoughtSignature": "context_engineering_is_the_way_to_go"
```

## Structured Outputs with Tools

Gemini 3 allows you to combine Structured Outputs with built-in tools, including Grounding with Google Search, URL Context, and Code Execution.

```bash
curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-preview:generateContent" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H 'Content-Type: application/json' \
  -X POST \
  -d '{
    "contents": [{
      "parts": [{"text": "Search for all details for the latest Euro."}]
    }],
    "tools": [
      {"googleSearch": {}},
      {"urlContext": {}}
    ],
    "generationConfig": {
        "responseMimeType": "application/json",
        "responseJsonSchema": {
            "type": "object",
            "properties": {
                "winner": {"type": "string"},
                "final_match_score": {"type": "string"},
                "scorers": {
                    "type": "array",
                    "items": {"type": "string"}
                }
            },
            "required": ["winner", "final_match_score", "scorers"]
        }
    }
  }'
```

## Installation

```bash
pip install google-genai
```

## Python SDK - Complete Reference

### Create a Client

```python
from google import genai

# Gemini Developer API
client = genai.Client(api_key='GEMINI_API_KEY')

# OR using environment variable
# export GEMINI_API_KEY='your-api-key'
client = genai.Client()
```

### Generate Content

```python
response = client.models.generate_content(
    model='gemini-3-pro-preview',
    contents='Why is the sky blue?'
)
print(response.text)
```

### System Instructions and Configs

```python
from google.genai import types

response = client.models.generate_content(
    model='gemini-3-pro-preview',
    contents='high',
    config=types.GenerateContentConfig(
        system_instruction='I say high, you say low',
        max_output_tokens=3,
        temperature=1.0,  # Keep at default 1.0
        thinking_level='high',  # low, high
    ),
)
```

### Safety Settings

```python
response = client.models.generate_content(
    model='gemini-3-pro-preview',
    contents='Say something bad.',
    config=types.GenerateContentConfig(
        safety_settings=[
            types.SafetySetting(
                category='HARM_CATEGORY_HATE_SPEECH',
                threshold='BLOCK_ONLY_HIGH',
            )
        ]
    ),
)
```

### Function Calling (Automatic)

```python
from google.genai import types

def get_current_weather(location: str) -> str:
    """Returns the current weather.

    Args:
        location: The city and state, e.g. San Francisco, CA
    """
    return 'sunny'

response = client.models.generate_content(
    model='gemini-3-pro-preview',
    contents='What is the weather like in Boston?',
    config=types.GenerateContentConfig(
        tools=[get_current_weather],
    ),
)

print(response.text)
```

### JSON Response Schema

```python
from pydantic import BaseModel
from google.genai import types

class CountryInfo(BaseModel):
    name: str
    population: int
    capital: str
    continent: str
    gdp: int
    official_language: str
    total_area_sq_mi: int

response = client.models.generate_content(
    model='gemini-3-pro-preview',
    contents='Give me information for the United States.',
    config=types.GenerateContentConfig(
        response_mime_type='application/json',
        response_schema=CountryInfo,
    ),
)
print(response.text)
```

### Streaming

```python
for chunk in client.models.generate_content_stream(
    model='gemini-3-pro-preview',
    contents='Tell me a story in 300 words.'
):
    print(chunk.text, end='')
```

### Async Support

```python
# Async non-streaming
response = await client.aio.models.generate_content(
    model='gemini-3-pro-preview',
    contents='Tell me a story in 300 words.'
)

# Async streaming
async for chunk in await client.aio.models.generate_content_stream(
    model='gemini-3-pro-preview',
    contents='Tell me a story in 300 words.'
):
    print(chunk.text, end='')
```

### Chat Sessions

```python
chat = client.chats.create(model='gemini-3-pro-preview')
response = chat.send_message('tell me a story')
print(response.text)
response = chat.send_message('summarize the story')
print(response.text)
```

### Count Tokens

```python
response = client.models.count_tokens(
    model='gemini-3-pro-preview',
    contents='why is the sky blue?',
)
print(response)
```

### Local Tokenizer

```python
tokenizer = genai.LocalTokenizer(model_name='gemini-3-pro-preview')
result = tokenizer.count_tokens("What is your name?")
```

## Migrating from Gemini 2.5

1. **Thinking**: Use `thinking_level: "high"` with simplified prompts instead of complex Chain-of-thought
2. **Temperature**: Remove explicit temperature settings, use default 1.0
3. **PDF Resolution**: Default OCR resolution changed, test `media_resolution_high` for dense documents
4. **Token Consumption**: May increase for PDFs, decrease for video
5. **Image Segmentation**: Not supported in Gemini 3 Pro (use Gemini 2.5 Flash)

## Prompting Best Practices

1. **Precise Instructions**: Be concise and direct. Gemini 3 responds best to clear instructions.
2. **Output Verbosity**: By default less verbose. Explicitly request conversational style if needed.
3. **Context Management**: Place instructions/questions at the END after providing data context.
4. **Anchor Questions**: Start with "Based on the information above..." for large datasets.

## FAQ

- **Knowledge Cutoff**: January 2025 (use Search Grounding for recent info)
- **Context Window**: 1 million tokens input, 64k tokens output
- **Free Tier**: Available in AI Studio, not in Gemini API
- **Batch API**: Supported
- **Context Caching**: Supported (minimum 2,048 tokens)
- **Supported Tools**: Google Search, File Search, Code Execution, URL Context, Function Calling

## Error Handling

```python
from google.genai import errors

try:
    client.models.generate_content(
        model="invalid-model-name",
        contents="What is your name?",
    )
except errors.APIError as e:
    print(e.code)  # 404
    print(e.message)
```

## Environment Variables

```bash
# Gemini Developer API
export GEMINI_API_KEY='your-api-key'
# OR
export GOOGLE_API_KEY='your-api-key'

# Vertex AI (alternative)
export GOOGLE_GENAI_USE_VERTEXAI=true
export GOOGLE_CLOUD_PROJECT='your-project-id'
export GOOGLE_CLOUD_LOCATION='us-central1'
```

## API Versions

```python
from google.genai import types

# Use v1 (stable)
client = genai.Client(
    api_key='YOUR_KEY',
    http_options=types.HttpOptions(api_version='v1')
)

# Use v1alpha (preview features)
client = genai.Client(
    api_key='YOUR_KEY',
    http_options=types.HttpOptions(api_version='v1alpha')
)
```

## Model Context Protocol (MCP) Support (Experimental)

```python
import asyncio
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client
from google import genai

client = genai.Client()

server_params = StdioServerParameters(
    command="npx",
    args=["-y", "@philschmid/weather-mcp"],
)

async def run():
    async with stdio_client(server_params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()

            response = await client.aio.models.generate_content(
                model="gemini-3-pro-preview",
                contents="What is the weather in London?",
                config=genai.types.GenerateContentConfig(
                    temperature=0,
                    tools=[session],
                ),
            )
            print(response.text)

asyncio.run(run())
```

## Advanced Features

### Files (Gemini Developer API only)

```python
# Upload
file = client.files.upload(file='document.pdf')

# Use in generation
response = client.models.generate_content(
    model='gemini-3-pro-preview',
    contents=['Summarize this file', file]
)

# Delete
client.files.delete(name=file.name)
```

### Context Caching

```python
from google.genai import types

cached_content = client.caches.create(
    model='gemini-3-pro-preview',
    config=types.CreateCachedContentConfig(
        contents=[...],
        system_instruction='What is the sum of the two pdfs?',
        ttl='3600s',
    ),
)

response = client.models.generate_content(
    model='gemini-3-pro-preview',
    contents='Summarize the pdfs',
    config=types.GenerateContentConfig(
        cached_content=cached_content.name,
    ),
)
```

### Batch Prediction

```python
# Create batch job
job = client.batches.create(
    model='gemini-3-pro-preview',
    src='bq://my-project.my-dataset.my-table',
)

# Poll until complete
import time
while job.state not in ['JOB_STATE_SUCCEEDED', 'JOB_STATE_FAILED']:
    job = client.batches.get(name=job.name)
    time.sleep(30)
```

## Resources

- Documentation: https://googleapis.github.io/python-genai/
- GitHub: https://github.com/googleapis/python-genai
- Cookbook: Check dedicated guide on thinking levels
- Vertex AI API: https://cloud.google.com/vertex-ai/docs/reference/rest
- Gemini API: https://ai.google.dev/api/rest
