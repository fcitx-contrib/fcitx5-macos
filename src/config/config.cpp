#include <string>
#include <fcitx-config/configuration.h>
#include <fcitx-config/rawconfig.h>
#include <fcitx-utils/stringutils.h>
#include <fcitx/inputmethodengine.h>
#include <fcitx/inputmethodentry.h>
#include <fcitx/inputmethodmanager.h>

#include "fcitx.h"
#include "config.h"

using namespace std::literals::string_literals;

static std::string getConfig(const std::string &uri);
static nlohmann::json &jsonLocate(nlohmann::json &j, const std::string &group,
                                  const std::string &option);
static nlohmann::json configValueToJson(const fcitx::RawConfig &config);
static nlohmann::json configSpecToJson(const fcitx::RawConfig &config);
static nlohmann::json configSpecToJson(const fcitx::Configuration &config);
static void mergeSpecAndValue(nlohmann::json &specJson,
                              const nlohmann::json &valueJson);
static fcitx::RawConfig jsonToRawConfig(const nlohmann::json &);
static std::tuple<std::string, std::string>
parseAddonUri(const std::string &uri);

std::string getConfig(const char *uri) { return getConfig(std::string(uri)); }

std::string getConfig(const std::string &uri) {
    FCITX_DEBUG() << "getConfig " << uri;
    return with_fcitx([&](Fcitx &fcitx) -> nlohmann::json {
               if (uri == globalConfigPath) {
                   auto &config = fcitx.instance()->globalConfig().config();
                   return configToJson(config);
               } else if (uri.starts_with(addonConfigPrefix)) {
                   auto [addonName, subPath] = parseAddonUri(uri);
                   auto *addonInfo = fcitx.addonMgr().addonInfo(addonName);
                   if (!addonInfo) {
                       return {{"ERROR",
                                "Addon \""s + addonName + "\" does not exist"}};
                   } else if (!addonInfo->isConfigurable()) {
                       return {{"ERROR", "Addon \""s + addonName +
                                             "\" is not configurable"}};
                   }
                   auto *addon = fcitx.addonMgr().addon(addonName, true);
                   if (!addon) {
                       return {{"ERROR", "Failed to get config for addon \""s +
                                             addonName + "\""}};
                   }
                   auto *config = subPath.empty()
                                      ? addon->getConfig()
                                      : addon->getSubConfig(subPath);
                   if (!config) {
                       return {{"ERROR", "Failed to get config for addon \""s +
                                             addonName + "\""}};
                   }
                   return configToJson(*config);
               } else if (uri.starts_with(imConfigPrefix)) {
                   auto imName = uri.substr(sizeof(imConfigPrefix) - 1);
                   auto *entry =
                       fcitx.instance()->inputMethodManager().entry(imName);
                   if (!entry) {
                       return {{"ERROR", "Input method \""s + imName +
                                             "\" doesn't exist"}};
                   }
                   if (!entry->isConfigurable()) {
                       return {{"ERROR", "Input method \""s + imName +
                                             "\" is not configurable"}};
                   }
                   auto *engine = fcitx.instance()->inputMethodEngine(imName);
                   if (!engine) {
                       return {{"ERROR",
                                "Failed to get engine for input method \""s +
                                    imName + "\""}};
                   }
                   auto *config = engine->getConfigForInputMethod(*entry);
                   if (!config) {
                       return {{"ERROR",
                                "Failed to get config for input method \""s +
                                    imName + "\""}};
                   }
                   return configToJson(*config);
               } else {
                   return {{"ERROR", "Bad config URI \""s + uri + "\""}};
               }
           })
        .dump();
}

bool setConfig(const char *uri_, const char *json_) {
    FCITX_DEBUG() << "setConfig " << uri_;
    auto config = jsonToRawConfig(nlohmann::json::parse(json_));
    auto uri = std::string(uri_);
    if (uri == globalConfigPath) {
        return with_fcitx([&](Fcitx &fcitx) {
            auto &gc = fcitx.instance()->globalConfig();
            gc.load(config, true);
            if (gc.safeSave()) {
                fcitx.instance()->reloadConfig();
                return true;
            } else {
                return false;
            }
        });
    } else if (uri.starts_with(addonConfigPrefix)) {
        return with_fcitx([&](Fcitx &fcitx) {
            auto [addonName, subPath] = parseAddonUri(uri);
            auto *addon =
                fcitx.instance()->addonManager().addon(addonName, true);
            if (addon) {
                FCITX_DEBUG() << "Saving addon config to: " << uri;
                if (subPath.empty()) {
                    addon->setConfig(config);
                } else {
                    addon->setSubConfig(subPath, config);
                }
                return true;
            } else {
                FCITX_ERROR() << "Failed to get addon";
                return false;
            }
        });
    } else if (uri.starts_with(imConfigPrefix)) {
        return with_fcitx([&](Fcitx &fcitx) {
            auto im = uri.substr(sizeof(imConfigPrefix) - 1);
            const auto *entry =
                fcitx.instance()->inputMethodManager().entry(im);
            auto *engine = fcitx.instance()->inputMethodEngine(im);
            if (entry && engine) {
                FCITX_DEBUG() << "Saving input method config to: " << uri;
                engine->setConfigForInputMethod(*entry, config);
                return true;
            } else {
                FCITX_ERROR() << "Failed to get input method";
                return false;
            }
        });
    } else {
        return false;
    }
}

void jsonFillRawConfigValues(const nlohmann::json &j,
                             fcitx::RawConfig &config) {
    if (j.is_string()) {
        config = j.get<std::string>();
        return;
    }
    if (j.is_object()) {
        for (const auto [key, subJson] : j.items()) {
            auto subConfig = config.get(key, true);
            jsonFillRawConfigValues(subJson, *subConfig);
        }
        return;
    }
    FCITX_FATAL() << "Unknown value json: " << j.dump();
}

fcitx::RawConfig jsonToRawConfig(const nlohmann::json &j) {
    fcitx::RawConfig config;
    jsonFillRawConfigValues(j, config);
    return config;
}

nlohmann::json &jsonLocate(nlohmann::json &j, const std::string &groupPath,
                           const std::string &option) {
    auto paths = fcitx::stringutils::split(groupPath, "$");
    paths.pop_back(); // remove type
    paths.push_back(option);
    nlohmann::json *cur = &j;
    for (const auto &part : paths) {
        auto &children =
            *cur->emplace("Children", nlohmann::json::array()).first;
        bool exist = false;
        for (auto &child : children) {
            if (child["Option"] == part) {
                exist = true;
                cur = &child;
                break;
            }
        }
        if (!exist) {
            cur = &children.emplace_back(nlohmann::json::object());
        }
    }
    return *cur;
}

nlohmann::json configValueToJson(const fcitx::RawConfig &config) {
    if (!config.hasSubItems()) {
        return nlohmann::json(config.value());
    }
    nlohmann::json j;
    for (auto &subItem : config.subItems()) {
        auto subConfig = config.get(subItem);
        j[subItem] = configValueToJson(*subConfig);
    }
    return j;
}

nlohmann::json configValueToJson(const fcitx::Configuration &config) {
    fcitx::RawConfig raw;
    config.save(raw);
    return configValueToJson(raw);
}

nlohmann::json configSpecToJson(const fcitx::RawConfig &config) {
    // first level  -> Path1$Path2$...$Path_n$ConfigType
    // second level -> OptionName
    nlohmann::json spec;
    auto groups = config.subItems();
    for (const auto &group : groups) {
        auto groupConfig = config.get(group);
        auto options = groupConfig->subItems();
        for (const auto &option : options) {
            auto optionConfig = groupConfig->get(option);
            nlohmann::json &optSpec = jsonLocate(spec, group, option);
            optSpec["Option"] = option;
            optionConfig->visitSubItems(
                [&](const fcitx::RawConfig &config, const std::string &path) {
                    optSpec[path] = configValueToJson(config);
                    return true;
                });
        }
    }
    return spec;
}

void mergeSpecAndValue(nlohmann::json &specJson,
                       const nlohmann::json &valueJson) {
    if (specJson.find("Type") != specJson.end()) {
        specJson["Value"] = valueJson;
    }
    for (auto &child : specJson["Children"]) {
        const auto iter = valueJson.find(child["Option"]);
        if (iter != valueJson.end()) {
            mergeSpecAndValue(child, *iter);
        }
    }
}

nlohmann::json configSpecToJson(const fcitx::Configuration &config) {
    fcitx::RawConfig rawDesc;
    config.dumpDescription(rawDesc);
    return configSpecToJson(rawDesc);
}

nlohmann::json configToJson(const fcitx::Configuration &config) {
    // specJson contains config definitions
    auto specJson = configSpecToJson(config);
    // valueJson contains actual values that user could change
    auto valueJson = configValueToJson(config);
    mergeSpecAndValue(specJson, valueJson);
    return specJson;
}

static std::tuple<std::string, std::string>
parseAddonUri(const std::string &uri) {
    auto addon = uri.substr(sizeof(addonConfigPrefix) - 1);
    auto pos = addon.find('/');
    if (pos == std::string::npos) {
        return {addon, ""};
    } else {
        return {addon.substr(0, pos), addon.substr(pos + 1)};
    }
}
