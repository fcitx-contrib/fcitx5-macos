/*
 * SPDX-License-Identifier: LGPL-2.1-or-later
 * SPDX-FileCopyrightText: Copyright 2021-2023 Fcitx5 for Android Contributors

 * SPDX-License-Identifier: GPL-3.0-only
 * SPDX-FileCopyrightText: Copyright 2023 Qijia Liu
 */
#ifndef FCITX5_MACOS_NATIVESTREAMBUF_H
#define FCITX5_MACOS_NATIVESTREAMBUF_H

#include <array>
#include <streambuf>
#include <os/log.h>

// Dynamic content is limited to 256B, see log.h
template <std::size_t SIZE = 256>
class native_streambuf : public std::streambuf {
public:
    using Base = std::streambuf;
    using char_type = typename Base::char_type;
    using int_type = typename Base::int_type;

    native_streambuf()
        : _buffer{},
          logger(os_log_create("org.fcitx.inputmethod.Fcitx5", "FcitxLog")) {
        Base::setp(_buffer.begin(), _buffer.end() - 1);
    }

    // buffer is full but current "line" of log hasn't finished
    int_type overflow(int_type ch) override {
        // append terminate character to the buffer (usually _buffer.end() when
        // overflow)
        *Base::pptr() = '\0';
        const char *text = Base::pbase();
        if (should_offset) {
            // it's the first write of this "line", guess priority
            update_log_priority(text[0]);
            // this write would skip first character
            write_log(text);
            // consequence write of this "line" should use same priority and
            // should not skip characters
            should_offset = false;
        } else {
            // it's not the first write of this "line", so just write
            write_log(text);
        }
        // mark buffer as available, since it's content has been written to
        // android log but we need to preserve the last position for '\0' in
        // case it overflows
        Base::setp(_buffer.begin(), _buffer.end() - 1);
        // write 'ch' as char if it's not eof
        if (!Base::traits_type::eq_int_type(ch, Base::traits_type::eof())) {
            const char_type c = Base::traits_type::to_char_type(ch);
            Base::xsputn(&c, 1);
        }
        return 0;
    }

    // current "line" of log has finished, and buffer is not full
    int_type sync() override {
        *Base::pptr() = '\0';
        const char *text = Base::pbase();
        if (should_offset) {
            // it's the first write of this "line", guess priority
            update_log_priority(text[0]);
        }
        write_log(text);
        // this "line" has finished and written to NS log,
        // reset state for next "line"
        should_offset = true;
        // mark buffer as available and preserve last position for '\0'
        Base::setp(_buffer.begin(), _buffer.end() - 1);
        return 0;
    }

private:
    std::array<char_type, SIZE> _buffer;
    os_log_t logger;
    os_log_type_t prio;
    /**
     * whether the first character in buffer represents log level or not
     */
    bool should_offset = true;

    void update_log_priority(const char_type first) {
        switch (first) {
        case 'D':
            prio = OS_LOG_TYPE_DEBUG;
            break;
        case 'I':
            prio = OS_LOG_TYPE_INFO;
            break;
        case 'W':
            prio = OS_LOG_TYPE_ERROR;
            break;
        case 'E':
        case 'F':
            prio = OS_LOG_TYPE_FAULT;
            break;
        default:
            break;
        }
    }

    void write_log(const char_type *text) const {
        os_log_with_type(logger, prio, "%{public}s",
                         text + (should_offset ? 1 : 0));
    }
};

#endif // FCITX5_MACOS_NATIVESTREAMBUF_H
