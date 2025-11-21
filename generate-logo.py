#!/usr/bin/env python3
"""
Generate Local AI Studio Logo using FAL AI
Creates multiple logo variations for Product Hunt submission
"""

import os
import requests
import json
from pathlib import Path

# Check for API key
ZAI_API_KEY = os.getenv('ZAI_API_KEY', '')

# Logo prompts - 4 different styles
LOGO_PROMPTS = {
    "minimal_tech": """
    A minimal, modern logo for 'Local AI Studio'.
    Features: Abstract geometric AI brain icon made of connected nodes and circuits.
    Style: Clean, minimal, flat design with gradient from cyan (#06B6D4) to indigo (#6366F1).
    Background: Transparent or white.
    Icon-only, no text, 512x512px, professional tech startup aesthetic.
    """,

    "glassmorphism": """
    A glassmorphism-style logo for 'Local AI Studio'.
    Features: Frosted glass effect with neural network pattern, glowing edges.
    Colors: Dark background with cyan and purple gradients, light refraction effects.
    Style: Modern, premium, 3D glass material with depth.
    512x512px, suitable for dark UI backgrounds.
    """,

    "geometric_abstract": """
    A geometric abstract logo representing local AI computing.
    Features: Cube or hexagon with circuit patterns inside, representing 'local' and 'contained'.
    Colors: Gradient from cyan to indigo with gold accents.
    Style: Sharp, clean lines, isometric perspective, modern tech.
    512x512px, icon-style, minimal text.
    """,

    "brain_circuit": """
    A stylized AI brain logo made of circuit board traces and neural connections.
    Features: Half brain, half circuit board design showing AI + local computing.
    Colors: Cyan (#06B6D4) and indigo (#6366F1) with glowing connection points.
    Style: Modern, techy, slightly futuristic but professional.
    512x512px, icon-only, suitable for app icons.
    """
}

OUTPUT_DIR = Path(__file__).parent / "logos"
OUTPUT_DIR.mkdir(exist_ok=True)

def generate_logo_with_zai(prompt: str, filename: str):
    """Generate logo using Z.AI Flux Pro model"""

    print(f"🎨 Generating: {filename}...")

    url = "https://api.z.ai/v1/images/generations"

    headers = {
        "Authorization": f"Bearer {ZAI_API_KEY}",
        "Content-Type": "application/json"
    }

    payload = {
        "model": "flux-pro",  # High quality model
        "prompt": prompt,
        "size": "1024x1024",  # High res
        "n": 1,
        "response_format": "url"
    }

    try:
        response = requests.post(url, headers=headers, json=payload, timeout=60)
        response.raise_for_status()

        data = response.json()
        image_url = data['data'][0]['url']

        # Download the image
        img_response = requests.get(image_url, timeout=30)
        img_response.raise_for_status()

        output_path = OUTPUT_DIR / filename
        with open(output_path, 'wb') as f:
            f.write(img_response.content)

        print(f"   ✓ Saved: {filename} ({len(img_response.content) // 1024} KB)")
        return True

    except Exception as e:
        print(f"   ✗ Error: {e}")
        return False

def main():
    print("🚀 Generating Local AI Studio Logos...\n")

    if not ZAI_API_KEY or ZAI_API_KEY == 'your_api_key_here':
        print("❌ Error: ZAI_API_KEY not found in environment")
        print("Set it with: export ZAI_API_KEY='your-key-here'")
        return

    print(f"Using Z.AI API key: {ZAI_API_KEY[:20]}...\n")

    # Generate all logo variations
    for style_name, prompt in LOGO_PROMPTS.items():
        filename = f"logo-{style_name}.png"
        generate_logo_with_zai(prompt, filename)
        print()

    print("═" * 60)
    print("✅ Logo generation complete!")
    print("═" * 60)
    print(f"\n📁 Logos saved to: {OUTPUT_DIR}")
    print("\nGenerated files:")
    for logo_file in OUTPUT_DIR.glob("logo-*.png"):
        size_kb = logo_file.stat().st_size // 1024
        print(f"  • {logo_file.name} ({size_kb} KB)")

    print("\n🎯 Ready for Product Hunt submission!")
    print("\nRecommendation: Use 'logo-minimal_tech.png' for:")
    print("  • Product Hunt thumbnail")
    print("  • Website favicon")
    print("  • Social media profile")
    print("\nAlternatives available for different contexts.\n")

if __name__ == "__main__":
    main()
