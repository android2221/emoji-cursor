cask "emojicursor" do
  version "1.0.0"
  sha256 "REPLACE_WITH_SHA256_FROM_RELEASE"

  url "https://github.com/android2221/emoji-cursor/releases/download/v#{version}/EmojiCursor-#{version}.zip"
  name "EmojiCursor"
  desc "Floating emoji that follows your mouse pointer"
  homepage "https://github.com/android2221/emoji-cursor"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sonoma"

  app "EmojiCursor.app"

  uninstall quit: "com.emojicursor.app"

  zap trash: [
    "~/Library/Caches/com.emojicursor.app",
    "~/Library/Preferences/com.emojicursor.app.plist",
    "~/Library/Saved Application State/com.emojicursor.app.savedState",
  ]
end
