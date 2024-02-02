#include <fcitx-config/configuration.h>
#include <fcitx-config/rawconfig.h>
#include <fcitx-utils/stringutils.h>
#include <fcitx/inputmethodengine.h>
#include <fcitx/inputmethodentry.h>
#include <fcitx/inputmethodmanager.h>

#include "fcitx.h"
#include "config.h"

static std::string getConfig(const std::string &uri);
static nlohmann::json &jsonLocate(nlohmann::json &j, const std::string &group,
                                  const std::string &option);
static nlohmann::json configValueToJson(const fcitx::RawConfig &config);
static nlohmann::json configValueToJson(const fcitx::Configuration &config);
static nlohmann::json configSpecToJson(const fcitx::RawConfig &config);
static nlohmann::json configSpecToJson(const fcitx::Configuration &config);
static void mergeSpecAndValue(nlohmann::json &specJson,
                              const nlohmann::json &valueJson);
static std::tuple<std::string, std::string>
parseAddonUri(const std::string &uri);

std::string getConfig(const char *uri) { return getConfig(std::string(uri)); }

std::string getConfig(const std::string &uri) {
    return with_fcitx([&](Fcitx &fcitx) -> nlohmann::json {
               if (uri == globalConfigPath) {
                   auto &config = fcitx.instance()->globalConfig().config();
                   return configToJson(config);
               } else if (fcitx::stringutils::startsWith(uri,
                                                         addonConfigPrefix)) {
                   auto [addonName, subPath] = parseAddonUri(uri);
                   auto *addonInfo = fcitx.addonMgr().addonInfo(addonName);
                   if (!addonInfo) {
                       return {{"ERROR", "addon does not exist"}};
                   } else if (!addonInfo->isConfigurable()) {
                       return {{"ERROR", "addon not configurable"}};
                   }
                   auto *addon = fcitx.addonMgr().addon(addonName, true);
                   if (!addon) {
                       return {{"ERROR", "failed to get addon"}};
                   }
                   auto *config = subPath.empty()
                                      ? addon->getConfig()
                                      : addon->getSubConfig(subPath);
                   if (!config) {
                       return {{"ERROR", "failed to get config"}};
                   }
                   return configToJson(*config);
               } else if (fcitx::stringutils::startsWith(uri, imConfigPrefix)) {
                   auto imName = uri.substr(sizeof(imConfigPrefix) - 1);
                   auto *entry =
                       fcitx.instance()->inputMethodManager().entry(imName);
                   if (!entry) {
                       return {{"ERROR", "input method doesn't exist"}};
                   }
                   if (!entry->isConfigurable()) {
                       return {{"ERROR", "input method not configurable"}};
                   }
                   auto *engine = fcitx.instance()->inputMethodEngine(imName);
                   if (!engine) {
                       return {{"ERROR", "failed to get engine"}};
                   }
                   auto *config = engine->getConfigForInputMethod(*entry);
                   if (!config) {
                       return {{"ERROR", "failed to get config"}};
                   }
                   return configToJson(*config);
               } else {
                   return {{"ERROR", "bad config uri"}};
               }
           })
        .dump();
}

nlohmann::json &jsonLocate(nlohmann::json &j, const std::string &groupPath,
                           const std::string &option) {
    auto paths = fcitx::stringutils::split(groupPath, "$");
    paths.pop_back(); // remove type
    paths.push_back(option);
    nlohmann::json *cur = &j;
    for (const auto &part : paths) {
        cur = &((*cur)[part]);
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
            auto typeField = optionConfig->get("Type");
            auto descriptionField = optionConfig->get("Description");
            auto defaultValueField = optionConfig->get("DefaultValue");
            if (!typeField || !descriptionField)
                continue;
            nlohmann::json &optSpec = jsonLocate(spec, group, option);
            optSpec["Type"] = typeField->value();
            optSpec["Description"] = descriptionField->value();
            optSpec["DefaultValue"] =
                defaultValueField ? configValueToJson(*defaultValueField)
                                  : nlohmann::json(); // null
            optionConfig->visitSubItems(
                [&](const fcitx::RawConfig &config, const std::string &path) {
                    if (path == "Type" || path == "Description" ||
                        path == "DefaultValue") {
                        return true;
                    }
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
    for (const auto &el : specJson.items()) {
        if (el.value().is_object() &&
            valueJson.find(el.key()) != valueJson.end()) {
            mergeSpecAndValue(el.value(), valueJson.at(el.key()));
        }
    }
}

nlohmann::json configSpecToJson(const fcitx::Configuration &config) {
    fcitx::RawConfig rawDesc;
    config.dumpDescription(rawDesc);
    return configSpecToJson(rawDesc);
}

nlohmann::json configToJson(const fcitx::Configuration &config) {
    auto specJson = configSpecToJson(config);
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
