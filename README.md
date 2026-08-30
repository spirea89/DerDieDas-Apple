# Der Die Das (iOS)

Native SwiftUI iOS app for practicing German articles — based on the **DER/DIE/DAS** game from [GermanaTeodora](https://github.com/spirea89/GermanaTeodora).

## How to play

1. The app shows (and speaks) a noun **without** the article.
2. Wait for the **beep** — that means the mic is open.
3. **Say** the article and the word out loud, for example `die Sonne`.
4. The app listens, tells you if you were right, speaks the full phrase, and moves to the next word automatically.
5. Use **Pace** (Slow / Normal / Fast) to control speech speed and the pause between words.
6. Use **Hear again** to replay the noun, **Listen again** if the mic stopped, or **Skip** to move on.

## Multiplayer

On the Play setup screen choose 1–6 players, names, and rounds per player. Turns rotate after each answered or skipped word. The scoreboard highlights whose turn it is, and a celebration appears when everyone finishes.

## Words

- Bundled list: **617** unique nouns imported from `GermanaTeodora/data/article-words.txt`
- App resource: `DerDieDas/Resources/content/words.json`
- Editable copy for reference: `content/article-words.txt`
- Use the **Words** tab to add, edit, delete, save, or reload the bundled defaults (saves to Application Support on device)

## Requirements

- macOS with Xcode 15 or newer (iOS 17+)
- Microphone + Speech Recognition permission (prompted on first play)
- Apple Developer account for device installs / App Store submission

## Open and run in Xcode

1. Clone this repository.
2. Open `DerDieDas.xcodeproj` in Xcode.
3. Select the **DerDieDas** target and set your Team under Signing & Capabilities.
4. Choose an iPhone/iPad simulator or device and press Run.
5. Allow microphone and speech recognition when prompted (use a real device for best voice results).

Display name: **Der Die Das**  
Bundle ID: `com.spirea89.DerDieDas`
