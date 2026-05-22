#!/usr/bin/env python3
"""Patch VibeWallet.xcodeproj: add missing Swift sources + widget extension target."""
from __future__ import annotations

import re
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PBX = ROOT / "VibeWallet.xcodeproj" / "project.pbxproj"

MAIN_SWIFT_DIRS = [
    ROOT / "VibeWallet",
]
SHARED_SWIFT = [ROOT / "VibeWalletShared" / "WidgetSnapshot.swift"]
WIDGET_SWIFT = list((ROOT / "VibeWalletWidgetExtension").glob("*.swift"))

# Files that belong only to widget target
WIDGET_ONLY = {p.name for p in WIDGET_SWIFT}
# Shared compiled in both
SHARED_NAMES = {p.name for p in SHARED_SWIFT}


def uid() -> str:
    return uuid.uuid4().hex[:24].upper()


def collect_main_swift() -> list[Path]:
    files: list[Path] = []
    for base in MAIN_SWIFT_DIRS:
        for p in sorted(base.rglob("*.swift")):
            if "WidgetExtension" in str(p):
                continue
            files.append(p)
    return files


def existing_paths(text: str) -> set[str]:
    return set(re.findall(r'path = ([^;]+\.swift);', text))


def add_file_reference(text: str, path: Path, file_id: str) -> str:
    name = path.name
    rel = path.relative_to(ROOT)
    line = (
        f"\t\t{file_id} /* {name} */ = {{isa = PBXFileReference; "
        f"lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = \"<group>\"; }};\n"
    )
    return text.replace("/* End PBXFileReference section */", line + "/* End PBXFileReference section */")


def add_build_file(text: str, name: str, file_id: str, build_id: str, phase_comment: str) -> str:
    line = f"\t\t{build_id} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_id} /* {name} */; }};\n"
    text = text.replace("/* End PBXBuildFile section */", line + "/* End PBXBuildFile section */")
    text = text.replace(
        f"/* {phase_comment} */ = {{",
        f"/* {phase_comment} */ = {{\n\t\t\t\t{build_id} /* {name} in Sources */,",
        1,
    )
    return text


def main() -> None:
    text = PBX.read_text()
    have = existing_paths(text)

    main_files = [p for p in collect_main_swift() if p.name not in WIDGET_ONLY]
    missing = [p for p in main_files if p.name not in have]

    for path in missing:
        name = path.name
        fid = uid()
        bid = uid()
        text = add_file_reference(text, path, fid)
        text = add_build_file(text, name, fid, bid, "Sources")

    for path in SHARED_SWIFT:
        if path.name in have:
            continue
        fid = uid()
        bid = uid()
        text = add_file_reference(text, path, fid)
        text = add_build_file(text, path.name, fid, bid, "Sources")

    # Widget extension target (minimal)
    if "VibeWalletWidgetExtension" not in text:
        widget_files = list(WIDGET_SWIFT) + SHARED_SWIFT
        w_build_ids = []
        w_file_ids = []
        for path in widget_files:
            if path.name in have and path.name not in WIDGET_ONLY:
                # shared already added to main - reuse file ref from pbxproj
                m = re.search(
                    rf"(A[0-9A-F]{{26}}) /\* {re.escape(path.name)} \*/ = {{isa = PBXFileReference;",
                    text,
                )
                fid = m.group(1) if m else uid()
            else:
                fid = uid()
                if path.name not in have:
                    text = add_file_reference(text, path, fid)
            bid = uid()
            w_file_ids.append((path.name, fid, bid))
            w_build_ids.append(bid)
            line = f"\t\t{bid} /* {path.name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {path.name} */; }};\n"
            text = text.replace("/* End PBXBuildFile section */", line + "/* End PBXBuildFile section */")

        appex_id = "A30000010000000000000002"
        target_id = "A60000010000000000000002"
        sources_phase = "A70000010000000000000004"
        fw_phase = "A40000010000000000000002"
        embed_phase = "A70000010000000000000006"
        dep_id = "A60000010000000000000003"
        proxy_id = "A60000010000000000000004"
        embed_bf = "A1000001000000000000009F"
        config_list = "A80000010000000000000004"
        debug_cfg = "AA0000010000000000000005"
        release_cfg = "AA0000010000000000000006"

        if appex_id not in text:
            text = text.replace(
                "A30000010000000000000001 /* VibeWallet.app */ = {isa = PBXFileReference;",
                f"{appex_id} /* VibeWalletWidgetExtension.appex */ = {{isa = PBXFileReference; explicitFileType = \"wrapper.app-extension\"; includeInIndex = 0; path = VibeWalletWidgetExtension.appex; sourceTree = BUILT_PRODUCTS_DIR; }};\n\t\tA30000010000000000000001 /* VibeWallet.app */ = {{isa = PBXFileReference;",
            )
            text = text.replace(
                "A30000010000000000000001 /* VibeWallet.app */,",
                f"A30000010000000000000001 /* VibeWallet.app */,\n\t\t\t\t{appex_id} /* VibeWalletWidgetExtension.appex */,",
            )

        build_lines = "\n".join(f"\t\t\t\t{bid} /* {name} in Sources */," for name, _, bid in w_file_ids)

        native = f"""
\t\t{target_id} /* VibeWalletWidgetExtension */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {config_list} /* Build configuration list for PBXNativeTarget "VibeWalletWidgetExtension" */;
\t\t\tbuildPhases = (
\t\t\t\t{sources_phase} /* Sources */,
\t\t\t\t{fw_phase} /* Frameworks */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = VibeWalletWidgetExtension;
\t\t\tproductName = VibeWalletWidgetExtension;
\t\t\tproductReference = {appex_id} /* VibeWalletWidgetExtension.appex */;
\t\t\tproductType = "com.apple.product-type.app-extension";
\t\t}};
"""
        text = text.replace("/* End PBXNativeTarget section */", native + "\n/* End PBXNativeTarget section */")

        sources_phase_block = f"""
\t\t{sources_phase} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{build_lines}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""
        fw_phase_block = f"""
\t\t{fw_phase} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""
        embed_phase_block = f"""
\t\t{embed_phase} /* Embed Foundation Extensions */ = {{
\t\t\tisa = PBXCopyFilesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tdstPath = "";
\t\t\t dstSubfolderSpec = 13;
\t\t\tfiles = (
\t\t\t\t{embed_bf} /* VibeWalletWidgetExtension.appex in Embed Foundation Extensions */,
\t\t\t);
\t\t\tname = "Embed Foundation Extensions";
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""
        # fix typo space in dstSubfolderSpec
        embed_phase_block = embed_phase_block.replace("\t\t dstSubfolderSpec", "\t\t\tdstSubfolderSpec")

        text = text.replace("/* End PBXSourcesBuildPhase section */", sources_phase_block + "\n/* End PBXSourcesBuildPhase section */")
        text = text.replace("/* End PBXFrameworksBuildPhase section */", fw_phase_block + "\n/* End PBXFrameworksBuildPhase section */")
        text = text.replace("/* End PBXCopyFilesBuildPhase section */", embed_phase_block + "\n/* End PBXCopyFilesBuildPhase section */")

        embed_bf_line = f"\t\t{embed_bf} /* VibeWalletWidgetExtension.appex in Embed Foundation Extensions */ = {{isa = PBXBuildFile; fileRef = {appex_id} /* VibeWalletWidgetExtension.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};\n"
        text = text.replace("/* End PBXBuildFile section */", embed_bf_line + "/* End PBXBuildFile section */")

        text = text.replace(
            "buildPhases = (\n\t\t\t\tA70000010000000000000001 /* Sources */,",
            "buildPhases = (\n\t\t\t\tA70000010000000000000001 /* Sources */,\n\t\t\t\tA70000010000000000000006 /* Embed Foundation Extensions */,",
            1,
        )
        text = text.replace(
            "dependencies = (\n\t\t\t);",
            f"dependencies = (\n\t\t\t\t{dep_id} /* PBXTargetDependency */,\n\t\t\t);",
            1,
        )
        text = text.replace(
            "targets = (\n\t\t\t\tA60000010000000000000001 /* VibeWallet */,",
            f"targets = (\n\t\t\t\tA60000010000000000000001 /* VibeWallet */,\n\t\t\t\t{target_id} /* VibeWalletWidgetExtension */,",
        )

        dep_block = f"""
\t\t{dep_id} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {target_id} /* VibeWalletWidgetExtension */;
\t\t\ttargetProxy = {proxy_id} /* PBXContainerItemProxy */;
\t\t}};
"""
        proxy_block = f"""
\t\t{proxy_id} /* PBXContainerItemProxy */ = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = A90000010000000000000001 /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = {target_id};
\t\t\tremoteInfo = VibeWalletWidgetExtension;
\t\t}};
"""
        if "/* Begin PBXContainerItemProxy section */" not in text:
            text = text.replace(
                "/* Begin PBXCopyFilesBuildPhase section */",
                "/* Begin PBXContainerItemProxy section */\n" + proxy_block + "/* End PBXContainerItemProxy section */\n\n/* Begin PBXCopyFilesBuildPhase section */",
            )
        text = text.replace("/* End PBXTargetDependency section */", dep_block + "/* End PBXTargetDependency section */")

        cfg_debug = f"""
\t\t{debug_cfg} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
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
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
"""
        cfg_release = cfg_debug.replace(debug_cfg, release_cfg).replace("Debug", "Release")
        text = text.replace("/* End XCBuildConfiguration section */", cfg_debug + cfg_release + "\n/* End XCBuildConfiguration section */")
        list_block = f"""
\t\t{config_list} /* Build configuration list for PBXNativeTarget "VibeWalletWidgetExtension" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{debug_cfg} /* Debug */,
\t\t\t\t{release_cfg} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
"""
        text = text.replace("/* End XCConfigurationList section */", list_block + "\n/* End XCConfigurationList section */")

        # Main app entitlements + notification usage
        for key in ["AA0000010000000000000003 /* Debug */", "AA0000010000000000000004 /* Release */"]:
            if "CODE_SIGN_ENTITLEMENTS = VibeWallet/VibeWallet.entitlements" not in text:
                text = text.replace(
                    f"{key} = {{\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {{\n\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;",
                    f"{key} = {{\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {{\n\t\t\t\tCODE_SIGN_ENTITLEMENTS = VibeWallet/VibeWallet.entitlements;\n\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;",
                )
            if "INFOPLIST_KEY_NSUserNotificationsUsageDescription" not in text:
                text = text.replace(
                    "INFOPLIST_KEY_NSRemindersFullAccessUsageDescription",
                    'INFOPLIST_KEY_NSUserNotificationsUsageDescription = "購物待辦與鏈上資產進出時推播提醒。";\n\t\t\t\tINFOPLIST_KEY_NSRemindersFullAccessUsageDescription',
                )

    PBX.write_text(text)
    print(f"Patched {PBX.name}: added {len(missing)} main sources; widget={'yes' if 'VibeWalletWidgetExtension' in text else 'no'}")


if __name__ == "__main__":
    main()
