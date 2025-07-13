# UI Updates Plan - PhotoBooth App

## Overview
Restructure the PhotoBooth app to move camera preview and countdown to the projector display, making it easier for participants to frame themselves. The main display becomes an operator control center with theme selection and controls.

## Phase 1: Projector Display Overhaul
**Current State**: Projector shows themed results and processing overlays  
**New State**: Projector becomes the primary participant interface

### Changes:
- Move live camera preview to projector (full-screen with margin/background)
- Add countdown overlay (3-2-1) on projector during photo capture
- Maintain current flow: original photo → processing overlay → themed reveal
- **New**: Themed image must display for minimum 10 seconds before theme button can activate live feed
- Add "Ready for next photo" state that returns to live camera feed
- Implement automatic display detection (projector window on secondary display if available, otherwise main display)

## Phase 2: Main Display Redesign
**Current State**: Shows camera preview, themes, and controls  
**New State**: Becomes operator control center

### New Layout:
```
┌─────────────────────────────────────┐
│  AI Photo Booth - Control Center   │
├─────────────────────────────────────┤
│  Theme Selection Grid               │
│  [Pixar] [Simpsons] [SpongeBob]    │
│  [South Park] [Rick&Morty] [DBZ]   │
│  [Flintstones] [Scooby Doo]        │
├─────────────────────────────────────┤
│  📸 TAKE PHOTO (Large Button)      │
├─────────────────────────────────────┤
│  Last Photo Preview (Small)        │
│  Original | Themed                 │
│  Status: "Ready" / "Processing..."  │
├─────────────────────────────────────┤
│  🖥️ Projector: [Show/Hide] [Reset] │
│  ⚙️ Settings                        │
└─────────────────────────────────────┘
```

## Phase 3: State Management Updates
### New State Flow:
1. **Idle**: Projector shows live camera feed (with margin)
2. **Countdown**: Projector shows countdown overlay over camera feed
3. **PhotoTaken**: Projector immediately shows captured original photo
4. **Processing**: Projector shows processing overlay with theme name/progress
5. **Reveal**: Projector shows themed result
6. **MinimumDisplay**: Themed image displays for minimum 10 seconds
7. **ReadyForNext**: After theme selection (and 10s minimum), return to live camera feed
8. **Error**: Show graceful and funny error message, then return to live feed

### Error Handling:
- Display humorous error messages on projector (e.g., "Oops! The AI got camera shy! Let's try that again! 📸")
- Automatic return to live camera feed for retake
- Log detailed errors for debugging while showing user-friendly messages

## Phase 4: Technical Implementation

### New Components Needed:
- `ProjectorCameraView`: Live camera feed for projector with margin
- `ProjectorCountdownView`: Countdown overlay
- `ControlCenterView`: New main display layout
- `ProjectorDisplayManager`: Handle single vs dual display logic
- `ErrorMessageView`: Funny error display component

### Modified Components:
- `ProjectorView`: Add camera preview, countdown, and error states
- `PhotoBoothViewModel`: Update state management for new flow with 10s minimum display timer
- `ContentView`: Replace with control center layout

### New State Properties:
- `minimumDisplayTimer`: Timer for 10-second themed image display
- `isReadyForNextPhoto`: Boolean to control theme button activation
- `displayConfiguration`: Track single vs dual display setup

## Phase 5: Display Detection & Fallback
- Auto-detect secondary displays on app launch
- If secondary display available: projector window on secondary, control center on main
- If single display: projector window on main display (for testing)
- Add display connection/disconnection handling
- Graceful transitions when displays are added/removed

## Phase 6: Settings Integration
- Add "Default Projector State" setting (Show/Hide on startup)
- Maintain existing projector timing controls
- Add "Single Display Mode" toggle for testing
- Add "Minimum Display Duration" setting (default 10s, range 5-30s)

## Phase 7: Camera Preview Specifications
- **Layout**: Camera feed centered with margin/background on projector
- **Aspect Ratio**: Maintain camera's natural aspect ratio
- **Background**: Subtle gradient or solid color around camera feed
- **Responsiveness**: Adapt to different projector resolutions

## Phase 8: Theme Selection Flow
- Theme buttons disabled during minimum display period
- Visual feedback when theme is selected (brief highlight)
- Theme selection immediately triggers return to live camera feed
- Clear visual indication of selected theme on control center

## Phase 9: Error Messages Collection
Funny error messages to rotate through:
- "Oops! The AI got camera shy! Let's try that again! 📸"
- "The pixels went on a coffee break! Ready for round two? ☕"
- "Houston, we have a photo problem! Let's give it another shot! 🚀"
- "The AI sneezed during processing! Bless you, AI! Let's retry! 🤧"
- "Photo booth gremlins detected! Shaking them off... Try again! 👾"

## Implementation Order:
1. Create new state management system with 10s timer
2. Build ProjectorCameraView with margin layout
3. Implement ControlCenterView for main display
4. Add display detection logic
5. Create error handling with funny messages
6. Update settings for new options
7. Test single vs dual display scenarios
8. Polish transitions and animations

## Testing Scenarios:
- Single display mode (development/testing)
- Dual display mode (production)
- Display disconnection during operation
- Error conditions and recovery
- Theme selection timing and flow
- Camera permission handling

## Success Criteria:
- Participants can easily frame themselves using projector camera preview
- Smooth countdown and photo capture experience
- Minimum 10-second themed image display before next photo
- Graceful error handling with humor
- Seamless single/dual display operation
- Intuitive operator control center interface 