#ifndef _FCITX5_MACOS_MACOSFRONTEND_PUBLIC_H_
#define _FCITX5_MACOS_MACOSFRONTEND_PUBLIC_H_

#include <fcitx/inputcontext.h>

typedef std::function<void(const std::string &, const std::string&)> NotificationCallback;
typedef std::function<void(const std::vector<std::string> &, const int)>
    CandidateListCallback;
typedef std::function<void(const std::string &)> CommitStringCallback;
typedef std::function<void(const std::string &, int)> ShowPreeditCallback;

FCITX_ADDON_DECLARE_FUNCTION(MacosFrontend, setNotificationCallback,
                             void(const NotificationCallback &))

FCITX_ADDON_DECLARE_FUNCTION(MacosFrontend, sendNotification,
                             void(const std::string &, const std::string &))

#endif
