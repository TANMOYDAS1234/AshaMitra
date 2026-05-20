# Voice Speech-to-Text Implementation

## Overview
The voice triage screen now uses a **hybrid online/offline approach** for speech recognition, optimized for Bengali dialects (especially West Bengal), Hindi, and English.

## How It Works

### 1. **Online Mode (Default)** 🟢
- **Engine:** Google Speech Recognition via `speech_to_text` package
- **Accuracy:** Excellent for Bengali dialects (Rarhi, Banga, Medinipur, etc.), Hindi, and English
- **Requires:** Internet connection
- **Speed:** Real-time streaming transcription
- **Languages:**
  - `bn_IN` — Bengali (India) — Default
  - `hi_IN` — Hindi (India)
  - `en_IN` — English (India)

### 2. **Offline Mode (Fallback)** 🔴
- **Engine:** Whisper Tiny model via `whisper_flutter_new` package
- **Accuracy:** Good for general multilingual speech, moderate for Bengali dialects
- **Requires:** ~75MB model (auto-downloads on first use)
- **Speed:** Processes after recording stops (~2-3 seconds)
- **Works:** Completely offline, no internet needed

## Automatic Switching
The app automatically detects connectivity:
- ✅ **Internet available** → Uses Google STT (online mode)
- ❌ **No internet** → Falls back to Whisper (offline mode)

## User Experience

### Language Selection
Users can tap language pills before speaking:
- **বাংলা** (Bengali - India)
- **हिंदी** (Hindi - India)
- **English** (English - India)

### Status Indicators
- 🟢 **"Online — Google STT"** — Using cloud-based recognition
- 🔴 **"Offline — Whisper"** — Using on-device recognition

### Voice Recognition Flow
1. User taps mic button
2. App checks connectivity
3. Starts appropriate STT engine
4. Shows live transcript as user speaks
5. Matches keywords (হ্যাঁ, না, মাঝে মাঝে, etc.)
6. Auto-advances to next question

## Keyword Matching
Supports multilingual keywords for answers:

**Yes (হ্যাঁ):**
- Bengali: হ্যাঁ, হা, হ্যা, জি, অবশ্যই, ঠিক, সত্যি
- Hindi: हाँ, हां, हा, जी, बिल्कुल, सही, ठीक
- English: yes, yeah, yep, correct, right, sure, ok

**No (না):**
- Bengali: না, নাহ, নেই, নয়, নাই
- Hindi: नहीं, नही, ना, नहीं है
- English: no, nope, not, never, nah

**Maybe (মাঝে মাঝে):**
- Bengali: মাঝে মাঝে, কিছুটা, একটু, হয়তো, নিশ্চিত না
- Hindi: कभी कभी, थोड़ा, शायद, पता नहीं
- English: sometimes, maybe, little, occasionally

## Technical Details

### Dependencies
```yaml
speech_to_text: ^7.0.0        # Online Google STT
whisper_flutter_new: ^1.0.1   # Offline Whisper
record: ^5.2.1                # Audio recording for Whisper
connectivity_plus: ^7.1.1     # Network detection
```

### Permissions (AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

### File Location
`lib/features/triage/presentation/screens/voice_triage_screen.dart`

## Benefits for ASHA Workers

1. **Works in low-connectivity areas** — Offline fallback ensures functionality in rural West Bengal
2. **Handles local dialects** — Google STT trained on regional Bengali variations
3. **Multilingual support** — Seamlessly handles Bengali, Hindi, English, and code-switching
4. **No manual typing** — Faster data collection during home visits
5. **Real-time feedback** — Live transcript shows what was heard

## First-Time Setup
- **Online mode:** Works immediately (no setup)
- **Offline mode:** Whisper model (~75MB) downloads automatically on first offline use

## Testing Recommendations

1. **Test online mode** with internet:
   - Speak in Bengali (West Bengal dialect)
   - Try Hindi phrases
   - Mix English words

2. **Test offline mode** without internet:
   - Turn off WiFi/mobile data
   - Verify Whisper fallback activates
   - Check transcription quality

3. **Test language switching:**
   - Switch between বাংলা, हिंदी, English
   - Verify correct locale is used

4. **Test keyword matching:**
   - Say "হ্যাঁ" → should select first option
   - Say "না" → should select second option
   - Say "মাঝে মাঝে" → should select third option

## Known Limitations

1. **Offline mode accuracy:** Whisper Tiny has lower accuracy for Bengali dialects compared to Google STT
2. **First offline use:** Requires ~75MB download (one-time)
3. **Online mode requires internet:** No caching of Google STT results

## Future Improvements

- [ ] Add more regional language support (Assamese, Odia, etc.)
- [ ] Implement larger Whisper model option for better offline accuracy
- [ ] Add voice feedback (text-to-speech) for questions
- [ ] Cache common phrases for faster offline recognition
