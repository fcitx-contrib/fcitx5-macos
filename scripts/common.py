import re
import subprocess

def dollar(command: str):
    return subprocess.check_output(command, shell=True, text=True).strip()


def get_json(tag: str):
    cmake_osx_deployment_target_line = dollar('grep "set(CMAKE_OSX_DEPLOYMENT_TARGET" CMakeLists.txt')
    match = re.search(r'CMAKE_OSX_DEPLOYMENT_TARGET ([\d\.]+)\)', cmake_osx_deployment_target_line)
    if match is None:
        raise Exception('CMakeLists.txt should set CMAKE_OSX_DEPLOYMENT_TARGET properly.')
    macos = match.group(1)
    return {
        'tag': tag,
        'macos': macos,
        'sha': dollar('git rev-parse HEAD'),
        'time': int(dollar('git show --no-patch --format=%ct'))
    }
