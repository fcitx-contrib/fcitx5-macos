#!/bin/zsh
set -xeu

user="$1"
tar_ball="$2"
INSTALL_DIR="/Library/Input Methods"
APP_DIR="$INSTALL_DIR/Fcitx5.app"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

# Don't remove files that must exist (which will be overwritten) as that will put Fcitx5 in a registered-but-not-listed state.
rm -rf "$APP_DIR"/Contents/{bin,include,lib,share,Resources}
if ls "$APP_DIR"/Contents/MacOS/Fcitx5.*; then # Debug symbols
    rm -rf "$APP_DIR"/Contents/MacOS/Fcitx5.*
fi
tar xjvf "$tar_ball" -C "$INSTALL_DIR"
rm -f "$tar_ball"

major_version=$(sw_vers -productVersion | cut -d. -f1)
if (( major_version >= 26 )); then
  cp "$RESOURCES_DIR/menu_icon_26.pdf" "$RESOURCES_DIR/menu_icon.pdf"
else
  cp "$RESOURCES_DIR/menu_icon_15.pdf" "$RESOURCES_DIR/menu_icon.pdf"
fi

xattr -dr com.apple.quarantine "$APP_DIR"
codesign --force --sign - --deep "$APP_DIR"

cd "$RESOURCES_DIR"
im=$(su -m "$user" -c "./get_im")
# Switching out is necessary, otherwise it doesn't show menu
# Not sure which one so try both.
su -m "$user" -c "./switch_im com.apple.keylayout.ABC"
su -m "$user" -c "./switch_im com.apple.keylayout.US"
killall Fcitx5

# This input source ID comes from Carbon API:
# import Carbon

# let bundleId = "org.fcitx.inputmethod.Fcitx5"
# let conditions = NSMutableDictionary()
# conditions.setValue(bundleId, forKey: kTISPropertyBundleID as String)
# if let array = TISCreateInputSourceList(conditions, true)?.takeRetainedValue()
#   as? [TISInputSource]
# {
#   for inputSource in array {
#     if let ptr = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) {
#       let inputSourceID = Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
#       print(inputSourceID)
#     }
#   }
# }

# The rule to construct seems:
# org.fcitx.inputmethod.Fcitx5 is our CFBundleIdentifier;
# The rest is the keys under tsInputModeListKey trimming the org.fcitx.inputmethod.

# Switch back.
su -m "$user" -c "./switch_im $im"
