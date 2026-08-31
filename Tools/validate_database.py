"""Code-level validation against an initialized CP Civ V debug database."""

from __future__ import annotations

import sqlite3
import sys
import xml.etree.ElementTree as ET
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: validate_database.py <Civ5DebugDatabase.db>")
        return 2

    source = sqlite3.connect(sys.argv[1])
    database = sqlite3.connect(":memory:")
    source.backup(database)
    source.close()

    # DebugDatabase excludes the separate localization database. Mirror the
    # standard mod-facing table so localization SQL can still be parsed and
    # checked for duplicate/malformed rows.
    database.execute(
        "CREATE TABLE IF NOT EXISTS Language_en_US "
        "(Tag TEXT PRIMARY KEY, Text TEXT, Gender TEXT, Plurality TEXT)"
    )

    for sql_path in (ROOT / "SQL" / "00_Gabriel_Core.sql", ROOT / "SQL" / "10_Gabriel_Text.sql"):
        try:
            database.executescript(sql_path.read_text(encoding="utf-8"))
            print(f"PASS SQL: {sql_path.name}")
        except sqlite3.Error as error:
            print(f"FAIL SQL: {sql_path.name}: {error}")
            return 1

    expected = {
        "Civilizations": "CIVILIZATION_GABRIEL_COLONY",
        "Leaders": "LEADER_GABRIEL_COLONY_MIND",
        "Traits": "TRAIT_GABRIEL_COLONY_NETWORK",
        "Units": "UNIT_GABRIEL_SWARM_HOST",
        "Buildings": "BUILDING_GABRIEL_COLONY_NEXUS",
        "Improvements": "IMPROVEMENT_GABRIEL_COLONY_NODE",
    }
    for table, object_type in expected.items():
        found = database.execute(f"SELECT COUNT(*) FROM {table} WHERE Type = ?", (object_type,)).fetchone()[0]
        if found != 1:
            print(f"FAIL OBJECT: {object_type} count={found}")
            return 1
        print(f"PASS OBJECT: {object_type}")

    unresolved = []
    for atlas, size, filename in database.execute(
        "SELECT Atlas, IconSize, Filename FROM IconTextureAtlases WHERE Atlas LIKE 'GABRIEL_%'"
    ):
        if not (ROOT / "Art" / "Atlases" / filename).exists():
            unresolved.append((atlas, size, filename))
    if unresolved:
        print(f"FAIL ART: missing atlas files {unresolved}")
        return 1
    print("PASS ART: all registered atlas files exist")

    modinfo = ROOT / "Gabriel The Colony Mind (v 1).modinfo"
    if modinfo.exists():
        tree = ET.parse(modinfo)
        print("PASS XML: modinfo is well formed")
        for file_node in tree.findall("./Files/File"):
            relative = (file_node.text or "").replace("\\", "/")
            target = ROOT / relative
            if not target.exists():
                print(f"FAIL MODINFO: missing {relative}")
                return 1
            actual = hashlib.md5(target.read_bytes()).hexdigest().upper()
            expected_hash = (file_node.attrib.get("md5") or "").upper()
            if actual != expected_hash:
                print(f"FAIL MODINFO: stale MD5 for {relative}: {expected_hash} != {actual}")
                return 1
        print("PASS MODINFO: every listed file exists and matches its MD5")

    for xml_path in (ROOT / "UI" / "Gabriel_NodePlacement.xml", ROOT / "Art" / "Gabriel_LeaderScene.xml"):
        ET.parse(xml_path)
        print(f"PASS XML: {xml_path.name} is well formed")

    print("All code-level database checks passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
