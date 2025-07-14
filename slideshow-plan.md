# Slideshow Module Implementation Plan

## Overview
Create a slideshow module that displays original and themed photo pairs on a loop to attract event attendees to the PhotoBooth. The slideshow runs on the secondary display in fullscreen mode when no photo booth operations are active.

## User Requirements Summary
- **Display Location**: Secondary screen in new fullscreen window
- **Trigger**: Manual launch from control panel
- **Exit Conditions**: Manual button press OR theme selection OR photo capture start
- **Photo Selection**: All complete photo pairs from `~/Pictures/booth/` folder
- **Timing**: Original photo (5s) → fade → themed photo (5s) → next pair
- **Controls**: Launch/exit buttons + speed adjustment
- **Smart Behavior**: Auto-close during photo operations, auto-add new photos
- **Error Handling**: Skip incomplete pairs (missing original or themed image)

---

## Phase 1: Core Architecture & Data Management

### 1.1 Create SlideShowViewModel
**Purpose**: Manage slideshow state, photo scanning, and timing

**Key Properties**:
- `isActive: Bool` - Whether slideshow is running
- `photoPairs: [PhotoPair]` - Array of matched original/themed photo pairs
- `currentPairIndex: Int` - Current photo pair being displayed
- `displayDuration: Double` - Configurable speed (default 5 seconds)
- `isShowingOriginal: Bool` - Toggle between original and themed
- `lastFolderScan: Date` - Track when we last scanned for new photos

**Key Methods**:
- `startSlideshow()` - Initialize and begin slideshow
- `stopSlideshow()` - Stop slideshow and cleanup
- `scanForPhotoPairs()` - Discover and match photo pairs
- `nextPhoto()` - Advance to next photo in sequence
- `updateDisplayDuration(_ seconds: Double)` - Adjust timing

### 1.2 Create PhotoPair Model
```swift
struct PhotoPair: Identifiable {
    let id = UUID()
    let original: URL
    let themed: URL
    let timestamp: Date
    let originalImage: NSImage
    let themedImage: NSImage
}
```

### 1.3 Photo Discovery Service
**Functionality**:
- Scan `~/Pictures/booth/` folder for matching pairs
- Parse timestamps from filenames (`original_TIMESTAMP.jpg` ↔ `themed_TIMESTAMP.jpg`)
- Sort by creation date (newest first for attraction value)
- Auto-refresh when new photos are detected via NotificationCenter
- Skip incomplete pairs (missing original or themed counterpart)

**Implementation Details**:
- Use FileManager to enumerate booth directory
- Match files by extracting timestamps from filenames
- Load images into memory with caching strategy
- Handle corrupted or unreadable image files gracefully

---

## Phase 2: Slideshow Display & Window Management

### 2.1 Create SlideShowView
**Purpose**: Fullscreen SwiftUI view with smooth cross-fade animations

**Display Logic**:
1. Show original photo for `displayDuration` seconds
2. Cross-fade to themed version (1 second transition)
3. Show themed photo for `displayDuration` seconds  
4. Cross-fade to next original (1 second transition)
5. Loop continuously until stopped

**Visual Design**:
- Clean, fullscreen display with black background
- Smooth cross-fade animations using SwiftUI transitions
- Subtle photo counter overlay ("Photo X of Y")
- Proper aspect ratio handling for landscape photos

### 2.2 Create SlideShowWindowController
**Purpose**: Manage secondary display detection and fullscreen presentation

**Features**:
- Auto-detect secondary displays using NSScreen API
- Launch in fullscreen on secondary display (fallback to primary if none)
- Handle window lifecycle and cleanup
- ESC key handling for manual exit
- Window level management to ensure proper display hierarchy

**Implementation Approach**:
- Use NSWindow with fullscreen presentation
- Integrate with existing window management system
- Handle display connection/disconnection events
- Remember user's preferred slideshow display

---

## Phase 3: Control Panel Integration

### 3.1 Add Slideshow Controls to ControlCenterView
**New UI Elements**:
- **"Start Slideshow" button** - Launches slideshow if photos available
- **Speed adjustment slider** - 2-10 seconds per image
- **"Stop Slideshow" button** - Manual exit (only visible when active)
- **Photo count indicator** - "X photo pairs available"

**Layout Integration**:
- Add slideshow section below existing controls
- Use consistent styling with current UI elements
- Show/hide controls based on slideshow state
- Provide visual feedback for slideshow status

### 3.2 State Management Integration
**PhotoBoothViewModel Extensions**:
- Add slideshow-related @Published properties
- Connect SlideShowViewModel to existing PhotoBoothViewModel
- Coordinate state between photo booth and slideshow operations

**Event Handling**:
- Listen for theme selection → auto-close slideshow
- Listen for photo capture start → auto-close slideshow  
- Listen for new photo completion → auto-add to slideshow
- Handle slideshow window events

---

## Phase 4: Smart Behavior & User Experience

### 4.1 Intelligent Slideshow Behavior
**Auto-close Scenarios**:
- User selects any theme (immediately)
- Photo capture countdown starts
- Manual exit button pressed
- ESC key pressed in slideshow window

**Enhancement Features**:
- **Auto-resume Option**: Restart slideshow after photo completion
- **Attraction Mode**: Slower transitions to showcase photos
- **Recent Photo Highlighting**: Prioritize newest photos in rotation

### 4.2 Performance Optimization
**Image Caching Strategy**:
- Pre-load next 3-5 photo pairs in memory
- Background loading to prevent slideshow stuttering
- Memory management for large photo collections

**Efficient Operations**:
- Background folder scanning without UI blocking
- Lazy loading of images not currently displayed
- Proper cleanup when slideshow stops

---

## Phase 5: Error Handling & Edge Cases

### 5.1 Robust Photo Pairing
**Error Scenarios**:
- Missing themed images (skip incomplete pairs)
- Corrupted image files (skip and log error)
- Empty booth folder (display "No photos available" state)
- Permission issues accessing Pictures directory

**User Feedback**:
- Clear messaging when no photos are available
- Graceful degradation when images can't be loaded
- Error recovery without crashing the slideshow

### 5.2 Display Management
**Multi-Display Handling**:
- Handle display disconnection during slideshow
- Graceful fallback to primary display
- Remember user's preferred slideshow display
- Adapt to display resolution changes

---

## Implementation Timeline

1. **Phase 1** (Day 1): Core data models and photo discovery
   - Create PhotoPair model
   - Implement photo scanning and pairing logic
   - Basic SlideShowViewModel structure

2. **Phase 2** (Day 2): Basic slideshow view and window management  
   - Create SlideShowView with fade animations
   - Implement SlideShowWindowController
   - Basic fullscreen presentation

3. **Phase 3** (Day 3): Control panel integration and state management
   - Add UI controls to ControlCenterView
   - Integrate with PhotoBoothViewModel
   - Wire up start/stop functionality

4. **Phase 4** (Day 4): Smart behaviors and performance optimization
   - Implement auto-close logic
   - Add image caching and performance optimizations
   - Background photo scanning

5. **Phase 5** (Day 5): Polish, testing, and edge case handling
   - Error handling and edge cases
   - User experience refinements
   - Testing and bug fixes

---

## Key Integration Points

- **Extends Existing Notification System**: Leverages `Notification.Name.newPhotoCapture` and related events
- **Uses Current Photo Storage**: Works with existing `~/Pictures/booth/` structure
- **Respects Photo Booth Workflow**: Doesn't interfere with capture/processing operations
- **Follows Established UI Patterns**: Integrates seamlessly with ControlCenterView design
- **Maintains Performance**: Efficient memory and CPU usage during slideshow operation

---

## Success Criteria

- ✅ Slideshow launches in fullscreen on secondary display
- ✅ Smooth 5-second original → 5-second themed transitions
- ✅ Auto-closes when photo booth operations begin
- ✅ Automatically includes new photos as they're created
- ✅ Handles missing/corrupted photos gracefully
- ✅ Provides intuitive control panel integration
- ✅ Maintains good performance with large photo collections
- ✅ Works reliably across display configuration changes 