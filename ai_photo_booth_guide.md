# Mac + Continuity Camera AI Photo‑Booth  
**5‑Day MVP — Ultra‑Simple Step‑By‑Step**

---

## Day 0 – Project Setup
1. **Create project folder**  
   ```bash
   mkdir mac-photobooth && cd mac-photobooth && git init
   ```
2. **Open Xcode → “App” (macOS) → SwiftUI**  
3. **Add API keys**  
   *Create `.env`:*  
   ```
   OPENAI_KEY=sk-...
   TWILIO_SID=AC...
   TWILIO_TOKEN=...
   TWILIO_FROM=+15551234567
   ```
4. **Enable Camera in App Sandbox** (`Signing & Capabilities`).

---

## Day 1 AM – Continuity Camera Preview
1. `import AVFoundation`  
2. **Find device**  
   ```swift
   let device = AVCaptureDevice
       .devices()
       .first { $0.deviceType == .continuityCamera }!
   ```
3. **Session + preview layer** inside `NSViewRepresentable`.
4. **Run** — live iPhone video should appear.

## Day 1 PM – Capture Still
1. Add `AVCapturePhotoOutput` to session.  
2. Capture on button tap:  
   ```swift
   photoOutput.capturePhoto(with: .init(), delegate: self)
   ```
3. Save JPEG to `~/Pictures/booth/original.jpg`.

---

## Day 2 AM – Theme UI
1. Hard‑code **9 prompts** in an array.  
2. Display grid with `LazyVGrid` + `Button`.

## Day 2 PM – Countdown
1. On **Snap** set `countdown = 3`.  
2. Start `Timer` every second; overlay `Text(countdown)`.  
3. Play a beep (`NSSound(named:"Glass")`).

---

## Day 3 AM – OpenAI Generation
1. Add **OpenAI Swift SDK**.  
2. Generate themed image:  
   ```swift
   let result = try await client.images.generate(
       prompt: prompts[selected],
       n: 1,
       size: "1536x1024",
       responseFormat: .base64JSON)
   let data = Data(base64Encoded: result.data[0].b64JSON)!
   try data.write(to: themedURL)
   ```

## Day 3 PM – Twilio MMS
1. Add **TwilioSwift** package.  
2. Send:  
   ```swift
   try await twilio.messages.create(
       to: phone, from: env.TWILIO_FROM, mediaUrl: themedURL)
   ```

---

## Day 4 AM – Second Screen Fade Reveal
1. Detect external `NSScreen`.  
2. Create borderless `NSWindow` on it.  
3. SwiftUI `Image` overlay fades from original to themed with  
   ```swift
   withAnimation(.easeInOut(duration:1)) { showThemed = true }
   ```

## Day 4 PM – Disk Cache
1. Save each pair in dated folder.  
2. Delete folders older than 7 days on launch.

---

## Day 5 – QA & Demo
1. Disable Wi‑Fi; verify LTE flow.  
2. Unplug/replug iPhone; auto‑reconnect.  
3. Capture 10 photos; ensure slideshow updates.  
4. Record final demo video.

---

*That’s it—functional booth in 5 focused days!*  
