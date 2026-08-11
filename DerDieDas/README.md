# Der Die Das (iOS)

Native SwiftUI iOS app for practicing German articles — based on the **DER/DIE/DAS** game from [GermanaTeodora](https://github.com/spirea89/GermanaTeodora).

## How to play

1. The app shows (and speaks) a noun **without** the article.
2. Answer with **both** the article and the word, for example `die Sonne`.
3. Tap **Check**. Correct answers score a point; wrong answers can be tried again.
4. Use **Hear word** to listen again, or **Skip** to move on.

## Multiplayer

On the Play setup screen choose 1–6 players, names, and rounds per player. Turns rotate after each answered or skipped word. The scoreboard highlights whose turn it is, and a celebration appears when everyone finishes.

## Words

- Bundled list: **617** unique nouns imported from `GermanaTeodora/data/article-words.txt`
- App resource: `DerDieDas/Resources/content/words.json`
- Editable copy for reference: `content/article-words.txt`
- Use the **Words** tab to add, edit, delete, save, or reload the bundled defaults (saves to Application Support on device)

## Requirements

- macOS with Xcode 15 or newer (iOS 17+)
- Apple Developer account for device installs / App Store submission

## Open and run

1. Open `DerDieDas.xcodeproj` in Xcode.
2. Select the **DerDieDas** target and set your Team under Signing & Capabilities.
3. Choose an iPhone/iPad simulator and press Run.

Display name: **Der Die Das**  
Bundle ID: `com.spirea89.DerDieDas`
