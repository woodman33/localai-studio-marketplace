# Accurate Model Storage Requirements for Local AI Studio

## Individual Model Sizes (Approximate)

### FREE TIER (3 models):
1. **TinyLlama 1.1B** - ~637 MB
2. **Llama 3.2 3B** - ~2.0 GB
3. **Gemma 2 2B** - ~1.6 GB

**Free Tier Total: ~4.2 GB**

### PRO TIER (8 models):
1. **Llama 3.1 8B** - ~4.7 GB
2. **Mistral 7B** - ~4.1 GB
3. **Gemma 2 9B** - ~5.4 GB
4. **Qwen 2.5 7B** - ~4.7 GB
5. **DeepSeek Coder V2 16B** - ~8.9 GB
6. **Llama 3.1 70B** - ~40 GB
7. **Phi 3.5** - ~2.2 GB
8. **Nous Hermes 3 8B** - ~4.7 GB

**Pro Tier Total: ~74.7 GB**

## Storage Summary

- **Minimum (1 model only):** ~637 MB (TinyLlama)
- **Free Tier (3 models):** ~4.2 GB
- **All 11 Models:** ~78.9 GB
- **Recommended Free Space:** 100 GB (allows for model updates and overhead)

## Detailed Requirements for Gumroad

### Storage Breakdown:
- **Docker Base Images:** ~2-3 GB
- **Ollama Runtime:** ~500 MB
- **Application Files:** ~100 MB
- **One Small Model (TinyLlama):** ~637 MB
- **One Medium Model (Llama 3.2 3B):** ~2 GB
- **One Large Model (Llama 3.1 70B):** ~40 GB
- **All 11 Models:** ~79 GB

### Minimum to Run:
- **4 GB** - Docker + Ollama + TinyLlama (instant responses)

### Recommended:
- **10 GB** - Docker + 3-4 models (good variety)
- **25 GB** - Docker + 7-8 models (most models except 70B)
- **100 GB** - All 11 models + updates + breathing room

## RAM Requirements by Model

- **TinyLlama 1.1B:** 2 GB RAM
- **Llama 3.2 3B:** 4 GB RAM
- **Llama 3.1 8B:** 8 GB RAM
- **Mistral 7B:** 8 GB RAM
- **Gemma 2 9B:** 10 GB RAM
- **Qwen 2.5 7B:** 8 GB RAM
- **DeepSeek Coder V2 16B:** 16 GB RAM
- **Llama 3.1 70B:** 48 GB RAM (requires high-end hardware)
- **Phi 3.5:** 4 GB RAM
- **Nous Hermes 3 8B:** 8 GB RAM

## System Requirements (Detailed)

### Minimum Configuration:
- **CPU:** Dual-core with AVX2 support (Intel i5/Ryzen 5 or newer)
- **RAM:** 8 GB (can run 3-4 smaller models)
- **Storage:** 10 GB free space
- **OS:** macOS 10.15+, Windows 10/11, Ubuntu 20.04+
- **Docker:** Docker Desktop 4.x or Docker Engine 20.x

### Recommended Configuration:
- **CPU:** Quad-core or better (Intel i7/Ryzen 7, Apple M1/M2/M3)
- **RAM:** 16 GB (can run most models comfortably)
- **Storage:** 25-50 GB free space
- **GPU:** Optional, but improves performance significantly
- **OS:** Latest stable version

### Optimal Configuration:
- **CPU:** 8+ cores (Intel i9/Ryzen 9, Apple M2 Max/M3 Max)
- **RAM:** 32 GB or more
- **Storage:** 100 GB+ SSD
- **GPU:** NVIDIA RTX 3060+ (12GB VRAM) or Apple Silicon
- **OS:** Latest version with hardware acceleration

## Performance Expectations

### On 8GB RAM System:
- TinyLlama: **Instant responses** (50-100 tokens/sec)
- Llama 3.2 3B: **Fast** (20-40 tokens/sec)
- Llama 3.1 8B: **Moderate** (5-15 tokens/sec)
- Larger models: **Not recommended**

### On 16GB RAM System:
- All models up to 9B: **Good performance**
- DeepSeek 16B: **Usable** (3-8 tokens/sec)
- Llama 70B: **Not practical**

### On 32GB+ RAM with GPU:
- All models: **Excellent performance**
- Even Llama 70B: **Usable** (2-5 tokens/sec)

## Accurate Gumroad Details Section
