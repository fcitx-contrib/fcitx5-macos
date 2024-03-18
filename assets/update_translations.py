#!/usr/bin/env python3

import sys
import re


DATA_LINE_RE = re.compile(r'^"(.*)" = "(.*)";$')
ENCODING = 'utf16'


class TranslationFile:
    def __init__(self, path: str):
        self.path = path
        self.table = {}
        try:
            with open(path, 'r', encoding=ENCODING) as file:
                self.contents = file.read()
                file.seek(0)
                for line in file:
                    m = re.match(DATA_LINE_RE, line)
                    if not m:
                        continue
                    self.table[m.group(1)] = m.group(2)
        except:
            self.contents = ''

    def update_from(self, base: 'TranslationFile'):
        with open(self.path, 'w', encoding=ENCODING) as out:
            with open(base.path, 'r', encoding=ENCODING) as inp:
                for line in inp:
                    m = re.match(DATA_LINE_RE, line)
                    if m:
                        key = m.group(1)
                        value = self.table.get(key, m.group(2))
                        out.write(f'"{key}" = "{value}";\n')
                    else:
                        out.write(line)


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print('USAGE: base.strings locale1.strings locale2.strings locale3.strings ...')
        sys.exit(1)
    print(f'base = {sys.argv[1]}')
    base = TranslationFile(sys.argv[1])
    for path in sys.argv[2:]:
        print(f'updating {path}')
        translated = TranslationFile(path)
        translated.update_from(base)
