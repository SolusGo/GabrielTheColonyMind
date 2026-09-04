"""Code-level validation against an initialized CP Civ V debug database."""

from __future__ import annotations

import sqlite3
import sys
import xml.etree.ElementTree as ET
import hashlib
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SUPPORTED_TWCENMT_FONTS = {
    "TwCenMT14",
    "TwCenMT16",
    "TwCenMT18",
    "TwCenMT20",
    "TwCenMT22",
    "TwCenMT24",
}


def dds_dimensions(path: Path) -> tuple[int, int]:
    """Read width and height from the standard 128-byte DDS header."""
    header = path.read_bytes()[:20]
    if len(header) < 20 or header[:4] != b"DDS ":
        raise ValueError(f"not a DDS file: {path}")
    height, width = struct.unpack_from("<II", header, 12)
    return width, height


def dds_fourcc(path: Path) -> bytes:
    """Read the DDS pixel-format FourCC; zero bytes mean uncompressed RGB(A)."""
    header = path.read_bytes()[:88]
    if len(header) < 88 or header[:4] != b"DDS ":
        raise ValueError(f"not a DDS file: {path}")
    return header[84:88]


def remove_existing_gabriel_rows(database: sqlite3.Connection) -> None:
    """Return a copied live debug DB to its pre-Gabriel state for repeatable checks."""
    tables = [
        row[0]
        for row in database.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'"
        )
    ]
    for table in tables:
        safe_table = table.replace('"', '""')
        columns = [row[1] for row in database.execute(f'PRAGMA table_info("{safe_table}")')]
        if not columns:
            continue
        filters = []
        for column in columns:
            safe_column = column.replace('"', '""')
            filters.append(f'CAST("{safe_column}" AS TEXT) LIKE ?')
        database.execute(
            f'DELETE FROM "{safe_table}" WHERE ' + " OR ".join(filters),
            ["%GABRIEL%"] * len(filters),
        )


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: validate_database.py <Civ5DebugDatabase.db>")
        return 2

    source = sqlite3.connect(sys.argv[1])
    database = sqlite3.connect(":memory:")
    source.backup(database)
    source.close()
    remove_existing_gabriel_rows(database)

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

    node_art, node_defense = database.execute(
        "SELECT ArtDefineTag, DefenseModifier FROM Improvements "
        "WHERE Type = 'IMPROVEMENT_GABRIEL_COLONY_NODE'"
    ).fetchone()
    if node_art != "ART_DEF_IMPROVEMENT_FORT" or int(node_defense or 0) != 0:
        print(
            "FAIL NODE ART: expected visual Fort landmark with zero defensive gameplay bonus, "
            f"got art={node_art!r}, defense={node_defense!r}"
        )
        return 1
    print("PASS NODE ART: stock Fort landmark is visual-only")

    gabriel_start = list(
        database.execute(
            "SELECT UnitClassType, UnitAIType, Count FROM Civilization_FreeUnits "
            "WHERE CivilizationType = 'CIVILIZATION_GABRIEL_COLONY' ORDER BY 1, 2, 3"
        )
    )
    standard_start = list(
        database.execute(
            "SELECT UnitClassType, UnitAIType, Count FROM Civilization_FreeUnits "
            "WHERE CivilizationType = 'CIVILIZATION_AMERICA' ORDER BY 1, 2, 3"
        )
    )
    if gabriel_start != standard_start:
        print(f"FAIL START: Gabriel {gabriel_start} != standard CP {standard_start}")
        return 1
    print("PASS START: Gabriel matches the standard CP starting-unit package")

    required_pedia_tags = (
        "TXT_KEY_CIV5_GABRIEL_TITLE",
        "TXT_KEY_CIV5_GABRIEL_HEADING_1",
        "TXT_KEY_CIV5_GABRIEL_TEXT_1",
        "TXT_KEY_CIVILOPEDIA_LEADERS_GABRIEL_NAME",
        "TXT_KEY_CIVILOPEDIA_LEADERS_GABRIEL_SUBTITLE",
        "TXT_KEY_CIVILOPEDIA_LEADERS_GABRIEL_LIVED",
        "TXT_KEY_CIVILOPEDIA_LEADERS_GABRIEL_HEADING_1",
        "TXT_KEY_CIVILOPEDIA_LEADERS_GABRIEL_TEXT_1",
    )
    missing_pedia = [
        tag
        for tag in required_pedia_tags
        if database.execute(
            "SELECT COUNT(*) FROM Language_en_US WHERE Tag = ?", (tag,)
        ).fetchone()[0]
        != 1
    ]
    if missing_pedia:
        print(f"FAIL PEDIA: missing tags {missing_pedia}")
        return 1
    print("PASS PEDIA: civilization and leader key families are complete")

    trait_tags = database.execute(
        "SELECT Description, ShortDescription FROM Traits "
        "WHERE Type = 'TRAIT_GABRIEL_COLONY_NETWORK'"
    ).fetchone()
    trait_description = database.execute(
        "SELECT Text FROM Language_en_US WHERE Tag = ?", (trait_tags[0],)
    ).fetchone()
    trait_name = database.execute(
        "SELECT Text FROM Language_en_US WHERE Tag = ?", (trait_tags[1],)
    ).fetchone()
    if (
        trait_description is None
        or trait_name is None
        or trait_description[0] == trait_name[0]
        or len(trait_description[0]) <= len(trait_name[0])
    ):
        print("FAIL TRAIT UI: Description must be the ability body, not the short name")
        return 1
    print("PASS TRAIT UI: description and short name are wired separately")

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

    wrong_dimensions = []
    for atlas, size, filename, columns, rows in database.execute(
        "SELECT Atlas, IconSize, Filename, IconsPerRow, IconsPerColumn "
        "FROM IconTextureAtlases WHERE Atlas LIKE 'GABRIEL_%'"
    ):
        path = ROOT / "Art" / "Atlases" / filename
        actual = dds_dimensions(path)
        expected_size = (int(size) * int(columns), int(size) * int(rows))
        if actual != expected_size:
            wrong_dimensions.append((atlas, size, filename, actual, expected_size))
    if wrong_dimensions:
        print(f"FAIL ART DIMENSIONS: {wrong_dimensions}")
        return 1
    print("PASS ART DIMENSIONS: every atlas exactly matches its registered icon grid")

    compressed_45px = [
        filename
        for _, size, filename in database.execute(
            "SELECT Atlas, IconSize, Filename FROM IconTextureAtlases "
            "WHERE Atlas LIKE 'GABRIEL_%' AND IconSize = 45"
        )
        if dds_fourcc(ROOT / "Art" / "Atlases" / filename) != b"\x00\x00\x00\x00"
    ]
    if compressed_45px:
        print(f"FAIL ART FORMAT: 45px tech-tree atlases must be uncompressed: {compressed_45px}")
        return 1
    print("PASS ART FORMAT: 45px tech-tree atlases use uncompressed RGBA DDS")

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
        xml_tree = ET.parse(xml_path)
        print(f"PASS XML: {xml_path.name} is well formed")
        if xml_path.name == "Gabriel_NodePlacement.xml":
            unsupported_fonts = sorted(
                {
                    font
                    for node in xml_tree.iter()
                    if (font := node.attrib.get("Font", "")).startswith("TwCenMT")
                    and font not in SUPPORTED_TWCENMT_FONTS
                }
            )
            if unsupported_fonts:
                print(f"FAIL UI FONTS: unsupported Font.xml names {unsupported_fonts}")
                return 1
            print("PASS UI FONTS: every TwCenMT name exists in Civ V Font.xml")

    print("All code-level database checks passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
