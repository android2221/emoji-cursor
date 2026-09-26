cask "emojicursor" do
  version "1.0.0"
  sha256 "REPLACE_WITH_SHA256_FROM_RELEASE"

  url "https://github.com/android2221/emoji-cursor/releases/download/v#{version}/EmojiCursor-#{version}.zip"
  name "EmojiCursor"
  desc "Overlay emojis on your cursor"
  homepage "https://github.com/android2221/emoji-cursor"

  depends_on macos: ">= :sonoma"

  app "EmojiCursor.app"

  zap trash: [
    "~/Library/Preferences/com.emojicursor.app.plist",
  ]
end
