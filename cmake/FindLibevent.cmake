find_path(Libevent_INCLUDE_PATH event.h)
find_library(Libevent_LIBRARY NAMES event)
if(Libevent_INCLUDE_PATH AND Libevent_LIBRARY)
  set(Libevent_FOUND TRUE)
endif()
