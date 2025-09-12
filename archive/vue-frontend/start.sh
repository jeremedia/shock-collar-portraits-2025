#!/bin/bash

echo "🎭 Starting OKNOTOK Shock Collar Portraits Gallery"
echo "================================================"
echo ""

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
  echo "📦 Installing dependencies..."
  npm install
fi

# Create cache directory if it doesn't exist
mkdir -p server/cache

echo "🚀 Starting servers..."
echo ""

# Start both servers
npm run dev:full &

sleep 3

echo ""
echo "✨ Gallery is ready!"
echo ""
echo "📱 Access on this Mac:"
echo "   http://localhost:5173"
echo ""
echo "📱 Access on iPad via Tailscale:"
echo "   1. Make sure Tailscale is running on both devices"
echo "   2. Get this Mac's Tailscale IP:"
tailscale ip -4 2>/dev/null || echo "   [Install/start Tailscale to see IP]"
echo "   3. On your iPad, visit: http://[tailscale-ip]:5173"
echo ""
echo "Press Ctrl+C to stop the servers"

# Wait for interrupt
wait