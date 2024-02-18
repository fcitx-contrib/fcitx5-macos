#ifndef FCITX5_MACOS_FCITX_H
#define FCITX5_MACOS_FCITX_H

#include <array>
#include <cstdint>
#include <string>

// Identical to fcitx::ICUUID. Replicated for Swift interop.
typedef std::array<uint8_t, 16> ICUUID;

void start_fcitx_thread() noexcept;
void stop_fcitx_thread() noexcept;
void restart_fcitx_thread() noexcept;

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

// Returns a json array of Input Methods.
// type InputMethod := {uniqueName:str, name:str, nativeName:str,
// languageCode:str, icon:str, label:str, isConfigurable: bool}
std::string imGetAvailableIMs() noexcept;

std::string getActions() noexcept;
void activateActionById(int id) noexcept;

#endif
