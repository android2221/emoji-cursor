import Foundation

struct EmojiCategory: Identifiable {
    let id: String
    let icon: String
    let emojis: [String]
}

// MARK: - Emoji Search Keywords

/// Maps emojis to extra search terms not in their Unicode name.
enum EmojiKeywords {
    static let keywords: [String: [String]] = [
        // Flowers
        "🌸": ["flower", "pink", "spring"],
        "🌹": ["flower", "red"],
        "🌺": ["flower", "tropical"],
        "🌻": ["flower", "yellow"],
        "🌼": ["flower", "daisy"],
        "🌷": ["flower", "pink"],
        "💐": ["flower", "bouquet"],
        "🥀": ["flower", "dead", "wilted"],
        "🏵️": ["flower", "rosette"],
        "💮": ["flower", "white"],
        // Hearts
        "❤️": ["love", "heart", "red"],
        "🧡": ["love", "heart"],
        "💛": ["love", "heart"],
        "💚": ["love", "heart"],
        "💙": ["love", "heart"],
        "💜": ["love", "heart"],
        "🖤": ["love", "heart", "black"],
        "🤍": ["love", "heart", "white"],
        "🤎": ["love", "heart", "brown"],
        "💔": ["love", "heart", "broken"],
        "❤️‍🔥": ["love", "heart", "fire"],
        "❤️‍🩹": ["love", "heart", "mending"],
        "💕": ["love", "heart"],
        "💞": ["love", "heart"],
        "💓": ["love", "heart"],
        "💗": ["love", "heart"],
        "💖": ["love", "heart"],
        "💘": ["love", "heart", "arrow"],
        "💝": ["love", "heart", "gift"],
        // Animals
        "🐶": ["dog", "puppy", "pet"],
        "🐱": ["cat", "kitty", "pet"],
        "🐰": ["rabbit", "bunny", "pet"],
        "🐹": ["hamster", "pet"],
        "🐻": ["bear", "teddy"],
        "🦊": ["fox"],
        "🐼": ["panda", "bear"],
        "🐨": ["koala", "bear"],
        "🦁": ["lion", "cat"],
        "🐯": ["tiger", "cat"],
        "🐮": ["cow"],
        "🐷": ["pig"],
        "🐸": ["frog", "toad"],
        "🐵": ["monkey", "ape"],
        "🐔": ["chicken", "bird"],
        "🐧": ["penguin", "bird"],
        "🦅": ["eagle", "bird"],
        "🦆": ["duck", "bird"],
        "🦉": ["owl", "bird"],
        "🐦": ["bird"],
        "🐤": ["chick", "bird", "baby"],
        "🐣": ["chick", "bird", "baby", "hatching"],
        "🐥": ["chick", "bird", "baby"],
        "🦜": ["parrot", "bird"],
        "🦢": ["swan", "bird"],
        "🦩": ["flamingo", "bird"],
        "🕊️": ["dove", "bird", "peace"],
        "🐍": ["snake", "reptile"],
        "🐢": ["turtle", "reptile"],
        "🦎": ["lizard", "reptile"],
        "🐊": ["crocodile", "reptile", "alligator"],
        "🐳": ["whale", "ocean"],
        "🐋": ["whale", "ocean"],
        "🐬": ["dolphin", "ocean"],
        "🦈": ["shark", "ocean"],
        "🐙": ["octopus", "ocean"],
        "🐟": ["fish", "ocean"],
        "🐠": ["fish", "tropical"],
        "🐡": ["fish", "blowfish"],
        "🐞": ["ladybug", "bug", "insect"],
        "🦋": ["butterfly", "bug", "insect"],
        "🐛": ["caterpillar", "bug", "insect"],
        "🐜": ["ant", "bug", "insect"],
        "🐝": ["bee", "bug", "insect", "honey"],
        "🕷️": ["spider", "bug", "insect"],
        // Food
        "🍕": ["pizza", "food"],
        "🍔": ["burger", "hamburger", "food"],
        "🍟": ["fries", "food"],
        "🌭": ["hotdog", "food"],
        "🍿": ["popcorn", "food", "snack", "movie"],
        "🍩": ["donut", "doughnut", "food", "sweet"],
        "🍪": ["cookie", "food", "sweet"],
        "🎂": ["cake", "birthday", "food", "sweet"],
        "🍰": ["cake", "food", "sweet"],
        "🧁": ["cupcake", "food", "sweet"],
        "🍫": ["chocolate", "food", "sweet", "candy"],
        "🍬": ["candy", "food", "sweet"],
        "🍭": ["lollipop", "food", "sweet", "candy"],
        "☕": ["coffee", "drink", "hot"],
        "🍵": ["tea", "drink", "hot"],
        "🍺": ["beer", "drink", "alcohol"],
        "🍷": ["wine", "drink", "alcohol"],
        "🥤": ["drink", "soda", "juice"],
        // Faces / emotions
        "😀": ["happy", "smile", "face"],
        "😃": ["happy", "smile", "face"],
        "😄": ["happy", "smile", "face"],
        "😁": ["happy", "smile", "face", "grin"],
        "😂": ["laugh", "cry", "face", "funny", "lol"],
        "🤣": ["laugh", "face", "funny", "lol", "rofl"],
        "😍": ["love", "face", "heart"],
        "🥰": ["love", "face", "heart"],
        "😘": ["kiss", "face", "love"],
        "😢": ["sad", "cry", "face"],
        "😭": ["sad", "cry", "face", "sobbing"],
        "😡": ["angry", "mad", "face"],
        "😠": ["angry", "mad", "face"],
        "😱": ["scared", "shock", "face", "scream"],
        "😴": ["sleep", "tired", "face", "zzz"],
        "🤔": ["think", "face", "hmm"],
        "😎": ["cool", "face", "sunglasses"],
        "🤩": ["excited", "face", "star"],
        "🥳": ["party", "face", "celebrate"],
        "😷": ["sick", "face", "mask"],
        "🤒": ["sick", "face", "fever"],
        "🤮": ["sick", "face", "vomit"],
        "💀": ["dead", "skull", "death"],
        "👻": ["ghost", "scary", "halloween"],
        "👽": ["alien", "ufo", "space"],
        "🤖": ["robot", "bot"],
        // Gestures
        "👍": ["thumbs up", "yes", "good", "ok", "like"],
        "👎": ["thumbs down", "no", "bad", "dislike"],
        "👋": ["wave", "hello", "hi", "bye"],
        "👏": ["clap", "applause", "bravo"],
        "🙏": ["pray", "please", "thanks", "hope"],
        "💪": ["strong", "muscle", "flex", "power"],
        "🤝": ["handshake", "deal", "agree"],
        "✌️": ["peace", "victory"],
        "🤞": ["luck", "fingers crossed", "hope"],
        "👌": ["ok", "perfect", "fine"],
        "🖕": ["middle finger", "rude"],
        // Objects
        "💻": ["computer", "laptop", "tech"],
        "📱": ["phone", "mobile", "cell"],
        "⌨️": ["keyboard", "computer", "type"],
        "🖥️": ["computer", "desktop", "monitor"],
        "💡": ["idea", "light", "bulb"],
        "🔑": ["key", "lock", "password"],
        "🔒": ["lock", "secure", "password"],
        "📷": ["camera", "photo"],
        "📸": ["camera", "photo", "flash"],
        "🎥": ["camera", "video", "movie", "film"],
        "📺": ["tv", "television", "screen"],
        "🎮": ["game", "controller", "play", "video game"],
        "🎵": ["music", "note", "song"],
        "🎶": ["music", "notes", "song"],
        "🎤": ["microphone", "sing", "karaoke"],
        "🎧": ["headphones", "music", "listen"],
        "📚": ["book", "read", "study"],
        "✏️": ["pencil", "write", "edit"],
        "📝": ["write", "note", "memo"],
        "✉️": ["email", "mail", "letter"],
        "📦": ["package", "box", "delivery"],
        "💰": ["money", "cash", "rich"],
        "💵": ["money", "dollar", "cash"],
        "💳": ["credit card", "payment", "money"],
        // Weather / nature
        "☀️": ["sun", "sunny", "weather", "hot"],
        "🌙": ["moon", "night"],
        "⭐": ["star", "night"],
        "🌟": ["star", "sparkle", "glow"],
        "✨": ["sparkle", "star", "magic", "new"],
        "🔥": ["fire", "hot", "lit"],
        "💧": ["water", "drop", "rain"],
        "🌊": ["wave", "ocean", "water", "sea"],
        "🌈": ["rainbow", "color"],
        "❄️": ["snow", "cold", "winter", "ice"],
        "⛄": ["snowman", "cold", "winter"],
        "🌪️": ["tornado", "weather", "storm"],
        "⚡": ["lightning", "electric", "power", "thunder"],
        "☁️": ["cloud", "weather"],
        "🌧️": ["rain", "weather", "cloud"],
        // Transport
        "🚗": ["car", "drive", "vehicle"],
        "🚕": ["taxi", "cab", "car"],
        "🚀": ["rocket", "space", "launch", "fast"],
        "✈️": ["plane", "airplane", "fly", "travel"],
        "🚁": ["helicopter", "fly"],
        "🚂": ["train", "travel"],
        "🚢": ["ship", "boat", "cruise"],
        "🚲": ["bike", "bicycle", "cycle"],
        // Symbols / misc
        "✅": ["check", "done", "yes", "complete"],
        "❌": ["no", "wrong", "cross", "delete"],
        "⚠️": ["warning", "alert", "caution"],
        "🚫": ["no", "forbidden", "stop", "ban"],
        "💯": ["hundred", "perfect", "score"],
        "♻️": ["recycle", "green", "environment"],
        "🎉": ["party", "celebrate", "tada"],
        "🎊": ["party", "celebrate", "confetti"],
        "🎈": ["balloon", "party"],
        "🎁": ["gift", "present", "birthday"],
        "🏆": ["trophy", "winner", "champion", "award"],
        "🥇": ["gold", "medal", "first", "winner"],
        "🏠": ["house", "home"],
        "🏡": ["house", "home", "garden"],
        "🌍": ["earth", "world", "globe"],
        "🌎": ["earth", "world", "globe"],
        "🌏": ["earth", "world", "globe"],
        // Flags
        "🏁": ["flag", "finish", "race"],
        "🚩": ["flag", "red"],
        "🏳️": ["flag", "white"],
        "🏴": ["flag", "black"],
        "🏳️‍🌈": ["flag", "pride", "rainbow", "lgbtq"],
    ]

    static func matches(_ emoji: String, query: String) -> Bool {
        if let kws = keywords[emoji] {
            return kws.contains { $0.contains(query) }
        }
        return false
    }
}

// MARK: - Skin Tone Support

enum SkinTone: String, CaseIterable {
    case light = "\u{1F3FB}"
    case mediumLight = "\u{1F3FC}"
    case medium = "\u{1F3FD}"
    case mediumDark = "\u{1F3FE}"
    case dark = "\u{1F3FF}"
}

enum EmojiSkinTone {
    /// Check if an emoji supports skin tone modifiers by testing whether
    /// appending a modifier actually changes its rendered form.
    static func supportsSkinTone(_ emoji: String) -> Bool {
        // Strip any existing skin tone modifier to get the base
        let base = stripSkinTone(emoji)
        // An emoji supports skin tones if it contains an Emoji_Modifier_Base scalar
        return base.unicodeScalars.contains { scalar in
            scalar.properties.isEmojiModifierBase
        }
    }

    /// Return the base emoji without any skin tone modifier.
    static func stripSkinTone(_ emoji: String) -> String {
        let skinToneScalars: Set<Unicode.Scalar> = [
            Unicode.Scalar(0x1F3FB)!,
            Unicode.Scalar(0x1F3FC)!,
            Unicode.Scalar(0x1F3FD)!,
            Unicode.Scalar(0x1F3FE)!,
            Unicode.Scalar(0x1F3FF)!,
        ]
        var scalars = Array(emoji.unicodeScalars)
        scalars.removeAll { skinToneScalars.contains($0) }
        return String(String.UnicodeScalarView(scalars))
    }

    /// Generate all skin tone variants for a base emoji (including the default yellow).
    /// Returns: [base, light, mediumLight, medium, mediumDark, dark]
    static func variants(for emoji: String) -> [String] {
        let base = stripSkinTone(emoji)
        guard supportsSkinTone(base) else { return [emoji] }

        var results = [base]
        for tone in SkinTone.allCases {
            results.append(applyTone(tone, to: base))
        }
        return results
    }

    /// Apply a skin tone modifier to a base emoji.
    /// Inserts the modifier after the first Emoji_Modifier_Base scalar.
    private static func applyTone(_ tone: SkinTone, to base: String) -> String {
        let modifier = tone.rawValue.unicodeScalars.first!
        var scalars: [Unicode.Scalar] = []
        var applied = false
        for scalar in base.unicodeScalars {
            scalars.append(scalar)
            if !applied && scalar.properties.isEmojiModifierBase {
                scalars.append(modifier)
                applied = true
            }
        }
        return String(String.UnicodeScalarView(scalars))
    }
}

enum EmojiData {
    static let categories: [EmojiCategory] = [
        EmojiCategory(id: "smileys", icon: "😀", emojis: [
            "😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃",
            "😉", "😊", "😇", "🥰", "😍", "🤩", "😘", "😗", "😚", "😙",
            "🥲", "😋", "😛", "😜", "🤪", "😝", "🤑", "🤗", "🤭", "🤫",
            "🤔", "🫡", "🤐", "🤨", "😐", "😑", "😶", "🫥", "😏", "😒",
            "🙄", "😬", "🤥", "😌", "😔", "😪", "🤤", "😴", "😷", "🤒",
            "🤕", "🤢", "🤮", "🥵", "🥶", "🥴", "😵", "🤯", "🤠", "🥳",
            "🥸", "😎", "🤓", "🧐", "😕", "🫤", "😟", "🙁", "😮", "😯",
            "😲", "😳", "🥺", "🥹", "😦", "😧", "😨", "😰", "😥", "😢",
            "😭", "😱", "😖", "😣", "😞", "😓", "😩", "😫", "🥱", "😤",
            "😡", "😠", "🤬", "😈", "👿", "💀", "☠️", "💩", "🤡", "👹",
            "👺", "👻", "👽", "👾", "🤖", "😺", "😸", "😹", "😻", "😼",
            "😽", "🙀", "😿", "😾",
        ]),
        EmojiCategory(id: "people", icon: "👋", emojis: [
            "👋", "🤚", "🖐️", "✋", "🖖", "🫱", "🫲", "🫳", "🫴", "🫷",
            "🫸", "👌", "🤌", "🤏", "✌️", "🤞", "🫰", "🤟", "🤘", "🤙",
            "👈", "👉", "👆", "🖕", "👇", "☝️", "🫵", "👍", "👎", "✊",
            "👊", "🤛", "🤜", "👏", "🙌", "🫶", "👐", "🤲", "🤝", "🙏",
            "✍️", "💅", "🤳", "💪", "🦾", "🦿", "🦵", "🦶", "👂", "🦻",
            "👃", "🧠", "🫀", "🫁", "🦷", "🦴", "👀", "👁️", "👅", "👄",
            "🫦", "👶", "🧒", "👦", "👧", "🧑", "👱", "👨", "🧔", "👩",
            "🧓", "👴", "👵", "🙍", "🙎", "🙅", "🙆", "💁", "🙋", "🧏",
            "🙇", "🤦", "🤷", "👮", "🕵️", "💂", "🥷", "👷", "🫅", "🤴",
            "👸", "👳", "👲", "🧕", "🤵", "👰", "🤰", "🫃", "🫄", "🤱",
            "👼", "🎅", "🤶", "🦸", "🦹", "🧙", "🧚", "🧛", "🧜", "🧝",
            "🧞", "🧟", "🧌", "💆", "💇", "🚶", "🧍", "🧎", "🏃", "💃",
            "🕺", "🕴️", "👯", "🧖", "👪", "👫", "👬", "👭",
        ]),
        EmojiCategory(id: "animals", icon: "🐱", emojis: [
            "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐻‍❄️", "🐨",
            "🐯", "🦁", "🐮", "🐷", "🐽", "🐸", "🐵", "🙈", "🙉", "🙊",
            "🐒", "🐔", "🐧", "🐦", "🐤", "🐣", "🐥", "🦆", "🦅", "🦉",
            "🦇", "🐺", "🐗", "🐴", "🦄", "🐝", "🪱", "🐛", "🦋", "🐌",
            "🐞", "🐜", "🪰", "🪲", "🪳", "🦟", "🦗", "🕷️", "🕸️", "🦂",
            "🐢", "🐍", "🦎", "🦖", "🦕", "🐙", "🦑", "🦐", "🦞", "🦀",
            "🪸", "🐡", "🐠", "🐟", "🐬", "🐳", "🐋", "🦈", "🐊", "🐅",
            "🐆", "🦓", "🫏", "🦍", "🦧", "🦣", "🐘", "🦛", "🦏", "🐪",
            "🐫", "🦒", "🦘", "🦬", "🐃", "🐂", "🐄", "🐎", "🐖", "🐏",
            "🐑", "🦙", "🐐", "🦌", "🐕", "🐩", "🦮", "🐕‍🦺", "🐈", "🐈‍⬛",
            "🪶", "🐓", "🦃", "🦤", "🦚", "🦜", "🦢", "🪿", "🦩", "🕊️",
            "🐇", "🦝", "🦨", "🦡", "🦫", "🦦", "🦥", "🐁", "🐀", "🐿️",
            "🦔", "🐾", "🐉", "🐲", "🌵", "🎄", "🌲", "🌳", "🌴", "🪵",
            "🌱", "🌿", "☘️", "🍀", "🎍", "🪴", "🎋", "🍃", "🍂", "🍁",
            "🪺", "🪹", "🍄", "🌾", "💐", "🌷", "🌹", "🥀", "🌺", "🌸",
            "🌼", "🌻", "🌞", "🌝", "🌛", "🌜", "🌚", "🌕", "🌖", "🌗",
            "🌘", "🌑", "🌒", "🌓", "🌔", "🌙", "🌎", "🌍", "🌏", "🪐",
            "💫", "⭐", "🌟", "✨", "⚡", "☄️", "💥", "🔥", "🌪️", "🌈",
            "☀️", "🌤️", "⛅", "🌥️", "☁️", "🌦️", "🌧️", "⛈️", "🌩️", "🌨️",
            "❄️", "☃️", "⛄", "🌬️", "💨", "💧", "💦", "🫧", "☔", "☂️",
            "🌊", "🌫️",
        ]),
        EmojiCategory(id: "food", icon: "🍕", emojis: [
            "🍏", "🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🫐",
            "🍈", "🍒", "🍑", "🥭", "🍍", "🥥", "🥝", "🍅", "🍆", "🥑",
            "🥦", "🫑", "🥬", "🥒", "🌶️", "🫚", "🧄", "🧅", "🥔", "🍠",
            "🫘", "🥐", "🍞", "🥖", "🥨", "🧀", "🥚", "🍳", "🧈", "🥞",
            "🧇", "🥓", "🥩", "🍗", "🍖", "🦴", "🌭", "🍔", "🍟", "🍕",
            "🫓", "🥪", "🥙", "🧆", "🌮", "🌯", "🫔", "🥗", "🥘", "🫕",
            "🥫", "🍝", "🍜", "🍲", "🍛", "🍣", "🍱", "🥟", "🦪", "🍤",
            "🍙", "🍚", "🍘", "🍥", "🥠", "🥮", "🍢", "🍡", "🍧", "🍨",
            "🍦", "🥧", "🧁", "🍰", "🎂", "🍮", "🍭", "🍬", "🍫", "🍿",
            "🍩", "🍪", "🌰", "🥜", "🍯", "🥛", "🍼", "🫖", "☕", "🍵",
            "🧃", "🥤", "🧋", "🫙", "🍶", "🍺", "🍻", "🥂", "🍷", "🫗",
            "🥃", "🍸", "🍹", "🧉", "🍾", "🧊", "🥄", "🍴", "🍽️", "🥣",
            "🥡", "🥢",
        ]),
        EmojiCategory(id: "travel", icon: "🚀", emojis: [
            "🚗", "🚕", "🚙", "🚌", "🚎", "🏎️", "🚓", "🚑", "🚒", "🚐",
            "🛻", "🚚", "🚛", "🚜", "🦯", "🦽", "🦼", "🛴", "🚲", "🛵",
            "🏍️", "🛺", "🚔", "🚍", "🚘", "🚖", "🛞", "🚡", "🚠", "🚟",
            "🚃", "🚋", "🚞", "🚝", "🚄", "🚅", "🚈", "🚂", "🚆", "🚇",
            "🚊", "🚉", "✈️", "🛫", "🛬", "🛩️", "💺", "🛰️", "🚀", "🛸",
            "🚁", "🛶", "⛵", "🚤", "🛥️", "🛳️", "⛴️", "🚢", "⚓", "🪝",
            "⛽", "🚧", "🚦", "🚥", "🚏", "🗺️", "🗿", "🗽", "🗼", "🏰",
            "🏯", "🏟️", "🎡", "🎢", "🎠", "⛲", "⛱️", "🏖️", "🏝️", "🏜️",
            "🌋", "⛰️", "🏔️", "🗻", "🏕️", "⛺", "🛖", "🏠", "🏡", "🏘️",
            "🏚️", "🏗️", "🏭", "🏢", "🏬", "🏣", "🏤", "🏥", "🏦", "🏨",
            "🏪", "🏫", "🏩", "💒", "🏛️", "⛪", "🕌", "🕍", "🛕", "🕋",
            "⛩️", "🛤️", "🛣️", "🗾", "🎑", "🏞️", "🌅", "🌄", "🌠", "🎇",
            "🎆", "🌇", "🌆", "🏙️", "🌃", "🌌", "🌉", "🌁",
        ]),
        EmojiCategory(id: "activities", icon: "⚽", emojis: [
            "⚽", "🏀", "🏈", "⚾", "🥎", "🎾", "🏐", "🏉", "🥏", "🎱",
            "🪀", "🏓", "🏸", "🏒", "🏑", "🥍", "🏏", "🪃", "🥅", "⛳",
            "🪁", "🏹", "🎣", "🤿", "🥊", "🥋", "🎽", "🛹", "🛼", "🛷",
            "⛸️", "🥌", "🎿", "⛷️", "🏂", "🪂", "🏋️", "🤼", "🤸", "⛹️",
            "🤺", "🤾", "🏌️", "🏇", "🧘", "🏄", "🏊", "🤽", "🚣", "🧗",
            "🚵", "🚴", "🏆", "🥇", "🥈", "🥉", "🏅", "🎖️", "🏵️", "🎗️",
            "🎪", "🤹", "🎭", "🩰", "🎨", "🎬", "🎤", "🎧", "🎼", "🎹",
            "🥁", "🪘", "🎷", "🎺", "🪗", "🎸", "🪕", "🎻", "🪈", "🎲",
            "♟️", "🎯", "🎳", "🎮", "🕹️", "🧩", "🎰", "🎁", "🎀", "🎊",
            "🎉", "🎈", "🪅", "🪩", "🎐", "🎏", "🎎", "🎑", "🧧",
        ]),
        EmojiCategory(id: "objects", icon: "💡", emojis: [
            "👓", "🕶️", "🥽", "🥼", "🦺", "👔", "👕", "👖", "🧣", "🧤",
            "🧥", "🧦", "👗", "👘", "🥻", "🩱", "🩲", "🩳", "👙", "👚",
            "👛", "👜", "👝", "🛍️", "🎒", "🩴", "👞", "👟", "🥾", "🥿",
            "👠", "👡", "👢", "👑", "👒", "🎩", "🎓", "🧢", "🪖",
            "⛑️", "📿", "💄", "💍", "💎", "🔇", "🔈", "🔉", "🔊", "📢",
            "📣", "📯", "🔔", "🔕", "🎵", "🎶", "🎙️", "🎚️", "🎛️", "📻",
            "📱", "📲", "☎️", "📞", "📟", "📠", "🔋", "🪫", "🔌", "💻",
            "🖥️", "🖨️", "⌨️", "🖱️", "🖲️", "💽", "💾", "💿", "📀", "🧮",
            "🎥", "🎞️", "📽️", "🎬", "📺", "📷", "📸", "📹", "📼", "🔍",
            "🔎", "🕯️", "💡", "🔦", "🏮", "🪔", "📔", "📕", "📖", "📗",
            "📘", "📙", "📚", "📓", "📒", "📃", "📜", "📄", "📰", "🗞️",
            "📑", "🔖", "🏷️", "💰", "🪙", "💴", "💵", "💶", "💷", "💸",
            "💳", "🧾", "💹", "✉️", "📧", "📨", "📩", "📤", "📥", "📦",
            "📫", "📪", "📬", "📭", "📮", "🗳️", "✏️", "✒️", "🖋️", "🖊️",
            "🖌️", "🖍️", "📝", "💼", "📁", "📂", "🗂️", "📅", "📆", "🗒️",
            "🗓️", "📇", "📈", "📉", "📊", "📋", "📌", "📍", "📎", "🖇️",
            "📏", "📐", "✂️", "🗃️", "🗄️", "🗑️", "🔒", "🔓", "🔏", "🔐",
            "🔑", "🗝️", "🔨", "🪓", "⛏️", "⚒️", "🛠️", "🗡️", "⚔️", "💣",
            "🏹", "🛡️", "🪚", "🔧", "🪛", "🔩", "⚙️", "🗜️", "⚖️",
            "🔗", "⛓️", "🪝", "🧰", "🧲", "🪜", "⚗️", "🧪", "🧫",
            "🧬", "🔬", "🔭", "📡", "💉", "🩸", "💊", "🩹", "🩼", "🩺",
            "🩻", "🚪", "🛗", "🪞", "🪟", "🛏️", "🛋️", "🪑", "🚽", "🪠",
            "🚿", "🛁", "🪤", "🪒", "🧴", "🧷", "🧹", "🧺", "🧻", "🪣",
            "🧼", "🫧", "🪥", "🧽", "🧯", "🛒", "🚬", "⚰️", "🪦", "⚱️",
            "🧿", "🪬", "🗿",
        ]),
        EmojiCategory(id: "symbols", icon: "🔣", emojis: [
            "❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💔",
            "❤️‍🔥", "❤️‍🩹", "❣️", "💕", "💞", "💓", "💗", "💖", "💘", "💝",
            "💟", "☮️", "✝️", "☪️", "🕉️", "☸️", "✡️", "🔯", "🕎", "☯️",
            "☦️", "🛐", "⛎", "♈", "♉", "♊", "♋", "♌", "♍", "♎",
            "♏", "♐", "♑", "♒", "♓", "🆔", "⚛️", "🉑", "☢️", "☣️",
            "📴", "📳", "🈶", "🈚", "🈸", "🈺", "🈷️", "✴️", "🆚", "💮",
            "🉐", "㊙️", "㊗️", "🈴", "🈵", "🈹", "🈲", "🅰️", "🅱️", "🆎",
            "🆑", "🅾️", "🆘", "❌", "⭕", "🛑", "⛔", "📛", "🚫", "💯",
            "💢", "♨️", "🚷", "🚯", "🚳", "🚱", "🔞", "📵", "🚭", "❗",
            "❕", "❓", "❔", "‼️", "⁉️", "🔅", "🔆", "〽️", "⚠️", "🚸",
            "🔱", "⚜️", "🔰", "♻️", "✅", "🈯", "💹", "❇️", "✳️", "❎",
            "🌐", "💠", "Ⓜ️", "🌀", "💤", "🏧", "🚾", "♿", "🅿️", "🛗",
            "🈳", "🈂️", "🛂", "🛃", "🛄", "🛅", "🚹", "🚺", "🚼", "⚧️",
            "🚻", "🚮", "🎦", "📶", "🈁", "🔣", "ℹ️", "🔤", "🔡", "🔠",
            "🆖", "🆗", "🆙", "🆒", "🆕", "🆓", "0️⃣", "1️⃣", "2️⃣", "3️⃣",
            "4️⃣", "5️⃣", "6️⃣", "7️⃣", "8️⃣", "9️⃣", "🔟", "#️⃣", "*️⃣", "⏏️",
            "▶️", "⏸️", "⏯️", "⏹️", "⏺️", "⏭️", "⏮️", "⏩", "⏪", "⏫",
            "⏬", "◀️", "🔼", "🔽", "➡️", "⬅️", "⬆️", "⬇️", "↗️", "↘️",
            "↙️", "↖️", "↕️", "↔️", "↩️", "↪️", "⤴️", "⤵️", "🔀", "🔁",
            "🔂", "🔄", "🔃", "➕", "➖", "➗", "✖️", "🟰",
            "♾️", "💲", "💱", "™️", "©️", "®️", "〰️", "➰", "➿", "🔚",
            "🔙", "🔛", "🔝", "🔜", "✔️", "☑️", "🔘", "🔴", "🟠", "🟡",
            "🟢", "🔵", "🟣", "⚫", "⚪", "🟤", "🔺", "🔻", "🔸", "🔹",
            "🔶", "🔷", "🔳", "🔲", "▪️", "▫️", "◾", "◽", "◼️", "◻️",
            "🟥", "🟧", "🟨", "🟩", "🟦", "🟪", "⬛", "⬜", "🟫",
            "💬", "💭", "🗯️",
            "♠️", "♣️", "♥️", "♦️", "🃏", "🎴", "🀄",
        ]),
        EmojiCategory(id: "flags", icon: "🏁", emojis: [
            "🏁", "🚩", "🎌", "🏴", "🏳️", "🏳️‍🌈", "🏳️‍⚧️", "🏴‍☠️",
            "🇺🇸", "🇬🇧", "🇨🇦", "🇦🇺", "🇩🇪", "🇫🇷", "🇪🇸", "🇮🇹",
            "🇯🇵", "🇰🇷", "🇨🇳", "🇮🇳", "🇧🇷", "🇲🇽", "🇷🇺", "🇿🇦",
            "🇦🇷", "🇨🇱", "🇨🇴", "🇵🇪", "🇻🇪", "🇪🇨", "🇧🇴", "🇵🇾",
            "🇺🇾", "🇵🇦", "🇨🇷", "🇬🇹", "🇭🇳", "🇸🇻", "🇳🇮", "🇨🇺",
            "🇩🇴", "🇭🇹", "🇯🇲", "🇹🇹", "🇧🇸", "🇧🇧", "🇵🇷", "🇦🇬",
            "🇸🇪", "🇳🇴", "🇩🇰", "🇫🇮", "🇮🇸", "🇮🇪", "🇳🇱", "🇧🇪",
            "🇨🇭", "🇦🇹", "🇵🇹", "🇬🇷", "🇵🇱", "🇨🇿", "🇷🇴", "🇭🇺",
            "🇺🇦", "🇹🇷", "🇮🇱", "🇸🇦", "🇦🇪", "🇶🇦", "🇰🇼", "🇧🇭",
            "🇴🇲", "🇯🇴", "🇱🇧", "🇮🇶", "🇮🇷", "🇪🇬", "🇳🇬", "🇰🇪",
            "🇪🇹", "🇬🇭", "🇹🇿", "🇲🇦", "🇹🇳", "🇩🇿", "🇱🇾", "🇸🇩",
            "🇹🇭", "🇻🇳", "🇮🇩", "🇲🇾", "🇵🇭", "🇸🇬", "🇲🇲", "🇰🇭",
            "🇱🇦", "🇧🇩", "🇱🇰", "🇳🇵", "🇵🇰", "🇦🇫", "🇲🇻", "🇲🇳",
            "🇳🇿", "🇫🇯", "🇵🇬", "🇹🇴", "🇼🇸", "🇻🇺",
            "🇺🇳",
        ]),
    ]
}
