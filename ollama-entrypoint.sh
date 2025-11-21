#!/bin/bash
# Ollama entrypoint script - Pre-pull TinyLlama for instant gratification

echo "🚀 Starting Ollama..."
# Start Ollama in background
/bin/ollama serve &
OLLAMA_PID=$!

# Wait for Ollama to be ready
echo "⏳ Waiting for Ollama to start..."
for i in {1..30}; do
    if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo "✅ Ollama is ready!"
        break
    fi
    sleep 1
done

# Pull TinyLlama automatically (only ~637MB, fast!)
echo "📥 Pre-downloading TinyLlama for instant use..."
if ! ollama list | grep -q "tinyllama:latest"; then
    echo "   Pulling tinyllama:latest (this may take 1-2 minutes)..."
    ollama pull tinyllama:latest
    echo "✅ TinyLlama ready! Users can chat immediately."
else
    echo "✅ TinyLlama already installed."
fi

# Keep Ollama running in foreground
wait $OLLAMA_PID
