"""Build Civilization V DDS screens and icon atlases from the project masters.

Requires Pillow 12+. Run from the repository root. Every atlas size is rendered
directly from its source crop; no output is resized from another output.
"""

from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Art" / "Source"
ATLASES = ROOT / "Art" / "Atlases"
SCREENS = ROOT / "Art" / "Screens"

RESAMPLE = Image.Resampling.LANCZOS
GOLD = (207, 151, 55, 255)
PALE_GOLD = (242, 205, 119, 255)
DARK = (7, 10, 13, 255)


def cover(image: Image.Image, size: tuple[int, int], center=(0.5, 0.5)) -> Image.Image:
    src = image.convert("RGBA")
    ratio = max(size[0] / src.width, size[1] / src.height)
    resized = src.resize((round(src.width * ratio), round(src.height * ratio)), RESAMPLE)
    left = round((resized.width - size[0]) * center[0])
    top = round((resized.height - size[1]) * center[1])
    return resized.crop((left, top, left + size[0], top + size[1]))


def crop_master(image: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    return image.crop(box).convert("RGBA")


def circle_portrait(source: Image.Image, size: int, center=(0.5, 0.5)) -> Image.Image:
    inset = max(3, round(size * 0.06))
    ring = max(2, round(size * 0.035))
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    draw.ellipse((0, 0, size - 1, size - 1), fill=DARK, outline=GOLD, width=ring)
    inner_box = (inset, inset, size - inset, size - inset)
    portrait = cover(source, (size - inset * 2, size - inset * 2), center)
    mask = Image.new("L", portrait.size, 0)
    ImageDraw.Draw(mask).ellipse((0, 0, portrait.width - 1, portrait.height - 1), fill=255)
    canvas.alpha_composite(Image.composite(portrait, Image.new("RGBA", portrait.size), mask), (inset, inset))
    draw = ImageDraw.Draw(canvas)
    draw.ellipse(inner_box, outline=PALE_GOLD, width=max(1, ring // 2))
    return canvas


def supplied_icon(
    source: Image.Image,
    size: int,
    transparent_corners: bool = True,
    crop: float = 0.055,
    slot_fill: float = 1.0,
) -> Image.Image:
    """Fit supplied icon art to a Civ V slot with consistent visual padding.

    The supplied masters contain a wide black margin around their circular
    frames.  Cropping that margin before the atlas resize keeps the subject at
    the same apparent scale as the game's stock 64/128 px icons.
    """
    margin = round(min(source.size) * crop)
    framed = source.crop((margin, margin, source.width - margin, source.height - margin))
    icon_size = max(1, round(size * slot_fill))
    icon = cover(framed, (icon_size, icon_size))
    if transparent_corners:
        scale = 4
        mask = Image.new("L", (icon_size * scale, icon_size * scale), 0)
        ImageDraw.Draw(mask).ellipse((0, 0, icon_size * scale - 1, icon_size * scale - 1), fill=255)
        icon.putalpha(mask.resize((icon_size, icon_size), RESAMPLE))
    if icon_size == size:
        return icon
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    inset = (size - icon_size) // 2
    canvas.alpha_composite(icon, (inset, inset))
    return canvas


def ant_mark(size: int, alpha_only=False) -> Image.Image:
    scale = size / 256.0
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0) if alpha_only else DARK)
    draw = ImageDraw.Draw(canvas)
    color = (255, 255, 255, 255) if alpha_only else GOLD
    width = max(2, round(9 * scale))
    cx = size // 2
    # Ant body: head, thorax, abdomen.
    draw.ellipse((cx - 25 * scale, 31 * scale, cx + 25 * scale, 81 * scale), fill=color)
    draw.ellipse((cx - 31 * scale, 87 * scale, cx + 31 * scale, 143 * scale), fill=color)
    draw.ellipse((cx - 44 * scale, 145 * scale, cx + 44 * scale, 232 * scale), fill=color)
    # Antennae and six legs.
    draw.line((cx - 13 * scale, 38 * scale, cx - 54 * scale, 5 * scale), fill=color, width=width)
    draw.line((cx + 13 * scale, 38 * scale, cx + 54 * scale, 5 * scale), fill=color, width=width)
    for y, reach, end_y in ((103, 91, 72), (120, 105, 120), (137, 91, 176)):
        draw.line((cx - 21 * scale, y * scale, cx - reach * scale, end_y * scale), fill=color, width=width)
        draw.line((cx + 21 * scale, y * scale, cx + reach * scale, end_y * scale), fill=color, width=width)
    if not alpha_only:
        draw.ellipse((4 * scale, 4 * scale, 252 * scale, 252 * scale), outline=GOLD, width=max(2, round(6 * scale)))
        draw.ellipse((14 * scale, 14 * scale, 242 * scale, 242 * scale), outline=(91, 61, 22, 255), width=max(1, round(3 * scale)))
    return canvas


def save_dds(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    rgba = image.convert("RGBA")
    if rgba.width % 4 == 0 and rgba.height % 4 == 0:
        rgba.save(path, format="DDS", pixel_format="DXT5")
    else:
        # Civ V's compact tech-tree icons are 45 px high. DXT block
        # compression is unreliable for that non-multiple-of-four dimension;
        # stock-compatible 45 px atlases use uncompressed 32-bit DDS instead.
        rgba.save(path, format="DDS")


def build() -> None:
    concept = Image.open(SOURCE / "Gabriel_Concept_Sheet.png").convert("RGBA")
    leader = Image.open(SOURCE / "Gabriel_Leader_Master.png").convert("RGBA")
    swarm_host_icon = Image.open(SOURCE / "Gabriel_Swarm_Host_Icon.png").convert("RGBA")
    civ_icon = Image.open(SOURCE / "Gabriel_Civ_Icon.png").convert("RGBA")
    colony_nexus_icon = Image.open(SOURCE / "Gabriel_Colony_Nexus_Icon.png").convert("RGBA")

    # Full-screen art.
    diplomacy = cover(leader, (1600, 900), center=(0.49, 0.50))
    save_dds(diplomacy, SCREENS / "Gabriel_Diplomacy.dds")
    dom = diplomacy.copy()
    shade = Image.new("RGBA", dom.size, (0, 0, 0, 0))
    shade_draw = ImageDraw.Draw(shade)
    for x in range(dom.width):
        alpha = int(max(0, (x / dom.width - 0.55) / 0.45) * 85)
        shade_draw.line((x, 0, x, dom.height), fill=(0, 0, 0, alpha))
    dom = Image.alpha_composite(dom, shade)
    save_dds(dom, SCREENS / "Gabriel_DOM.dds")
    save_dds(cover(concept, (1600, 900), center=(0.50, 0.50)), SCREENS / "Gabriel_Map.dds")
    # Dawn of Man uses a wide panorama; setup's LargeMapImage is 360x410.
    network_map = cover(Image.open(SOURCE / "Gabriel_Colony_Network_Map.png").convert("RGBA"), (1600, 900), center=(0.50, 0.50))
    save_dds(network_map, SCREENS / "Gabriel_Colony_Network_Map.dds")
    selection_map = cover(
        Image.open(SOURCE / "Gabriel_Selection_Map.png").convert("RGBA"),
        (360, 410),
    )
    # Legacy uncompressed DDS supports the panel's non-block-aligned height.
    save_dds(selection_map, SCREENS / "Gabriel_Selection_Map.dds")

    # Canonical object crops from the supplied concept sheet.
    node_master = crop_master(concept, (750, 423, 936, 594))
    infestation_master = crop_master(concept, (718, 646, 871, 770))
    # A deliberately tight portrait crop: the 128 px leader slot must read as
    # a face/upper-body portrait rather than a miniaturized diplomacy screen.
    leader_master = crop_master(leader, (180, 0, 820, 920))

    for size in (256, 128, 80, 64, 45, 32):
        save_dds(supplied_icon(civ_icon, size), ATLASES / f"Gabriel_Civ_{size}.dds")
        row = Image.new("RGBA", (size * 4, size), (0, 0, 0, 0))
        row.alpha_composite(
            supplied_icon(swarm_host_icon, size, crop=0.0, slot_fill=0.92),
            (0, 0),
        )
        row.alpha_composite(supplied_icon(colony_nexus_icon, size), (size, 0))
        row.alpha_composite(circle_portrait(node_master, size, center=(0.45, 0.52)), (size * 2, 0))
        row.alpha_composite(circle_portrait(infestation_master, size, center=(0.60, 0.45)), (size * 3, 0))
        save_dds(row, ATLASES / f"Gabriel_Objects_{size}.dds")

    for size in (256, 128, 64):
        save_dds(circle_portrait(leader_master, size, center=(0.48, 0.30)), ATLASES / f"Gabriel_Leader_{size}.dds")

    for size in (128, 64, 48, 32, 24, 16):
        save_dds(ant_mark(size, alpha_only=True), ATLASES / f"Gabriel_Alpha_{size}.dds")


if __name__ == "__main__":
    build()
    print("Built Gabriel DDS screens and atlases.")
