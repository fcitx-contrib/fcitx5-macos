// swift-format-ignore-file
import Foundation

private let Chinese = NSLocalizedString("Chinese", comment: "")
private let English = NSLocalizedString("English", comment: "")
private let Korean = NSLocalizedString("Korean", comment: "")
private let Japanese = NSLocalizedString("Japanese", comment: "")
private let Sinhala = NSLocalizedString("Sinhala", comment: "")
private let Thai = NSLocalizedString("Thai", comment: "")
private let Vietnamese = NSLocalizedString("Vietnamese", comment: "")

private let Generic = NSLocalizedString("Generic", comment: "")
private let Other = NSLocalizedString("Other", comment: "")

private let tableExtra = "fcitx/fcitx5-table-extra"

// NOTE: Currently, It is assumed that all official plugins contain an arch-independent data part,
// which is named as plugin-any.tar.bz2.
// (This will probably remain true for a long time, because at least .conf is there.)
// Should this assumption change in the future, please update install() in plugin.swift.
let officialPlugins = [
  Plugin(id: "anthy", category: Japanese, native: true, github: "fcitx/fcitx5-anthy"),
  Plugin(id: "array", category: Chinese, native: false, github: tableExtra, dependencies: ["chinese-addons"]),
  Plugin(id: "boshiamy", category: Chinese, native: false, github: tableExtra, dependencies: ["chinese-addons"]),
  Plugin(id: "cangjie", category: Chinese, native: false, github: tableExtra, dependencies: ["chinese-addons"]),
  Plugin(id: "cantonese", category: Chinese, native: false, github: tableExtra, dependencies: ["chinese-addons"]),
  Plugin(id: "chinese-addons", category: Chinese, native: true, github: "fcitx/fcitx5-chinese-addons"),
  Plugin(id: "hallelujah", category: English, native: true, github: "fcitx-contrib/fcitx5-hallelujah"),
  Plugin(id: "lua", category: Other, native: true, github: "fcitx/fcitx5-lua"),
  Plugin(id: "quick", category: Chinese, native: false, github: tableExtra, dependencies: ["chinese-addons"]),
  Plugin(id: "mozc", category: Japanese, native: true, github: "fcitx/mozc"),
  Plugin(id: "rime", category: Generic, native: true, github: "fcitx/fcitx5-rime"),
  Plugin(id: "skk", category: Japanese, native: true, github: "fcitx/fcitx5-skk"),
  Plugin(id: "stroke", category: Chinese, native: false, github: tableExtra, dependencies: ["chinese-addons"]),
  Plugin(id: "thai", category: Thai, native: true, github: "fcitx/fcitx5-libthai"),
  Plugin(id: "unikey", category: Vietnamese, native: true, github: "fcitx/fcitx5-unikey"),
  Plugin(id: "wu", category: Chinese, native: false, github: tableExtra, dependencies: ["chinese-addons"]),
  Plugin(id: "wubi86", category: Chinese, native: false, github: tableExtra, dependencies: ["chinese-addons"]),
  Plugin(id: "wubi98", category: Chinese, native: false, github: tableExtra, dependencies: ["chinese-addons"]),
  Plugin(id: "zhengma", category: Chinese, native: false, github: tableExtra, dependencies: ["chinese-addons"]),
  Plugin(id: "chewing", category: Chinese, native: true, github: "fcitx/fcitx5-chewing"),
  Plugin(id: "hangul", category: Korean, native: true, github: "fcitx/fcitx5-hangul"),
  Plugin(id: "sayura", category: Sinhala, native: true, github: "fcitx/fcitx5-sayura"),
  Plugin(id: "bamboo", category: Vietnamese, native: true, github: "fcitx/fcitx5-bamboo"),
]
