#!/bin/zsh
set -xeu

user="$1"
remove_user_data="$2"
APP_DIR="/Library/Input Methods/Fcitx5.app"
DATA_DIR="/Users/$user/Library/fcitx5"
CONFIG_DIR="/Users/$user/.config/fcitx5"
LOCAL_DIR="/Users/$user/.local/share/fcitx5"

rm -rf "$APP_DIR"
rm -rf "$DATA_DIR"
rm -rf "$CONFIG_DIR"

if [ "$remove_user_data" = "true" ]; then
  rm -rf "$LOCAL_DIR"
fi

killall Fcitx5
