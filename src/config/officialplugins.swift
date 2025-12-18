// swift-format-ignore-file
import Foundation

private let Amharic = NSLocalizedString("Amharic", comment: "")
private let Arabic = NSLocalizedString("Arabic", comment: "")
private let Chinese = NSLocalizedString("Chinese", comment: "")
private let English = NSLocalizedString("English", comment: "")
private let Korean = NSLocalizedString("Korean", comment: "")
private let Japanese = NSLocalizedString("Japanese", comment: "")
private let Malayalam = NSLocalizedString("Malayalam", comment: "")
private let Russian = NSLocalizedString("Russian", comment: "")
private let Sinhala = NSLocalizedString("Sinhala", comment: "")
private let Tamil = NSLocalizedString("Tamil", comment: "")
private let Thai = NSLocalizedString("Thai", comment: "")
private let Ukrainian = NSLocalizedString("Ukrainian", comment: "")
private let Vietnamese = NSLocalizedString("Vietnamese", comment: "")

private let Generic = NSLocalizedString("Generic", comment: "")
private let Other = NSLocalizedString("Other", comment: "")

private let chineseAddons = "chinese-addons"

private let tableExtra = "fcitx/fcitx5-table-extra"
private let tableOther = "fcitx/fcitx5-table-other"

// NOTE: Currently, It is assumed that all official plugins contain an arch-independent data part,
// which is named as plugin-any.tar.bz2.
// (This will probably remain true for a long time, because at least .conf is there.)
// Should this assumption change in the future, please update install() in plugin.swift.
let officialPlugins = [
  Plugin(id: "anthy", category: Japanese, native: true, github: "fcitx/fcitx5-anthy"),
  Plugin(id: "array", category: Chinese, native: false, github: tableExtra, dependencies: [chineseAddons]),
  Plugin(id: "bamboo", category: Vietnamese, native: true, github: "fcitx/fcitx5-bamboo"),
  Plugin(id: "boshiamy", category: Chinese, native: false, github: tableExtra, dependencies: [chineseAddons]),
  Plugin(id: "cangjie", category: Chinese, native: false, github: tableExtra, dependencies: [chineseAddons]),
  Plugin(id: "cantonese", category: Chinese, native: false, github: tableExtra, dependencies: [chineseAddons]),
  Plugin(id: "chewing", category: Chinese, native: true, github: "fcitx/fcitx5-chewing"),
  Plugin(id: "chinese-addons", category: Chinese, native: true, github: "fcitx/fcitx5-chinese-addons"),
  Plugin(id: "cskk", category: Japanese, native: true, github: "fcitx/fcitx5-cskk"),
  Plugin(id: "hallelujah", category: English, native: true, github: "fcitx-contrib/fcitx5-hallelujah"),
  Plugin(id: "hangul", category: Korean, native: true, github: "fcitx/fcitx5-hangul"),
  Plugin(id: "jyutping", category: Chinese, native: true, github: "fcitx/libime-jyutping", dependencies: [chineseAddons]),
  Plugin(id: "keyman", category: Generic, native: true, github: "fcitx/fcitx5-keyman"),
  Plugin(id: "kkc", category: Japanese, native: true, github: "fcitx/fcitx5-kkc"),
  Plugin(id: "lua", category: Other, native: true, github: "fcitx/fcitx5-lua"),
  Plugin(id: "quick", category: Chinese, native: false, github: tableExtra, dependencies: [chineseAddons]),
  Plugin(id: "m17n", category: Generic, native: true, github: "fcitx/fcitx5-m17n"),
  Plugin(id: "mozc", category: Japanese, native: true, github: "fcitx/mozc"),
  Plugin(id: "rime", category: Generic, native: true, github: "fcitx/fcitx5-rime"),
  Plugin(id: "sayura", category: Sinhala, native: true, github: "fcitx/fcitx5-sayura"),
  Plugin(id: "skk", category: Japanese, native: true, github: "fcitx/fcitx5-skk"),
  Plugin(id: "stroke", category: Chinese, native: false, github: tableExtra, dependencies: [chineseAddons]),
  Plugin(id: "table-amharic", category: Amharic, native: false, github: tableOther, dependencies: [chineseAddons]),
  Plugin(id: "table-arabic", category: Arabic, native: false, github: tableOther, dependencies: [chineseAddons]),
  Plugin(id: "table-cns11643", category: Chinese, native: false, github: tableOther, dependencies: [chineseAddons]),
  Plugin(id: "table-compose", category: Other, native: false, github: tableOther, dependencies: [chineseAddons]),
  Plugin(id: "table-emoji", category: Other, native: false, github: tableOther, dependencies: [chineseAddons]),
  Plugin(id: "table-ipa-x-sampa", category: Other, native: false, github: tableOther, dependencies: [chineseAddons]),
  Plugin(id: "table-latex", category: Other, native: false, github: tableOther, dependencies: [chineseAddons]),
  Plugin(id: "table-malayalam-phonetic", category: Malayalam, native: false, github: tableOther, dependencies: [chineseAddons]),
  Plugin(id: "table-rustrad", category: Russian, native: false, github: tableOther, dependencies: [chineseAddons]),
  Plugin(id: "table-tamil-remington", category: Tamil, native: false, github: tableOther, dependencies: [chineseAddons]),
  Plugin(id: "table-thai", category: Thai, native: false, github: tableOther, dependencies: [chineseAddons]),
  Plugin(id: "table-translit", category: Russian, native: false, github: tableOther, dependencies: [chineseAddons]),
  Plugin(id: "table-translit-ua", category: Ukrainian, native: false, github: tableOther, dependencies: [chineseAddons]),
  Plugin(id: "table-viqr", category: Vietnamese, native: false, github: tableOther, dependencies: [chineseAddons]),
  Plugin(id: "table-yawerty", category: Russian, native: false, github: tableOther, dependencies: [chineseAddons]),
  Plugin(id: "thai", category: Thai, native: true, github: "fcitx/fcitx5-libthai"),
  Plugin(id: "unikey", category: Vietnamese, native: true, github: "fcitx/fcitx5-unikey"),
  Plugin(id: "wu", category: Chinese, native: false, github: tableExtra, dependencies: [chineseAddons]),
  Plugin(id: "wubi86", category: Chinese, native: false, github: tableExtra, dependencies: [chineseAddons]),
  Plugin(id: "wubi98", category: Chinese, native: false, github: tableExtra, dependencies: [chineseAddons]),
  Plugin(id: "zhengma", category: Chinese, native: false, github: tableExtra, dependencies: [chineseAddons]),
  Plugin(id: "zhuyin", category: Chinese, native: true, github: "fcitx/fcitx5-zhuyin"),
]
