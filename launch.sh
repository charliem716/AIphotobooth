#!/bin/bash

# Check if .env file exists
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found!"
    echo ""
    echo "Please create a .env file with your API credentials:"
    echo "1. Copy env.example to .env"
    echo "   cp env.example .env"
    echo ""
    echo "2. Edit .env and add your credentials:"
    echo "   - OpenAI API key"
    echo "   - Twilio Account SID"
    echo "   - Twilio Auth Token"
    echo "   - Twilio Phone Number"
    echo ""
    exit 1
fi

# Check if build is needed
if [ ! -d .build ]; then
    echo "🔨 Building PhotoBooth for the first time..."
    swift build
fi

# Run the app
echo "🎬 Launching AI Photo Booth..."
swift run PhotoBooth 