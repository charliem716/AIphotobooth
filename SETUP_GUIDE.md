# AI Photo Booth - Quick Setup Guide

## 🚀 Quick Start

### 1. Add Your API Credentials

```bash
cp env.example .env
```

Edit `.env` and add your credentials:
- **OpenAI API Key**: Get from [platform.openai.com](https://platform.openai.com/api-keys)
- **Twilio Credentials**: Get from [console.twilio.com](https://console.twilio.com/)

### 2. Launch the App

```bash
./launch.sh
```

### 3. Connect Your iPhone

1. Mount iPhone on tripod
2. Enable Continuity Camera in iPhone Settings
3. The app should auto-detect your iPhone

### 4. Start Taking Photos!

1. Guest selects a cartoon theme
2. Enters phone number
3. Clicks "Take Photo"
4. 3-2-1... Snap! 📸
5. AI transforms the photo
6. Guest receives it via SMS

## 📺 Cartoon Themes

Your custom themes are ready:
- 🍃 **Studio Ghibli** - Magical anime transformation
- 🏠 **Simpsons** - Springfield's finest
- 🚀 **Rick and Morty** - Multiverse madness
- 🔥 **Dragon Ball Z** - Power level over 9000!
- 🔍 **Scooby Doo** - Mystery gang style
- 💧 **SpongeBob** - Bikini Bottom ready
- ❄️ **South Park** - Colorado cut-out style
- 🌙 **Batman TAS** - Dark deco nights
- 🔨 **Flintstones** - Stone age spectacular

## 🛠️ Utilities

### Clean Photo Cache
```bash
# Remove photos older than 7 days
./Scripts/cleanup_cache.swift

# Remove photos older than 3 days
./Scripts/cleanup_cache.swift 3
```

### External Display Setup
1. Connect HDMI projector
2. Go to Settings in the app
3. Select the projector screen
4. Guests will see the magical fade reveal!

## 🆘 Troubleshooting

### iPhone Not Detected
- Unlock your iPhone
- Check both devices are on same Wi-Fi
- Click the refresh button (↻) in the app
- Restart both devices if needed

### SMS Not Sending
- Verify Twilio credentials in .env
- Check phone number format (+1 for US)
- Ensure Twilio account has credits

### Build Issues
```bash
# Clean and rebuild
rm -rf .build
swift build
```

## 📝 Notes

- Photos are saved to `~/Pictures/booth/`
- Cache auto-cleans after 7 days (configurable)
- For production, use a backend service for API calls
- Keep your .env file secure and never commit it

## 🎉 Ready to Party!

Your AI Photo Booth is ready for events. Have fun transforming guests into their favorite cartoon characters!

Need help? Check the full README.md for detailed documentation. 