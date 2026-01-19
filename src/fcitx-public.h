#pragma once

#include <string>

void start_fcitx_thread(const char *locale) noexcept;
void stop_fcitx_thread() noexcept;
void reload();
void setupI18N();

// NOTE: It's impossible to use std::vector<std::string> directly
// until Swift fixes C++ interop.
// Returns a json array of group names.
std::string imGetGroupNames() noexcept;
std::string imGetCurrentGroupName() noexcept;
void imSetCurrentGroup(const char *groupName) noexcept;

// Returns a json array of { "name": ..., "displayName": ... }
std::string imGetCurrentGroup() noexcept;

int imGroupCount() noexcept;
void imAddToCurrentGroup(const char *imName) noexcept;

// Returns json
// [{"name": "group name", "inputMethods":
//   [{"name": ..., "displayName": ...}...]}...].
std::string imGetGroups() noexcept;
void imSetGroups(const char *json) noexcept;

std::string imGetCurrentIMName() noexcept;
void imSetCurrentIM(const char *imName) noexcept;
void toggleInputMethod() noexcept;

// Returns a json array of Input Methods.
// type InputMethod := {uniqueName:str, name:str, nativeName:str,
// languageCode:str, icon:str, label:str, isConfigurable: bool}
std::string imGetAvailableIMs() noexcept;

std::string getAddons() noexcept;

std::string getActions() noexcept;
void activateActionById(int id, bool hotkey) noexcept;

std::string isoName(const char *code) noexcept;

// Tunnel variables
#include "tunnel.h"
