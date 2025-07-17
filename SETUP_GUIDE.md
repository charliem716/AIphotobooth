# AI Photo Booth - Quick Setup Guide

## 🚀 Quick Start

### 1. Add Your API Credentials

**🔒 Secure Keychain Storage (Recommended)**

The app will automatically prompt you to securely store credentials in macOS Keychain on first run:

1. Launch the app
2. Enter your OpenAI API key when prompted
3. Optionally add Twilio credentials for SMS
4. Credentials are encrypted and stored in macOS Keychain

**📄 Environment Variables (Alternative)**

```bash
cp env.example .env
```

Edit `.env` and add your credentials:
- **OpenAI API Key**: Get from [platform.openai.com](https://platform.openai.com/api-keys)
- **Twilio Credentials**: Get from [console.twilio.com](https://console.twilio.com/)

**🔄 Automatic Migration**

The app will automatically migrate credentials from `.env` to Keychain for improved security. This happens transparently on app startup.

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

## 🔐 Credential Management

### Viewing Stored Credentials

The app provides a configuration summary showing where credentials are stored:

```
Configuration Status:
• OpenAI: ✅ Configured
• Twilio: ✅ Configured

Credential Storage:
• OpenAI API Key: ✅ Stored in Keychain (length: 51)
• Twilio Account SID: ✅ Stored in Keychain (length: 34)
• Twilio Auth Token: ✅ Stored in Keychain (length: 32)
• Twilio From Number: ✅ Stored in Keychain (length: 12)
```

### Updating Credentials

1. **Via App Interface**: The app will provide prompts to update credentials
2. **Manual Migration**: Run the app to trigger automatic migration from .env to Keychain
3. **Environment Fallback**: If Keychain credentials are missing, the app falls back to .env

### Security Benefits

- **Encrypted Storage**: Credentials are encrypted by macOS Keychain
- **Access Control**: Only the PhotoBooth app can access its credentials
- **No File Exposure**: Credentials are not stored in plain text files
- **Automatic Cleanup**: Credentials are properly managed and cleaned up

### Managing Credentials

- **Clear All**: The app can clear all stored credentials from Keychain
- **Individual Deletion**: Remove specific credentials as needed
- **Migration Status**: View which credentials have been migrated

## 🆘 Troubleshooting

### iPhone Not Detected
- Unlock your iPhone
- Check both devices are on same Wi-Fi
- Click the refresh button (↻) in the app
- Restart both devices if needed

### SMS Not Sending
- Verify Twilio credentials in Keychain or .env
- Check phone number format (+1 for US)
- Ensure Twilio account has credits

### Credential Issues
- Check configuration summary in app logs
- Verify OpenAI API key is valid and has credits
- Ensure Keychain access is not blocked
- Try manual migration if automatic migration fails

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
- **Security**: Credentials are now stored in macOS Keychain for enhanced security
- **Backup**: Keep your .env file secure and never commit it (used as fallback)
- **Migration**: The app automatically migrates from .env to Keychain

## 🎉 Ready to Party!

Your AI Photo Booth is ready for events. Have fun transforming guests into their favorite cartoon characters!

Need help? Check the full README.md for detailed documentation. 