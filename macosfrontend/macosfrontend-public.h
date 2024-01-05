#ifndef _FCITX5_MACOS_MACOSFRONTEND_PUBLIC_H_
#define _FCITX5_MACOS_MACOSFRONTEND_PUBLIC_H_

#include <fcitx/inputcontext.h>

typedef std::function<void(const std::string &, const std::string &)>
    NotifyCallback;
typedef std::function<void(const std::vector<std::string> &, const int)>
    CandidateListCallback;
typedef std::function<void(const std::string &)> CommitStringCallback;
typedef std::function<void(const std::string &, int)> ShowPreeditCallback;

FCITX_ADDON_DECLARE_FUNCTION(MacosFrontend, setNotifyCallback,
                             void(const NotifyCallback &))

FCITX_ADDON_DECLARE_FUNCTION(MacosFrontend, notify,
                             void(const std::string &, const std::string &))

#endif
