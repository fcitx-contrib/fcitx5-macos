#pragma once

#include <string>
#include <fcitx-config/configuration.h>
#include <nlohmann/json.hpp>

#include "config-public.h"

constexpr char globalConfigPath[] = "fcitx://config/global";
constexpr char addonConfigPrefix[] = "fcitx://config/addon/";
constexpr char imConfigPrefix[] = "fcitx://config/inputmethod/";

/// Convert configuration into a json object.
nlohmann::json configToJson(const fcitx::Configuration &config);
