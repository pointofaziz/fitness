#!/usr/bin/env python3
"""Deterministic, dependency-free generator for the checked-in Xcode project."""
from pathlib import Path
import hashlib, json
ROOT = Path(__file__).resolve().parents[1]
objects = {}
def ident(key): return hashlib.sha1(key.encode()).hexdigest()[:24].upper()
def q(value): return json.dumps(str(value))
def arr(values): return '(' + ', '.join(values) + ',)'
def obj(key, isa, **fields):
    keyid = ident(key)
    objects[keyid] = '{ isa = ' + isa + '; ' + ' '.join(k + ' = ' + v + ';' for k, v in fields.items()) + ' }'
    return keyid
refs = {}
app_sources = sorted(str(p.relative_to(ROOT)) for directory in ['Sources/LiftLogCore', 'LiftLog'] for p in (ROOT/directory).rglob('*.swift'))
unit_sources = sorted(str(p.relative_to(ROOT)) for directory in ['Tests/LiftLogCoreTests', 'LiftLogTests'] for p in (ROOT/directory).glob('*.swift'))
ui_sources = ['LiftLogUITests/LiftLogUITests.swift']
resources = ['LiftLog/Assets.xcassets', 'LiftLog/PrivacyInfo.xcprivacy']
for path in app_sources + unit_sources + ui_sources + resources + ['LiftLog/Info.plist', 'LiftLog/AppIdentity.xcconfig', 'README.md']:
    kind = 'sourcecode.swift' if path.endswith('.swift') else 'folder.assetcatalog' if path.endswith('.xcassets') else 'text.xcconfig' if path.endswith('.xcconfig') else 'text.plist.xml' if path.endswith(('.plist','.xcprivacy')) else 'text'
    refs[path] = obj(path, 'PBXFileReference', lastKnownFileType=q(kind), path=q(path), sourceTree=q('<group>'))
products = []
for name, ext, kind in [('LiftLog','app','wrapper.application'),('LiftLogTests','xctest','wrapper.cfbundle'),('LiftLogUITests','xctest','wrapper.cfbundle')]:
    products.append(obj('product:'+name, 'PBXFileReference', explicitFileType=q(kind), includeInIndex='0', path=q(name+'.'+ext), sourceTree=q('BUILT_PRODUCTS_DIR')))
product_group = obj('products', 'PBXGroup', children=arr(products), name=q('Products'), sourceTree=q('<group>'))
main = obj('main', 'PBXGroup', children=arr(list(refs.values())+[product_group]), sourceTree=q('<group>'))
project_configs=[]
for config in ['Debug','Release']:
    values = {'SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'17.0','SWIFT_VERSION':'5.0','CLANG_ENABLE_MODULES':'YES','CLANG_ENABLE_OBJC_ARC':'YES','GCC_C_LANGUAGE_STANDARD':'gnu17','SWIFT_STRICT_CONCURRENCY':'targeted','ENABLE_USER_SCRIPT_SANDBOXING':'YES','DEBUG_INFORMATION_FORMAT':'dwarf' if config=='Debug' else 'dwarf-with-dsym','SWIFT_OPTIMIZATION_LEVEL':'-Onone' if config=='Debug' else '-O','ONLY_ACTIVE_ARCH':'YES' if config=='Debug' else 'NO'}
    if config=='Debug': values.update(ENABLE_TESTABILITY='YES', SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG')
    project_configs.append(obj('project:'+config,'XCBuildConfiguration',name=q(config),baseConfigurationReference=refs['LiftLog/AppIdentity.xcconfig'], buildSettings='{ '+ ' '.join(k+' = '+q(v)+';' for k,v in values.items())+' }'))
project_config_list=obj('project-configs','XCConfigurationList',buildConfigurations=arr(project_configs), defaultConfigurationIsVisible='0', defaultConfigurationName=q('Release'))
targets=[]
for index,(name,sources) in enumerate([('LiftLog',app_sources),('LiftLogTests',unit_sources),('LiftLogUITests',ui_sources)]):
    sourcefiles=[obj(name+':build:'+p,'PBXBuildFile',fileRef=refs[p]) for p in sources]
    sourcephase=obj(name+':sources','PBXSourcesBuildPhase',buildActionMask='2147483647',files=arr(sourcefiles),runOnlyForDeploymentPostprocessing='0')
    frameworkphase=obj(name+':frameworks','PBXFrameworksBuildPhase',buildActionMask='2147483647',files='()',runOnlyForDeploymentPostprocessing='0')
    resourcefiles=[obj(name+':resource:'+p,'PBXBuildFile',fileRef=refs[p]) for p in resources] if index==0 else []
    resourcephase=obj(name+':resources','PBXResourcesBuildPhase',buildActionMask='2147483647',files=arr(resourcefiles) if resourcefiles else '()',runOnlyForDeploymentPostprocessing='0')
    configs=[]
    for config in ['Debug','Release']:
        values={'PRODUCT_NAME':'$(TARGET_NAME)','TARGETED_DEVICE_FAMILY':'1','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','CODE_SIGN_STYLE':'Automatic','SUPPORTS_MACCATALYST':'NO','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks @loader_path/Frameworks','PRODUCT_BUNDLE_IDENTIFIER':'$(LIFTLOG_BUNDLE_ID)' + ('.tests' if index==1 else '.uitests' if index==2 else '')}
        if index==0: values.update(INFOPLIST_FILE='LiftLog/Info.plist',GENERATE_INFOPLIST_FILE='NO',ASSETCATALOG_COMPILER_APPICON_NAME='AppIcon',ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME='AccentColor',CURRENT_PROJECT_VERSION='1',MARKETING_VERSION='1.0')
        else: values.update(GENERATE_INFOPLIST_FILE='YES')
        if index==1: values.update(TEST_HOST='$(BUILT_PRODUCTS_DIR)/LiftLog.app/LiftLog',BUNDLE_LOADER='$(TEST_HOST)')
        if index==2: values.update(TEST_TARGET_NAME='LiftLog')
        configs.append(obj(name+':'+config,'XCBuildConfiguration',name=q(config),buildSettings='{ '+' '.join(k+' = '+q(v)+';' for k,v in values.items())+' }'))
    configlist=obj(name+':configs','XCConfigurationList',buildConfigurations=arr(configs),defaultConfigurationIsVisible='0',defaultConfigurationName=q('Release'))
    dependencies=[]
    if index:
        proxy=obj(name+':proxy','PBXContainerItemProxy',containerPortal=ident('project'),proxyType='1',remoteGlobalIDString=ident('target:LiftLog'),remoteInfo=q('LiftLog'))
        dependencies.append(obj(name+':dependency','PBXTargetDependency',target=ident('target:LiftLog'),targetProxy=proxy))
    targets.append(obj('target:'+name,'PBXNativeTarget',buildConfigurationList=configlist,buildPhases=arr([sourcephase,frameworkphase,resourcephase]),buildRules='()',dependencies=arr(dependencies) if dependencies else '()',name=q(name),productName=q(name),productReference=products[index],productType=q('com.apple.product-type.application' if index==0 else 'com.apple.product-type.bundle.unit-test' if index==1 else 'com.apple.product-type.bundle.ui-testing')))
obj('project','PBXProject',attributes='{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; TargetAttributes = { '+ident('target:LiftLog')+' = { CreatedOnToolsVersion = 16.0; }; '+ident('target:LiftLogTests')+' = { CreatedOnToolsVersion = 16.0; TestTargetID = '+ident('target:LiftLog')+'; }; '+ident('target:LiftLogUITests')+' = { CreatedOnToolsVersion = 16.0; TestTargetID = '+ident('target:LiftLog')+'; }; }; }',buildConfigurationList=project_config_list,compatibilityVersion=q('Xcode 14.0'),developmentRegion=q('en'),hasScannedForEncodings='0',knownRegions=arr([q('en'),q('Base')]),mainGroup=main,productRefGroup=product_group,projectDirPath=q(''),projectRoot=q(''),targets=arr(targets))
project=ROOT/'LiftLog.xcodeproj';project.mkdir(exist_ok=True)
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(k+' = '+v+';' for k,v in sorted(objects.items()))+'\n}; rootObject = '+ident('project')+'; }\n')
def buildref(name, ext): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident("target:"+name)}" BuildableName="{name}.{ext}" BlueprintName="{name}" ReferencedContainer="container:LiftLog.xcodeproj"/>'
app=buildref('LiftLog','app')
scheme=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.7">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
 <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app}</BuildActionEntry>
 </BuildActionEntries></BuildAction>
 <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables>
 <TestableReference skipped="NO" parallelizable="NO">{buildref('LiftLogTests','xctest')}</TestableReference>
 <TestableReference skipped="NO" parallelizable="NO">{buildref('LiftLogUITests','xctest')}</TestableReference>
 </Testables></TestAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app}</BuildableProductRunnable></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app}</BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
path=project/'xcshareddata/xcschemes';path.mkdir(parents=True,exist_ok=True);(path/'LiftLog.xcscheme').write_text(scheme)
print(f'Generated {len(app_sources)} app sources, 3 targets and shared scheme.')
