import json
import os
import re
from common import dollar, get_json

def get_version():
    project_line = dollar('grep "project(fcitx5-macos VERSION" CMakeLists.txt')
    match = re.search(r'VERSION ([\d\.]+)', project_line)
    if match is None:
        raise Exception('CMakeLists.txt should set VERSION properly.')
    return match.group(1)

version = get_version()
if os.system(f'git tag -a {version} -m "release {version}"') != 0:
    raise Exception('Failed to create git tag.')

with open('version.jsonl') as f:
    content = f.read()

with open('version.jsonl', 'w') as f:
    json.dump(get_json(version), f)
    f.write('\n' + content)

major, minor, patch = version.split('.')

if os.system(f'sed -i.bak "s/fcitx5-macos VERSION {major}\\.{minor}\\.{patch}/fcitx5-macos VERSION {major}.{minor}.{int(patch) + 1}/" CMakeLists.txt') != 0:
    raise Exception('Failed to update version in CMakeLists.txt.')
os.system('rm CMakeLists.txt.bak')

os.system('git add version.jsonl CMakeLists.txt')
