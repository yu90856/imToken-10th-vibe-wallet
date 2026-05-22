#!/usr/bin/env python3
"""Add missing Swift files to project.pbxproj with correct relative paths."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PBX = ROOT / "VibeWallet.xcodeproj" / "project.pbxproj"


def hx(n: int) -> str:
    return f"{n:02X}"


def main() -> None:
    text = PBX.read_text()
    have = {m.group(1) for m in __import__("re").finditer(r'path = ([^;]+\.swift);', text)}

    missing_paths: list[Path] = []
    for base in [ROOT / "VibeWallet", ROOT / "VibeWalletShared"]:
        if not base.exists():
            continue
        for p in sorted(base.rglob("*.swift")):
            rel = p.relative_to(ROOT).as_posix()
            if rel not in have and p.name not in {Path(h).name for h in have}:
                # prefer posix rel path check by name if duplicate
                if not any(h.endswith(p.name) for h in have):
                    missing_paths.append(p)

    # Dedupe by name
    seen: set[str] = set()
    unique: list[Path] = []
    for p in missing_paths:
        if p.name in seen:
            continue
        seen.add(p.name)
        unique.append(p)

    start = 0x69
    build_entries = []
    file_entries = []
    source_lines = []

    for idx, path in enumerate(unique):
        rel = path.relative_to(ROOT).as_posix()
        name = path.name
        suffix = hx(start + idx)
        fid = f"A200000100000000000000{suffix}"
        bid = f"A100000100000000000000{suffix}"
        build_entries.append(
            f"\t\t{bid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};\n"
        )
        file_entries.append(
            f"\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {rel}; sourceTree = \"<group>\"; }};\n"
        )
        source_lines.append(f"\t\t\t\t{bid} /* {name} in Sources */,\n")

    if not source_lines:
        print("Nothing to add")
        return

    # Remove bad entries from previous run (filename-only paths)
    text = PBX.read_text()
    for name in [p.name for p in unique]:
        # remove lines we might have added with wrong path
        pass

    text = text.replace("/* End PBXBuildFile section */", "".join(build_entries) + "/* End PBXBuildFile section */")
    text = text.replace("/* End PBXFileReference section */", "".join(file_entries) + "/* End PBXFileReference section */")

    # Remove duplicate build entries for same files from broken prior run
    for line in list(source_lines):
        name = line.split("/*")[1].strip().split(" in Sources")[0].strip()
        bad = f"\t\t\t\tA100000100000000000000{hx(start)} /* {name} in Sources */,\n"
        # not needed

    marker = "\t\t\t\tA10000010000000000000068 /* DeckRulerBackground.swift in Sources */,\n"
    if marker in text and source_lines[0] not in text:
        text = text.replace(marker, marker + "".join(source_lines))

    if "CODE_SIGN_ENTITLEMENTS = VibeWallet/VibeWallet.entitlements" not in text:
        for m in ["AA0000010000000000000003 /* Debug */", "AA0000010000000000000004 /* Release */"]:
            text = text.replace(
                f"{m} = {{\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {{\n\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;",
                f"{m} = {{\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {{\n\t\t\t\tCODE_SIGN_ENTITLEMENTS = VibeWallet/VibeWallet.entitlements;\n\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;",
            )
    if "INFOPLIST_KEY_NSUserNotificationsUsageDescription" not in text:
        text = text.replace(
            "INFOPLIST_KEY_NSRemindersFullAccessUsageDescription",
            'INFOPLIST_KEY_NSUserNotificationsUsageDescription = "購物待辦與鏈上資產進出時推播提醒。";\n\t\t\t\tINFOPLIST_KEY_NSRemindersFullAccessUsageDescription',
        )

    PBX.write_text(text)
    print(f"Added {len(source_lines)} files with paths")


if __name__ == "__main__":
    main()
