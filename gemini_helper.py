#!/usr/bin/env python3
"""
Gemini 3 Pro Helper Script
Quick access to Gemini 3 Pro API with your stored API key
"""

import os
from google import genai
from google.genai import types
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

class GeminiHelper:
    """Helper class for Gemini 3 Pro interactions"""

    def __init__(self, api_key=None):
        """
        Initialize Gemini client

        Args:
            api_key: Optional API key. If not provided, will use GEMINI_API_KEY env var
        """
        self.api_key = api_key or os.getenv('GEMINI_API_KEY') or os.getenv('GOOGLE_API_KEY')

        if not self.api_key:
            raise ValueError(
                "No API key found. Please set GEMINI_API_KEY environment variable "
                "or pass api_key parameter"
            )

        self.client = genai.Client(api_key=self.api_key)
        self.default_model = 'gemini-3-pro-preview'

    def generate(self, prompt, model=None, thinking_level='high', temperature=1.0,
                 max_tokens=None, system_instruction=None):
        """
        Generate content with Gemini 3 Pro

        Args:
            prompt: The prompt text
            model: Model to use (default: gemini-3-pro-preview)
            thinking_level: 'low' or 'high' (default: high)
            temperature: Temperature setting (default: 1.0 - recommended)
            max_tokens: Maximum output tokens
            system_instruction: System instruction for the model

        Returns:
            Response text
        """
        config = types.GenerateContentConfig(
            thinking_level=thinking_level,
            temperature=temperature,
        )

        if max_tokens:
            config.max_output_tokens = max_tokens

        if system_instruction:
            config.system_instruction = system_instruction

        response = self.client.models.generate_content(
            model=model or self.default_model,
            contents=prompt,
            config=config,
        )

        return response.text

    def stream(self, prompt, model=None, thinking_level='high'):
        """
        Stream content generation

        Args:
            prompt: The prompt text
            model: Model to use
            thinking_level: 'low' or 'high'

        Yields:
            Text chunks
        """
        config = types.GenerateContentConfig(
            thinking_level=thinking_level,
        )

        for chunk in self.client.models.generate_content_stream(
            model=model or self.default_model,
            contents=prompt,
            config=config,
        ):
            yield chunk.text

    def chat(self, model=None):
        """
        Create a chat session

        Args:
            model: Model to use

        Returns:
            Chat session object
        """
        return self.client.chats.create(model=model or self.default_model)

    def generate_with_schema(self, prompt, schema, model=None):
        """
        Generate structured output matching a Pydantic schema

        Args:
            prompt: The prompt text
            schema: Pydantic model class
            model: Model to use

        Returns:
            Response text (JSON)
        """
        response = self.client.models.generate_content(
            model=model or self.default_model,
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type='application/json',
                response_schema=schema,
            ),
        )

        return response.text

    def function_call(self, prompt, functions, model=None):
        """
        Generate with function calling

        Args:
            prompt: The prompt text
            functions: List of Python functions to use as tools
            model: Model to use

        Returns:
            Response text
        """
        response = self.client.models.generate_content(
            model=model or self.default_model,
            contents=prompt,
            config=types.GenerateContentConfig(
                tools=functions,
            ),
        )

        return response.text

    def count_tokens(self, text, model=None):
        """
        Count tokens in text

        Args:
            text: Text to count
            model: Model to use for counting

        Returns:
            Token count response
        """
        return self.client.models.count_tokens(
            model=model or self.default_model,
            contents=text,
        )


def quick_ask(prompt, thinking_level='high'):
    """
    Quick one-off question to Gemini 3 Pro

    Args:
        prompt: Your question or prompt
        thinking_level: 'low' or 'high'

    Returns:
        Response text
    """
    helper = GeminiHelper()
    return helper.generate(prompt, thinking_level=thinking_level)


def main():
    """Example usage"""
    import sys

    if len(sys.argv) < 2:
        print("Usage: python gemini_helper.py 'Your question here'")
        print("\nExample:")
        print("  python gemini_helper.py 'Explain quantum computing in simple terms'")
        return

    prompt = ' '.join(sys.argv[1:])

    try:
        helper = GeminiHelper()
        print(f"\n🤖 Gemini 3 Pro (thinking_level: high)\n")
        print("Response:")
        print("=" * 60)

        for chunk in helper.stream(prompt):
            print(chunk, end='', flush=True)

        print("\n" + "=" * 60)

    except Exception as e:
        print(f"❌ Error: {e}")
        print("\nMake sure GEMINI_API_KEY is set in your .env file")


if __name__ == '__main__':
    main()
