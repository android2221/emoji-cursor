# EmojiCursor

A macOS menu bar app that floats an emoji next to your mouse pointer, with optional spring physics, a fading tail, idle "alive" motion and a jiggle when you click.

Requires macOS 14 (Sonoma) or later. EmojiCursor asks for no special permissions, collects no data and makes no network connections.

## Install

```sh
brew tap android2221/emoji-cursor https://github.com/android2221/emoji-cursor
brew install --cask emojicursor
```

Or download the DMG from the [latest release](https://github.com/android2221/emoji-cursor/releases/latest).

EmojiCursor lives in the menu bar (the smiling-face icon). If your menu bar is crowded and the icon is hidden, open EmojiCursor again from Applications or Spotlight to bring up its window.

## Develop

Open `EmojiCursor.xcodeproj` in Xcode 15 or later and run the `EmojiCursor` scheme. To run the tests:

```sh
xcodebuild test -project EmojiCursor.xcodeproj -scheme EmojiCursor -destination 'platform=macOS'
```

## Release

Releases are signed with a Developer ID certificate, notarized by Apple and published to GitHub Releases. The Homebrew cask in `Casks/` points at the release zip.

**Automated:** push a version tag.

```sh
git tag v1.0.0 && git push origin v1.0.0
```

`.github/workflows/release.yml` runs the tests, then builds, signs, notarizes and staples the app and DMG, creates the GitHub release, and commits the new version and checksum to `Casks/emojicursor.rb` on the default branch. It needs these repository secrets:

| Secret | What it is |
|---|---|
| `APPLE_CERTIFICATE_P12` | Base64 of your exported "Developer ID Application" certificate + private key (`base64 -i cert.p12`) |
| `APPLE_CERTIFICATE_PASSWORD` | Password you set when exporting the .p12 |
| `KEYCHAIN_PASSWORD` | Any random string (used for a temporary CI keychain) |
| `APPLE_ID` | Your Apple ID email |
| `APPLE_TEAM_ID` | `4JKVKDGJN4` |
| `APPLE_APP_PASSWORD` | An app-specific password from appleid.apple.com |

**Manual, from your Mac:** needs the Developer ID Application certificate in your keychain, `brew install create-dmg`, and stored notary credentials:

```sh
xcrun notarytool store-credentials EmojiCursor-notary \
  --apple-id <you@example.com> --team-id 4JKVKDGJN4 --password <app-specific-password>
./scripts/release.sh 1.0.0
./scripts/update-cask.sh 1.0.0 <zip sha256 printed by release.sh>
```
