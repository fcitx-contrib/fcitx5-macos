set -e

for file in $(git ls-files | grep '\.swift$'); do
  if grep 'NSLog(' $file; then
    echo "Please use Logging module instead of NSLog"
    exit 1
  fi
  if grep 'ScrollView.*\.horizontal' $file; then
    echo "Please don't use horizontal scroll"
    exit 1
  fi
  if grep 'LocalizedStringKey(' $file; then
    echo "Please use NSLocalizedString instead of LocalizedStringKey"
    exit 1
  fi
done
