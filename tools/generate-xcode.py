"""Generate a dependency-free Xcode project with app and XCTest targets."""
from pathlib import Path
import hashlib,shutil,re
r=Path(__file__).resolve().parents[1];base=r/'ios';proj=base/'CRISIS.xcodeproj';proj.mkdir(exist_ok=True)
def ID(s):return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
objects=[]
def obj(k,v):objects.append(f'{ID(k)} = {{ {v} }};');return ID(k)
def arr(xs):return '('+','.join(xs)+(',)' if xs else ')')
files={}
for name,typ in [('CRISIS/CrisisApp.swift','sourcecode.swift'),('CRISIS/Models.swift','sourcecode.swift'),('CRISISTests/EngineTests.swift','sourcecode.swift'),('CRISIS/Resources/content.json','text.json'),('CRISIS/Resources/demo-data.json','text.json'),('CRISIS/Resources/logo.png','image.png'),('CRISIS/Resources/Assets.xcassets','folder.assetcatalog'),('CRISIS/Resources/PrivacyInfo.xcprivacy','text.xml'),('CRISISTests/golden-data.json','text.json')]:
 files[name]=obj(name,f'isa = PBXFileReference; lastKnownFileType = {typ}; path = "{name}"; sourceTree = "<group>";')
shutil.copy(r/'shared/golden-data.json',base/'CRISISTests/golden-data.json')
appProduct=obj('product-app','isa = PBXFileReference; explicitFileType = wrapper.application; path = CRISIS.app; sourceTree = BUILT_PRODUCTS_DIR;')
testProduct=obj('product-tests','isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = CRISISTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
products=obj('products',f'isa = PBXGroup; children = {arr([appProduct,testProduct])}; name = Products; sourceTree = "<group>";')
main=obj('main',f'isa = PBXGroup; children = {arr(list(files.values())+[products])}; sourceTree = "<group>";')
def phase(key,isa,paths):
 builds=[obj(key+p,f'isa = PBXBuildFile; fileRef = {files[p]};') for p in paths]
 return obj(key,f'isa = {isa}; buildActionMask = 2147483647; files = {arr(builds)}; runOnlyForDeploymentPostprocessing = 0;')
aSrc=phase('app-sources','PBXSourcesBuildPhase',['CRISIS/CrisisApp.swift','CRISIS/Models.swift'])
aRes=phase('app-resources','PBXResourcesBuildPhase',['CRISIS/Resources/content.json','CRISIS/Resources/demo-data.json','CRISIS/Resources/logo.png','CRISIS/Resources/PrivacyInfo.xcprivacy','CRISIS/Resources/Assets.xcassets'])
tSrc=phase('test-sources','PBXSourcesBuildPhase',['CRISISTests/EngineTests.swift'])
tRes=phase('test-resources','PBXResourcesBuildPhase',['CRISIS/Resources/content.json','CRISIS/Resources/demo-data.json','CRISISTests/golden-data.json'])
frameworksA=phase('app-frameworks','PBXFrameworksBuildPhase',[]);frameworksT=phase('test-frameworks','PBXFrameworksBuildPhase',[])
def configs(target):
 ids=[]
 for mode in ['Debug','Release']:
  settings='SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 16.0; SWIFT_VERSION = 5.0; CLANG_ENABLE_MODULES = YES;'
  if target=='project':settings+=' SWIFT_OPTIMIZATION_LEVEL = '+('"-Onone"' if mode=='Debug' else '"-O"')+'; ENABLE_TESTABILITY = '+('YES' if mode=='Debug' else 'NO')+';'
  else:
   settings+=' GENERATE_INFOPLIST_FILE = YES; TARGETED_DEVICE_FAMILY = "1,2"; CODE_SIGN_STYLE = Automatic; PRODUCT_NAME = "$(TARGET_NAME)";'
   if target=='app':settings+=' ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; PRODUCT_BUNDLE_IDENTIFIER = berlin.aia.crisis; INFOPLIST_KEY_CFBundleDisplayName = "CRISIS ©"; INFOPLIST_KEY_UILaunchScreen_Generation = YES; INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES; CURRENT_PROJECT_VERSION = 1; MARKETING_VERSION = 1.0.0;'
   else:settings+=' PRODUCT_BUNDLE_IDENTIFIER = berlin.aia.crisis.tests; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/CRISIS.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/CRISIS"; BUNDLE_LOADER = "$(TEST_HOST)";'
  ids.append(obj(target+mode,f'isa = XCBuildConfiguration; buildSettings = {{ {settings} }}; name = {mode};'))
 return obj(target+'configs',f'isa = XCConfigurationList; buildConfigurations = {arr(ids)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
ac=configs('app');tc=configs('test');pc=configs('project')
proxy=obj('proxy',f'isa = PBXContainerItemProxy; containerPortal = {ID("project")}; proxyType = 1; remoteGlobalIDString = {ID("app")}; remoteInfo = CRISIS;')
dep=obj('dependency',f'isa = PBXTargetDependency; target = {ID("app")}; targetProxy = {proxy};')
app=obj('app',f'isa = PBXNativeTarget; buildConfigurationList = {ac}; buildPhases = {arr([aSrc,frameworksA,aRes])}; buildRules = (); dependencies = (); name = CRISIS; productName = CRISIS; productReference = {appProduct}; productType = "com.apple.product-type.application";')
tests=obj('tests',f'isa = PBXNativeTarget; buildConfigurationList = {tc}; buildPhases = {arr([tSrc,frameworksT,tRes])}; buildRules = (); dependencies = {arr([dep])}; name = CRISISTests; productName = CRISISTests; productReference = {testProduct}; productType = "com.apple.product-type.bundle.unit-test";')
obj('project',f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 1600; TargetAttributes = {{ {app} = {{ CreatedOnToolsVersion = 16.0; }}; {tests} = {{ CreatedOnToolsVersion = 16.0; TestTargetID = {app}; }}; }}; }}; buildConfigurationList = {pc}; compatibilityVersion = "Xcode 14.0"; developmentRegion = de; hasScannedForEncodings = 0; knownRegions = (de,en,Base,); mainGroup = {main}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = {arr([app,tests])};')
sections={}
for entry in objects:
 isa=re.search(r'isa = (\w+);',entry).group(1)
 sections.setdefault(isa,[]).append(entry)
objects_text='\n'.join(f'/* Begin {isa} section */\n'+ '\n'.join(entries)+f'\n/* End {isa} section */' for isa,entries in sections.items())
(proj/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+objects_text+f'\n}}; rootObject = {ID("project")}; }}\n')
schemes=proj/'xcshareddata/xcschemes';schemes.mkdir(parents=True,exist_ok=True)
def ref(id,name):return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{id}" BuildableName="{name}" BlueprintName="{name.split(".")[0]}" ReferencedContainer="container:CRISIS.xcodeproj"/>'
(schemes/'CRISIS.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref(app,'CRISIS.app')}</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{ref(tests,'CRISISTests.xctest')}</TestableReference></Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref(app,'CRISIS.app')}</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref(app,'CRISIS.app')}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
print('Xcode project and shared app/test scheme generated.')
