#!/usr/bin/env python3
"""Regenerate the deterministic iPad project from the shared sources. No dependencies."""
from pathlib import Path
import hashlib,json,plistlib,os
root=Path(__file__).resolve().parents[1]
def uid(s):return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
def q(s):return json.dumps(str(s))
(root/'iPadOS/CommissieWijzer.xcodeproj/xcshareddata/xcschemes').mkdir(parents=True, exist_ok=True)
(root/'iPadOS/Assets.xcassets/AppIcon.appiconset').mkdir(parents=True, exist_ok=True)
objects=[]
def obj(key,value):objects.append(f'{uid(key)} = {{ {value} }};');return uid(key)
sourceids=[];filerefs=[]
for p in sorted((root/'Sources/CommissieWijzer').glob('*.swift')):
 ref=obj('file:'+p.name, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(p.name)}; sourceTree = "<group>";')
 build=obj('build:'+p.name,f'isa = PBXBuildFile; fileRef = {ref};')
 filerefs.append(ref);sourceids.append(build)
sourcegroup=obj('sourcegroup',f'isa = PBXGroup; path = ../Sources/CommissieWijzer; sourceTree = "<group>"; children = ({",".join(filerefs)});')
asset=obj('assets','isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>";')
assetbuild=obj('assetbuild',f'isa = PBXBuildFile; fileRef = {asset};')
licenses=obj('licenses','isa = PBXFileReference; lastKnownFileType = folder; path = ../ThirdPartyLicenses; sourceTree = "<group>";')
licensesbuild=obj('licensesbuild',f'isa = PBXBuildFile; fileRef = {licenses};')
privacy=obj('privacy','isa = PBXFileReference; lastKnownFileType = text.xml; path = ../AppStore/PrivacyInfo.xcprivacy; sourceTree = "<group>";')
privacybuild=obj('privacybuild',f'isa = PBXBuildFile; fileRef = {privacy};')
product=obj('product','isa = PBXFileReference; explicitFileType = wrapper.application; path = CommissieWijzer.app; sourceTree = BUILT_PRODUCTS_DIR;')
productgroup=obj('productgroup',f'isa = PBXGroup; name = Products; sourceTree = "<group>"; children = ({product},{uid("testproduct")});')
main=obj('main',f'isa = PBXGroup; sourceTree = "<group>"; children = ({sourcegroup},{asset},{licenses},{privacy},{productgroup},{uid("testgroup")});')
package=obj('package','isa = XCLocalSwiftPackageReference; relativePath = ..;')
packprod=obj('packageproduct',f'isa = XCSwiftPackageProductDependency; package = {package}; productName = CommissieShared;')
packbuild=obj('packagebuild',f'isa = PBXBuildFile; productRef = {packprod};')
sources=obj('sources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(sourceids)}); runOnlyForDeploymentPostprocessing = 0;')
resources=obj('resources',f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({assetbuild},{licensesbuild},{privacybuild}); runOnlyForDeploymentPostprocessing = 0;')
frameworks=obj('frameworks',f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = ({packbuild}); runOnlyForDeploymentPostprocessing = 0;')
projectconfigs=[];targetconfigs=[]
for kind in ['Debug','Release']:
 opts={'SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'26.0','CLANG_ENABLE_MODULES':'YES','SWIFT_VERSION':'5.0','ONLY_ACTIVE_ARCH':'YES' if kind=='Debug' else 'NO','SWIFT_STRICT_CONCURRENCY':'targeted','SWIFT_ACTIVE_COMPILATION_CONDITIONS':'$(inherited) DEBUG' if kind=='Debug' else '$(inherited)','SWIFT_OPTIMIZATION_LEVEL':'-Onone' if kind=='Debug' else '-O','DEBUG_INFORMATION_FORMAT':'dwarf' if kind=='Debug' else 'dwarf-with-dsym'}
 settings=' '.join(f'{k} = {q(v)};' for k,v in opts.items())
 projectconfigs.append(obj('proj'+kind,f'isa = XCBuildConfiguration; name = {kind}; buildSettings = {{ {settings} }};'))
 opts={'PRODUCT_NAME':'CommissieWijzer','PRODUCT_BUNDLE_IDENTIFIER':'nl.commissiewijzer.app','INFOPLIST_FILE':'Info.plist','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','TARGETED_DEVICE_FAMILY':'2','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','SUPPORTS_MACCATALYST':'NO','SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD':'NO','CODE_SIGN_STYLE':'Automatic','MARKETING_VERSION':'1.2.0','CURRENT_PROJECT_VERSION':'8','CW_CLOUDKIT_ENABLED':'NO','CW_CLOUDKIT_ENVIRONMENT':'Disabled','SWIFT_EMIT_LOC_STRINGS':'YES','ENABLE_PREVIEWS':'YES','ENABLE_TESTABILITY':'YES','PRODUCT_MODULE_NAME':'CommissieWijzer','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks'}
 settings=' '.join(f'{k} = {q(v)};' for k,v in opts.items())
 targetconfigs.append(obj('target'+kind,f'isa = XCBuildConfiguration; name = {kind}; buildSettings = {{ {settings} }};'))
pcl=obj('projectconfig',f'isa = XCConfigurationList; buildConfigurations = ({",".join(projectconfigs)}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
tcl=obj('targetconfig',f'isa = XCConfigurationList; buildConfigurations = ({",".join(targetconfigs)}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
target=obj('target',f'isa = PBXNativeTarget; buildConfigurationList = {tcl}; buildPhases = ({sources},{frameworks},{resources}); buildRules = (); dependencies = (); name = CommissieWijzer-iPad; packageProductDependencies = ({packprod}); productName = CommissieWijzer; productReference = {product}; productType = "com.apple.product-type.application";')
testids=[];testrefs=[]
for p in sorted((root/'Tests/CommissieAppTests').glob('*.swift')):
 ref=obj('testfile:'+p.name,f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(p.name)}; sourceTree = "<group>";')
 testrefs.append(ref)
 testids.append(obj('testbuild:'+p.name,f'isa = PBXBuildFile; fileRef = {ref};'))
fixture=obj('fixture','isa = PBXFileReference; lastKnownFileType = file; path = ../Fixtures/mac-v1.spdfwork; sourceTree = "<group>";')
fixturebuild=obj('fixturebuild',f'isa = PBXBuildFile; fileRef = {fixture};')
storefixture=obj('storefixture','isa = PBXFileReference; lastKnownFileType = file; path = ../Fixtures/ipad-store-demo.spdfwork; sourceTree = "<group>";')
storefixturebuild=obj('storefixturebuild',f'isa = PBXBuildFile; fileRef = {storefixture};')
obj('testgroup',f'isa = PBXGroup; name = Tests; path = ../Tests/CommissieAppTests; sourceTree = "<group>"; children = ({",".join(testrefs)},{fixture},{storefixture});')
testproduct=obj('testproduct','isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = CommissieWijzerTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
testsources=obj('testsources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(testids)}); runOnlyForDeploymentPostprocessing = 0;')
testres=obj('testresources',f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({fixturebuild},{storefixturebuild}); runOnlyForDeploymentPostprocessing = 0;')
testpackbuild=obj('testpackagebuild',f'isa = PBXBuildFile; productRef = {packprod};')
testfw=obj('testframeworks',f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = ({testpackbuild}); runOnlyForDeploymentPostprocessing = 0;')
testconfigs=[]
for kind in ['Debug','Release']:
 opts={'PRODUCT_NAME':'CommissieWijzerTests','PRODUCT_BUNDLE_IDENTIFIER':'nl.commissiewijzer.app.tests','GENERATE_INFOPLIST_FILE':'YES','TEST_HOST':'$(BUILT_PRODUCTS_DIR)/CommissieWijzer.app/CommissieWijzer','BUNDLE_LOADER':'$(TEST_HOST)','CODE_SIGN_STYLE':'Automatic','TARGETED_DEVICE_FAMILY':'2','SWIFT_VERSION':'5.0'}
 settings=' '.join(f'{k} = {q(v)};' for k,v in opts.items())
 testconfigs.append(obj('test'+kind,f'isa = XCBuildConfiguration; name = {kind}; buildSettings = {{ {settings} }};'))
testcl=obj('testconfig',f'isa = XCConfigurationList; buildConfigurations = ({",".join(testconfigs)}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
proxy=obj('testproxy',f'isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {target}; remoteInfo = "CommissieWijzer-iPad";')
dep=obj('testdependency',f'isa = PBXTargetDependency; target = {target}; targetProxy = {proxy};')
testtarget=obj('testtarget',f'isa = PBXNativeTarget; buildConfigurationList = {testcl}; buildPhases = ({testsources},{testfw},{testres}); buildRules = (); dependencies = ({dep}); name = CommissieWijzerTests; packageProductDependencies = ({packprod}); productName = CommissieWijzerTests; productReference = {testproduct}; productType = "com.apple.product-type.bundle.unit-test";')
project=obj('project',f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2710; TargetAttributes = {{ {target} = {{ CreatedOnToolsVersion = 27.1; }}; }}; }}; buildConfigurationList = {pcl}; compatibilityVersion = "Xcode 14.0"; developmentRegion = nl; hasScannedForEncodings = 0; knownRegions = (nl,en,Base); mainGroup = {main}; packageReferences = ({package}); productRefGroup = {productgroup}; projectDirPath = ""; projectRoot = ""; targets = ({target},{testtarget});')
(root/'iPadOS/CommissieWijzer.xcodeproj/project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+f'\n}}; rootObject = {project}; }}\n')
scheme=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2710" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="CommissieWijzer.app" BlueprintName="CommissieWijzer-iPad" ReferencedContainer="container:CommissieWijzer.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
 <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO" parallelizable="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{testtarget}" BuildableName="CommissieWijzerTests.xctest" BlueprintName="CommissieWijzerTests" ReferencedContainer="container:CommissieWijzer.xcodeproj"/></TestableReference></Testables></TestAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="CommissieWijzer.app" BlueprintName="CommissieWijzer-iPad" ReferencedContainer="container:CommissieWijzer.xcodeproj"/></BuildableProductRunnable></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="CommissieWijzer.app" BlueprintName="CommissieWijzer-iPad" ReferencedContainer="container:CommissieWijzer.xcodeproj"/></BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
(root/'iPadOS/CommissieWijzer.xcodeproj/xcshareddata/xcschemes/CommissieWijzer-iPad.xcscheme').write_text(scheme)
live_scheme=scheme.replace(
    '</Testables></TestAction>',
    '</Testables><EnvironmentVariables><EnvironmentVariable key="CW_RUN_LIVE_APPLE_AI" value="1" isEnabled="YES"/></EnvironmentVariables></TestAction>')
live_scheme=live_scheme.replace(
    'allowLocationSimulation="YES"><BuildableProductRunnable',
    'allowLocationSimulation="YES"><EnvironmentVariables><EnvironmentVariable key="CW_RUN_LIVE_APPLE_AI" value="1" isEnabled="YES"/></EnvironmentVariables><BuildableProductRunnable')
(root/'iPadOS/CommissieWijzer.xcodeproj/xcshareddata/xcschemes/CommissieWijzer-LiveAI.xcscheme').write_text(live_scheme)
(root/'iPadOS/CommissieWijzer.xcodeproj/xcshareddata/xcschemes/CommissieWijzer-LiveChatGPT.xcscheme').write_text(
    live_scheme.replace('CW_RUN_LIVE_APPLE_AI', 'CW_RUN_LIVE_CHATGPT'))
store_screenshots_scheme=scheme.replace(
    '</Testables></TestAction>',
    '</Testables><EnvironmentVariables><EnvironmentVariable key="CW_CAPTURE_STORE_SCREENSHOTS" value="1" isEnabled="YES"/></EnvironmentVariables></TestAction>')
store_screenshots_scheme=store_screenshots_scheme.replace(
    'allowLocationSimulation="YES"><BuildableProductRunnable',
    'allowLocationSimulation="YES"><EnvironmentVariables><EnvironmentVariable key="CW_CAPTURE_STORE_SCREENSHOTS" value="1" isEnabled="YES"/></EnvironmentVariables><BuildableProductRunnable')
(root/'iPadOS/CommissieWijzer.xcodeproj/xcshareddata/xcschemes/CommissieWijzer-StoreScreenshots.xcscheme').write_text(store_screenshots_scheme)
info={'CFBundleDevelopmentRegion':'nl','CFBundleDisplayName':'CommissieWijzer','CFBundleExecutable':'$(EXECUTABLE_NAME)','CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)','CFBundleInfoDictionaryVersion':'6.0','CFBundleName':'$(PRODUCT_NAME)','CFBundlePackageType':'APPL','CFBundleShortVersionString':'$(MARKETING_VERSION)','CFBundleVersion':'$(CURRENT_PROJECT_VERSION)','CWCloudKitEnabled':'$(CW_CLOUDKIT_ENABLED)','CWCloudKitEnvironment':'$(CW_CLOUDKIT_ENVIRONMENT)','LSRequiresIPhoneOS':True,'UIApplicationSupportsIndirectInputEvents':True,'UIUserInterfaceStyle':'Dark','UILaunchScreen':{},'UIApplicationSceneManifest':{'UIApplicationSupportsMultipleScenes':True},'UISupportedInterfaceOrientations~ipad':['UIInterfaceOrientationPortrait','UIInterfaceOrientationPortraitUpsideDown','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'],'UIFileSharingEnabled':True,'LSSupportsOpeningDocumentsInPlace':True,'UISupportsDocumentBrowser':True,'CFBundleDocumentTypes':[{'CFBundleTypeName':'CommissieWijzer-werkdocument','CFBundleTypeRole':'Editor','LSHandlerRank':'Owner','LSItemContentTypes':['nl.commissiewijzer.app.work']},{'CFBundleTypeName':'PDF-document','CFBundleTypeRole':'Viewer','LSHandlerRank':'Alternate','LSItemContentTypes':['com.adobe.pdf']}],'UTExportedTypeDeclarations':[{'UTTypeIdentifier':'nl.commissiewijzer.app.work','UTTypeDescription':'CommissieWijzer work document','UTTypeConformsTo':['public.data'],'UTTypeTagSpecification':{'public.filename-extension':['spdfwork']}}],'ITSAppUsesNonExemptEncryption':False}
(root/'iPadOS/Info.plist').write_bytes(plistlib.dumps(info))
# CloudKit entitlements are generated as explicit opt-in inputs only. Build scripts
# select one after validating the matching profile; ordinary previews use none.
for environment in ('Development', 'Production'):
    cloud={'com.apple.developer.icloud-container-identifiers':['iCloud.nl.commissiewijzer.app'],
           'com.apple.developer.icloud-services':['CloudKit'],
           'com.apple.developer.icloud-container-environment':environment}
    (root/f'iPadOS/CommissieWijzer.iCloud-{environment}.entitlements').write_bytes(plistlib.dumps(cloud,sort_keys=True))
(root/'iPadOS/Assets.xcassets/Contents.json').write_text(json.dumps({'info':{'author':'xcode','version':1}},indent=2)+'\n')
(root/'iPadOS/Assets.xcassets/AppIcon.appiconset/Contents.json').write_text(json.dumps({'images':[{'filename':'AppIcon.png','idiom':'universal','platform':'ios','size':'1024x1024'}],'info':{'author':'xcode','version':1}},indent=2)+'\n')
import subprocess
module_cache=root/'.build'/'swift-module-cache'
module_cache.mkdir(parents=True,exist_ok=True)
swift_env=os.environ.copy()
swift_env.setdefault('CLANG_MODULE_CACHE_PATH',str(module_cache))
swift_env.setdefault('SWIFT_MODULECACHE_PATH',str(module_cache))
subprocess.run(['swift',str(root/'scripts/prepare-ipad-icon.swift'),str(root/'Assets/CommissieWijzer.png'),str(root/'iPadOS/Assets.xcassets/AppIcon.appiconset/AppIcon.png')],check=True,env=swift_env)
(root/'iPadOS/Assets.xcassets/CWBrand.imageset').mkdir(exist_ok=True)
import shutil
shutil.copyfile(root/'iPadOS/Assets.xcassets/AppIcon.appiconset/AppIcon.png',root/'iPadOS/Assets.xcassets/CWBrand.imageset/CWBrand.png')
(root/'iPadOS/Assets.xcassets/CWBrand.imageset/Contents.json').write_text(json.dumps({'images':[{'filename':'CWBrand.png','idiom':'universal'}],'info':{'author':'xcode','version':1}},indent=2)+'\n')
print(f'Generated target with {len(sourceids)} shared Swift files')
