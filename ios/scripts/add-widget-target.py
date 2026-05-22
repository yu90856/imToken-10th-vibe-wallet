#!/usr/bin/env python3
"""Add VibeWalletWidgetExtension target to project.pbxproj."""
from pathlib import Path

PBX = Path(__file__).resolve().parents[1] / "VibeWallet.xcodeproj" / "project.pbxproj"

if "VibeWalletWidgetExtension" in PBX.read_text():
    print("Widget target exists")
    raise SystemExit(0)

text = PBX.read_text()

build = """
\t\tA1000001000000000000009A /* VibeWalletWidgetBundle.swift in Sources */ = {isa = PBXBuildFile; fileRef = A2000001000000000000009A /* VibeWalletWidgetBundle.swift */; };
\t\tA1000001000000000000009B /* VibeWalletWidget.swift in Sources */ = {isa = PBXBuildFile; fileRef = A2000001000000000000009B /* VibeWalletWidget.swift */; };
\t\tA1000001000000000000009C /* WidgetSnapshot.swift in Sources */ = {isa = PBXBuildFile; fileRef = A2000001000000000000009D /* WidgetSnapshot.swift */; };
\t\tA1000001000000000000009F /* VibeWalletWidgetExtension.appex in Embed Foundation Extensions */ = {isa = PBXBuildFile; fileRef = A30000010000000000000002 /* VibeWalletWidgetExtension.appex */; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };
"""

files = """
\t\tA2000001000000000000009A /* VibeWalletWidgetBundle.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = VibeWalletWidgetBundle.swift; sourceTree = "<group>"; };
\t\tA2000001000000000000009B /* VibeWalletWidget.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = VibeWalletWidget.swift; sourceTree = "<group>"; };
\t\tA30000010000000000000002 /* VibeWalletWidgetExtension.appex */ = {isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = VibeWalletWidgetExtension.appex; sourceTree = BUILT_PRODUCTS_DIR; };
"""

text = text.replace("/* End PBXBuildFile section */", build + "/* End PBXBuildFile section */")
text = text.replace(
    "A30000010000000000000001 /* VibeWallet.app */ = {isa = PBXFileReference;",
    "A30000010000000000000002 /* VibeWalletWidgetExtension.appex */ = {isa = PBXFileReference; explicitFileType = \"wrapper.app-extension\"; includeInIndex = 0; path = VibeWalletWidgetExtension.appex; sourceTree = BUILT_PRODUCTS_DIR; };\n\t\tA30000010000000000000001 /* VibeWallet.app */ = {isa = PBXFileReference;",
)
text = text.replace("/* End PBXFileReference section */", files + "/* End PBXFileReference section */")
text = text.replace(
    "A30000010000000000000001 /* VibeWallet.app */,",
    "A30000010000000000000001 /* VibeWallet.app */,\n\t\t\t\tA30000010000000000000002 /* VibeWalletWidgetExtension.appex */,",
)

text = text.replace(
    "A50000010000000000000001 = {",
    """A50000010000000000000023 /* VibeWalletWidgetExtension */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\tA2000001000000000000009A /* VibeWalletWidgetBundle.swift */,
\t\t\t\tA2000001000000000000009B /* VibeWalletWidget.swift */,
\t\t\t);
\t\t\tpath = VibeWalletWidgetExtension;
\t\t\tsourceTree = "<group>";
\t\t};
\t\tA50000010000000000000001 = {""",
)

text = text.replace(
    "A50000010000000000000002 /* VibeWallet */,",
    "A50000010000000000000023 /* VibeWalletWidgetExtension */,\n\t\t\t\tA50000010000000000000002 /* VibeWallet */,",
)

native = """
\t\tA60000010000000000000002 /* VibeWalletWidgetExtension */ = {
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = A80000010000000000000004 /* Build configuration list for PBXNativeTarget "VibeWalletWidgetExtension" */;
\t\t\tbuildPhases = (
\t\t\t\tA70000010000000000000004 /* Sources */,
\t\t\t\tA40000010000000000000002 /* Frameworks */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = VibeWalletWidgetExtension;
\t\t\tproductName = VibeWalletWidgetExtension;
\t\t\tproductReference = A30000010000000000000002 /* VibeWalletWidgetExtension.appex */;
\t\t\tproductType = "com.apple.product-type.app-extension";
\t\t};
"""
text = text.replace("/* End PBXNativeTarget section */", native + "/* End PBXNativeTarget section */")

text = text.replace(
    "buildPhases = (\n\t\t\t\tA70000010000000000000001 /* Sources */,",
    "buildPhases = (\n\t\t\t\tA70000010000000000000001 /* Sources */,\n\t\t\t\tA70000010000000000000006 /* Embed Foundation Extensions */,",
    1,
)
text = text.replace(
    "dependencies = (\n\t\t\t);\n\t\t\tpackageProductDependencies = (",
    "dependencies = (\n\t\t\t\tA60000010000000000000003 /* PBXTargetDependency */,\n\t\t\t);\n\t\t\tpackageProductDependencies = (",
    1,
)
text = text.replace(
    "targets = (\n\t\t\t\tA60000010000000000000001 /* VibeWallet */,",
    "targets = (\n\t\t\t\tA60000010000000000000001 /* VibeWallet */,\n\t\t\t\tA60000010000000000000002 /* VibeWalletWidgetExtension */,",
)

proxy = """
/* Begin PBXContainerItemProxy section */
\t\tA60000010000000000000004 /* PBXContainerItemProxy */ = {
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = A90000010000000000000001 /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = A60000010000000000000002;
\t\t\tremoteInfo = VibeWalletWidgetExtension;
\t\t};
/* End PBXContainerItemProxy section */

"""
if "PBXContainerItemProxy" not in text:
    text = text.replace("/* Begin PBXCopyFilesBuildPhase section */", proxy + "/* Begin PBXCopyFilesBuildPhase section */")

dep = """
/* Begin PBXTargetDependency section */
\t\tA60000010000000000000003 /* PBXTargetDependency */ = {
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = A60000010000000000000002 /* VibeWalletWidgetExtension */;
\t\t\ttargetProxy = A60000010000000000000004 /* PBXContainerItemProxy */;
\t\t};
/* End PBXTargetDependency section */

"""
if "PBXTargetDependency" not in text:
    text = text.replace("/* Begin XCBuildConfiguration section */", dep + "/* Begin XCBuildConfiguration section */")

embed = """
/* Begin PBXCopyFilesBuildPhase section */
\t\tA70000010000000000000006 /* Embed Foundation Extensions */ = {
\t\t\tisa = PBXCopyFilesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tdstPath = "";
\t\t\tdstSubfolderSpec = 13;
\t\t\tfiles = (
\t\t\t\tA1000001000000000000009F /* VibeWalletWidgetExtension.appex in Embed Foundation Extensions */,
\t\t\t);
\t\t\tname = "Embed Foundation Extensions";
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXCopyFilesBuildPhase section */

"""
if "Embed Foundation Extensions" not in text:
    text = text.replace("/* Begin PBXResourcesBuildPhase section */", embed + "/* Begin PBXResourcesBuildPhase section */")

fw = """
\t\tA40000010000000000000002 /* Frameworks */ = {
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
"""
text = text.replace("/* End PBXFrameworksBuildPhase section */", fw + "/* End PBXFrameworksBuildPhase section */")

src = """
\t\tA70000010000000000000004 /* Sources */ = {
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\tA1000001000000000000009A /* VibeWalletWidgetBundle.swift in Sources */,
\t\t\t\tA1000001000000000000009B /* VibeWalletWidget.swift in Sources */,
\t\t\t\tA1000001000000000000009C /* WidgetSnapshot.swift in Sources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
"""
text = text.replace("/* End PBXSourcesBuildPhase section */", src + "/* End PBXSourcesBuildPhase section */")

# WidgetSnapshot file ref - use existing 9D from main app if present
if "A2000001000000000000009D /* WidgetSnapshot.swift */" not in text:
    text = text.replace(
        "/* End PBXFileReference section */",
        "\t\tA2000001000000000000009D /* WidgetSnapshot.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = VibeWalletShared/WidgetSnapshot.swift; sourceTree = \"<group>\"; };\n/* End PBXFileReference section */",
    )

cfg = """
\t\tAA0000010000000000000005 /* Debug */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tCODE_SIGN_ENTITLEMENTS = VibeWalletWidgetExtension/VibeWalletWidgetExtension.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = "Vibe Widget";
\t\t\t\tINFOPLIST_KEY_NSExtension_NSExtensionPointIdentifier = "com.apple.widgetkit-extension";
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 0.1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.vibe.wallet.widget;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_STRICT_CONCURRENCY = complete;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t};
\t\t\tname = Debug;
\t\t};
\t\tAA0000010000000000000006 /* Release */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tCODE_SIGN_ENTITLEMENTS = VibeWalletWidgetExtension/VibeWalletWidgetExtension.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = "Vibe Widget";
\t\t\t\tINFOPLIST_KEY_NSExtension_NSExtensionPointIdentifier = "com.apple.widgetkit-extension";
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 0.1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.vibe.wallet.widget;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_STRICT_CONCURRENCY = complete;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t};
\t\t\tname = Release;
\t\t};
"""
text = text.replace("/* End XCBuildConfiguration section */", cfg + "/* End XCBuildConfiguration section */")

clist = """
\t\tA80000010000000000000004 /* Build configuration list for PBXNativeTarget "VibeWalletWidgetExtension" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\tAA0000010000000000000005 /* Debug */,
\t\t\t\tAA0000010000000000000006 /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t};
"""
text = text.replace("/* End XCConfigurationList section */", clist + "/* End XCConfigurationList section */")

PBX.write_text(text)
print("Widget target added")
