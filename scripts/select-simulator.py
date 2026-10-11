#!/usr/bin/env python3
"""Select an installed iPhone simulator at iOS 17+ without a fixed device name."""
import json
import re
import sys


def select_device(data):
    candidates = []
    for runtime, devices in data.get('devices', {}).items():
        if '.iOS-' not in runtime:
            continue
        version = tuple(int(n) for n in re.findall(r'\d+', runtime.split('.iOS-', 1)[1]))
        if not version or version[0] < 17:
            continue
        for device in devices:
            if device.get('isAvailable') and device.get('name', '').startswith('iPhone') and device.get('udid'):
                candidates.append((version, device.get('state') == 'Booted', device['name'], device['udid']))
    if not candidates:
        raise ValueError('No available iPhone simulator at iOS 17 or later. In Xcode Settings → Components/Platforms, install an iOS simulator runtime, then try again.')
    return max(candidates)[3]


if __name__ == '__main__':
    try:
        with open(sys.argv[1], encoding='utf-8') as source:
            print(select_device(json.load(source)))
    except (OSError, ValueError, IndexError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
