#!/usr/bin/env python3
"""Portable structure checks, explicitly not an Apple SDK build."""
from pathlib import Path
import json, plistlib, re, struct, xml.etree.ElementTree as ET
root=Path(__file__).resolve().parents[1]
project=(root/'LiftLog.xcodeproj/project.pbxproj').read_text()
objects=set(re.findall(r'^([A-F0-9]{24}) = ', project,re.M))
refs=set(re.findall(r'\b[A-F0-9]{24}\b',project))
assert refs <= objects, f'Dangling project references: {refs-objects}'
assert project.count('isa = PBXNativeTarget;') == 3
for path in re.findall(r'path = "([^"\n]+)";',project):
    if path.endswith(('.app','.xctest')): continue
    assert (root/path).exists(), f'Missing {path}'
for directory in ['LiftLog','Sources/LiftLogCore','LiftLogTests','LiftLogUITests','Tests/LiftLogCoreTests']:
    for file in (root/directory).rglob('*.swift'):
        assert str(file.relative_to(root)) in project, f'Unreferenced Swift file {file}'
for path in [root/'LiftLog/Info.plist',root/'LiftLog/PrivacyInfo.xcprivacy']:
    with path.open('rb') as f: plistlib.load(f)
scheme=ET.parse(root/'LiftLog.xcodeproj/xcshareddata/xcschemes/LiftLog.xcscheme')
assert len(scheme.findall('.//TestableReference')) == 2
for ref in scheme.findall('.//BuildableReference'): assert ref.attrib['BlueprintIdentifier'] in objects
for path in (root/'LiftLog/Assets.xcassets').rglob('Contents.json'): json.loads(path.read_text())
icon=(root/'LiftLog/Assets.xcassets/AppIcon.appiconset/AppIcon.png').read_bytes()
assert struct.unpack('>II',icon[16:24]) == (1024,1024) and icon[25] == 2, 'Icon must be opaque RGB 1024x1024'
print('PASS: project references, 3 targets, shared scheme, source membership, plists and icon assets.')
print('This does not compile SwiftUI/SwiftData or verify simulator behavior.')
