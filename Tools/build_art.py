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
    crop: float | None = None,
    slot_fill: float = 0.78,
) -> Image.Image:
    """Fit supplied icon art to a Civ V slot with consistent visual padding.

    Normalize the supplied gold rim before fitting it inside the transparent
    atlas cell. The stock selection UI adds its own frame around the artwork;
    filling an entire 64px cell makes our portrait larger than its neighbors.
    """
    if crop is None:
        # The gold rim intersects both center scanlines. Ignore the black
        # margin outside it, which differs between the three supplied masters.
        rgb = source.convert("RGB")
        xs = [x for x in range(rgb.width) if max(rgb.getpixel((x, rgb.height // 2))) >= 70]
        ys = [y for y in range(rgb.height) if max(rgb.getpixel((rgb.width // 2, y))) >= 70]
        if not xs or not ys:
            raise ValueError("Icon master has no visible central rim")
        framed = source.crop((xs[0], ys[0], xs[-1] + 1, ys[-1] + 1))
    else:
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


def pad_portrait(portrait: Image.Image, size: int, fill: float) -> Image.Image:
    """Match the visible stock portrait diameter without changing atlas cells."""
    inner = round(size * fill)
    canvas = Image.new("RGBA", (size, size))
    canvas.alpha_composite(portrait.resize((inner, inner), RESAMPLE),
                           ((size - inner) // 2, (size - inner) // 2))
    return canvas


def ant_mark(size: int, alpha_only=False) -> Image.Image:
    # A connected heraldic silhouette: bent antennae, six jointed legs and
    # a distinct narrow waist. Render large first so 16px city emblems retain
    # smooth contours instead of the old independently rounded 2px strokes.
    supersample = 4
    mask = Image.new("L", (256 * supersample, 256 * supersample))
    draw = ImageDraw.Draw(mask)
    stroke = 16 if size <= 24 else 13

    def limb(points, width):
        draw.line([(x * supersample, y * supersample) for x, y in points],
                  fill=255, width=width * supersample, joint="curve")

    def oval(box):
        draw.ellipse(tuple(v * supersample for v in box), fill=255)

    for reflected in (False, True):
        def mirror(points):
            return [(256 - x if reflected else x, y) for x, y in points]
        limb(mirror([(113, 55), (98, 35), (91, 20)]), stroke)
        limb(mirror([(114, 107), (79, 94), (64, 61)]), stroke)
        limb(mirror([(110, 124), (66, 129), (32, 115)]), stroke)
        limb(mirror([(116, 140), (80, 166), (64, 202)]), stroke)
    limb([(128, 78), (128, 170)], 14)
    oval((101, 44, 155, 92))
    oval((107, 103, 149, 147))
    oval((90, 163, 166, 236))
    alpha = mask.resize((size, size), RESAMPLE)
    # White RGB even under transparent pixels prevents dark fringes when
    # Civ V tints/filter-samples the emblem with the player's color.
    mark = Image.new("RGBA", (size, size), (255, 255, 255, 255) if alpha_only else GOLD)
    mark.putalpha(alpha)
    if alpha_only:
        return mark
    canvas = Image.new("RGBA", (size, size), DARK)
    canvas.alpha_composite(mark)
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
            supplied_icon(swarm_host_icon, size),
            (0, 0),
        )
        row.alpha_composite(supplied_icon(colony_nexus_icon, size), (size, 0))
        row.alpha_composite(pad_portrait(circle_portrait(node_master, size, center=(0.45, 0.52)), size, 0.78), (size * 2, 0))
        row.alpha_composite(pad_portrait(circle_portrait(infestation_master, size, center=(0.60, 0.45)), size, 0.78), (size * 3, 0))
        save_dds(row, ATLASES / f"Gabriel_Objects_{size}.dds")

    for size in (256, 128, 64):
        save_dds(pad_portrait(circle_portrait(leader_master, size, center=(0.48, 0.30)), size, 0.75), ATLASES / f"Gabriel_Leader_{size}.dds")

    for size in (128, 64, 48, 32, 24, 16):
        # Tiny tintable masks benefit from full 8-bit alpha rather than DXT5
        # block compression, especially at the city banner's 16/24px sizes.
        ant_mark(size, alpha_only=True).save(ATLASES / f"Gabriel_Alpha_{size}.dds", format="DDS")


if __name__ == "__main__":
    build()
    print("Built Gabriel DDS screens and atlases.")
