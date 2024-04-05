/*
This file aims to convert locale from system to a string that fcitx5 recognizes.
Given fcitx5 has a limited number of locales in po/, we do not need to convert all locales.
User sets system locale in System Settings -> General -> Language & Region.
The first language in Preferred Languages and the Region count.
However, if the language is not commonly used in the region, it results in funny behavior.
e.g. 简体中文 with US region, the system locale is zh-Hans_US, but we need zh_CN.
In this situation, script is Hans (otherwise nil), and identifier = languageCode-script_regionCode
We also need zh_SG to fall back to zh_CN.
*/

import Foundation
import Logging

func getLocale() -> String {
  let locale = Locale.current
  FCITX_INFO("System locale = \(locale.identifier)")

  if let languageCode = locale.language.languageCode?.identifier {
    if languageCode == "zh" {
      if let scriptCode = locale.language.script?.identifier {
        if scriptCode == "Hans" {
          return "zh_CN"
        } else {
          return "zh_TW"
        }
      }
      if locale.region?.identifier == "SG" {
        return "zh_CN"
      } else {
        return "zh_TW"
      }
    }
    return languageCode
  }
  return "C"
}
