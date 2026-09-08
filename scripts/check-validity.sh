set -e

has_homebrew_deps=0
has_xcode_rpath=0
has_extra_dylib=0
has_invalid_build_version=0

project_root=$(cd "$(dirname "$0")/.." && pwd)
deployment_target=$(sed -nE \
  's/^[[:space:]]*set\(CMAKE_OSX_DEPLOYMENT_TARGET[[:space:]]+([0-9]+(\.[0-9]+)*)\).*$/\1/p' \
  "$project_root/CMakeLists.txt")
sdk_version=$(xcrun --sdk macosx --show-sdk-version)

if [[ -z $deployment_target ]]; then
  echo "Failed to read CMAKE_OSX_DEPLOYMENT_TARGET from $project_root/CMakeLists.txt" >&2
  exit 8
fi

cd /Library/Input\ Methods/Fcitx5.app/Contents
libs=(MacOS/Fcitx5)
libs+=($(ls lib/libFcitx5{Config,Core,Utils}.dylib))
libs+=($(ls lib/fcitx5/*.so))
libs+=(lib/fcitx5/libexec/comp-spell-dict)

for lib in "${libs[@]}"; do
  if otool -L $lib | grep '/usr/local\|/opt/homebrew'; then
    otool -L $lib
    has_homebrew_deps=1
  fi
  if otool -l $lib | grep -A2 LC_RPATH | grep Xcode; then
    otool -l $lib | grep -A2 LC_RPATH
    has_xcode_rpath=2
  fi
  n_dylib=$(otool -L MacOS/Fcitx5 | grep rpath | wc -l | xargs)
  if [[ $n_dylib != 3 ]]; then
    has_extra_dylib=4
  fi
done

build_version=$(vtool -show-build MacOS/Fcitx5)

check_build_version() {
  local field=$1
  local expected=$2

  if ! awk -v field="$field" -v expected="$expected" '
    $1 == field {
      found = 1
      if ($2 != expected) {
        invalid = 1
      }
    }
    END { exit !found || invalid }
  ' <<< "$build_version"; then
    echo "MacOS/Fcitx5 has an unexpected $field; expected $expected:" >&2
    echo "$build_version" >&2
    has_invalid_build_version=8
  fi
}

check_build_version minos "$deployment_target"
check_build_version sdk "$sdk_version"

exit $((has_homebrew_deps + has_xcode_rpath + has_extra_dylib + has_invalid_build_version))
