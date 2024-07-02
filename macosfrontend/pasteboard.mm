#include "macosfrontend.h"
#import <AppKit/AppKit.h>

static int lastChangeCount = 0;
static NSPasteboardType passwordType = @"org.nspasteboard.ConcealedType";

namespace fcitx {
std::string getPasteboardString(bool *isPassword) {
  NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
  if (pasteboard.changeCount == lastChangeCount) {
    return "";
  }
  lastChangeCount = (int)pasteboard.changeCount;
  NSString *stringData = [pasteboard stringForType:NSPasteboardTypeString];
  if (stringData) {
    *isPassword = ([pasteboard stringForType:passwordType] != nil);
    return std::string([stringData UTF8String]);
  }
  return "";
}
} // namespace fcitx
