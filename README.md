# AI Photo Booth for Mac

A modern photo booth application for macOS that uses AI to transform photos into themed artwork. Built with SwiftUI, it leverages Continuity Camera for capture, OpenAI for image generation, and Twilio for SMS delivery.

## Features

- 📸 **Continuity Camera Support**: Use your iPhone as a wireless camera
- 🎨 **9 AI Themes**: Transform photos into various artistic styles
- 📱 **MMS Delivery**: Automatically send actual themed photos via MMS
- 🖥️ **Dual Display**: Show fade reveal on external projector
- ⚡ **Fast Processing**: < 15 second experience per guest
- 💾 **Smart Caching**: Automatic cleanup of old photos

## Requirements

- **macOS Sonoma 14.0 or later** (required for Continuity Camera)
- iPhone with iOS 16+ (for Continuity Camera)
- OpenAI API key
- Twilio account (for MMS)
- Swift 5.9+

## Quick Start

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd PhotoBooth
   ```

2. **Set up environment variables**
   ```bash
   cp env.example .env
   # Edit .env with your actual API keys
   ```

3. **Configure your .env file**
   ```
   OPENAI_KEY=sk-your-openai-api-key-here
   TWILIO_SID=ACyour-twilio-account-sid
   TWILIO_TOKEN=your-twilio-auth-token
   TWILIO_FROM=+1your-twilio-phone-number
   ```

4. **Build and run**
   ```bash
   ./launch.sh
   ```

   Or manually:
   ```bash
   swift build
   swift run PhotoBooth
   ```

   Or open `Package.swift` in Xcode and run from there.

## Setup Guide

### Continuity Camera Setup

1. Ensure your iPhone and Mac are on the same Wi-Fi network
2. Sign in with the same Apple ID on both devices
3. Enable Bluetooth on both devices
4. On iPhone: Settings → General → AirPlay & Handoff → Continuity Camera (ON)
5. Mount your iPhone on a tripod
6. The app will automatically detect it as an external camera

### OpenAI Setup

1. Create an account at [platform.openai.com](https://platform.openai.com)
2. Generate an API key
3. Add credit to your account (DALL-E costs ~$0.05 per image)

### Twilio Setup

1. Create an account at [twilio.com](https://www.twilio.com)
2. Get a phone number with MMS capabilities (US/Canada recommended)
3. Find your Account SID and Auth Token in the console
4. Add these credentials to your .env file

## Usage

1. **Launch the app** - The main window will appear
2. **Connect iPhone** - Should auto-detect via Continuity Camera
3. **Guest interaction**:
   - Select a theme from the 9 options
   - Enter phone number
   - Click "Take Photo"
   - 3-2-1 countdown begins
   - Photo is captured and processed
   - Themed image is sent via MMS
4. **External display** (optional) - Connect projector to see fade reveals

## Themes Available

1. **Studio Ghibli** - Transform into the magical anime style of Spirited Away and Totoro
2. **Simpsons** - Get Simpsonized with yellow skin and Springfield art style
3. **Rick and Morty** - Enter the multiverse with sci-fi cartoon transformation
4. **Dragon Ball Z** - Power up with spiky hair and intense anime action
5. **Scooby Doo** - Join the Mystery Gang with classic 70s cartoon vibes
6. **SpongeBob** - Dive into Bikini Bottom with underwater cartoon fun
7. **South Park** - Get the cut-out animation look from Colorado
8. **Batman TAS** - Dark deco style from the acclaimed animated series
9. **Flintstones** - Yabba dabba doo! Travel to the stone age

## Architecture

```
PhotoBooth/
├── Sources/PhotoBooth/
│   ├── PhotoBoothApp.swift      # Main app entry
│   ├── ViewModels/              # Business logic
│   ├── Views/                   # SwiftUI views
│   ├── Services/                # API integrations
│   └── Resources/               # Assets & Info.plist
├── Package.swift                # Dependencies
└── .env                        # API credentials
```

## Development Timeline

Following the 5-day MVP plan:
- **Day 0**: Project setup ✅
- **Day 1**: Camera integration
- **Day 2**: UI and countdown
- **Day 3**: AI and SMS integration
- **Day 4**: External display
- **Day 5**: Polish and testing

## Troubleshooting

### Camera not detected
- Check iPhone is unlocked
- Verify Continuity Camera is enabled
- Try reconnecting (click refresh button)
- Restart both devices if needed

### API errors
- Verify credentials in .env file
- Check API quotas/credits
- Ensure internet connection

### MMS not sending
- Verify phone number format (+1 for US)
- Check Twilio account balance
- Ensure number is MMS-capable
- Check image upload service availability

## Security Notes

⚠️ **Important**: This MVP stores API credentials locally. For production:
- Use a backend service for API calls
- Implement proper authentication
- Never expose API keys in client apps

## Contributing

Feel free to submit issues and enhancement requests!

## License

MIT License - see LICENSE file for details 

## ✨ **GPT-4o Vision-Powered AI Image Generation**

The AI Photo Booth now uses **GPT-4o vision capabilities** to actually analyze captured photos before generating themed transformations. This creates much more accurate and personalized results.

### Current Implementation
- **GPT-4o Vision Analysis**: Actually analyzes the captured photo to understand people, poses, clothing, and setting
- **Intelligent Prompting**: Generates DALL-E prompts based on real photo analysis rather than generic templates
- **Fallback System**: Graceful fallback to enhanced static prompts if vision analysis fails
- **Retry Logic**: 3 attempts with exponential backoff for reliable generation
- **MMS Delivery**: Full-resolution images sent directly to phones

### How It Works
1. **Photo Capture**: iPhone via Continuity Camera captures the photo
2. **Vision Analysis**: GPT-4o analyzes the image for people, poses, clothing, expressions, and setting
3. **Smart Prompt Generation**: Creates a DALL-E prompt that preserves the actual scene composition
4. **Style Transformation**: DALL-E generates the themed artwork based on the real photo analysis
5. **MMS Delivery**: Users receive the personalized AI-generated photo

### Benefits
- **Accurate People Count**: Preserves the exact number of people in the photo
- **Pose Preservation**: Maintains the actual poses and positioning from the original
- **Clothing Recognition**: Considers actual clothing colors and styles in the transformation
- **Composition Integrity**: Keeps the original photo booth composition and framing
- **Personalized Results**: Each transformation is unique to the actual captured photo 