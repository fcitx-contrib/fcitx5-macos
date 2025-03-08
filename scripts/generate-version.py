import json
from common import get_json

versions = []

with open('version.jsonl') as f:
    while line := f.readline():
        versions.append(json.loads(line))

# Generate sha and time for tag latest.
latest = get_json('latest')

with open('version.json', 'w') as f:
    json.dump({
        'versions': [latest] + versions
    }, f)
