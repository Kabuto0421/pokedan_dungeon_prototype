from pathlib import Path
import json
import math
import random

from PIL import Image, ImageDraw


PROJECT_ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = PROJECT_ROOT / "assets/sprites/effects"
OUTPUT_PATH = OUT_DIR / "element_connection_atlas_24.png"
MANIFEST_PATH = OUT_DIR / "element_connection_atlas_manifest.json"
PREVIEW_PATH = PROJECT_ROOT / "outputs/element_connection_cross_preview.png"

CELL = 24
PREVIEW_SCALE = 4

UP = 1
RIGHT = 2
DOWN = 4
LEFT = 8
ORIGIN_COLUMN = 16

DIRECTIONS = (
    (UP, (0, -1)),
    (RIGHT, (1, 0)),
    (DOWN, (0, 1)),
    (LEFT, (-1, 0)),
)

ELEMENTS = [
    {
        "id": "normal",
        "outer": (228, 214, 168, 82),
        "mid": (255, 241, 198, 144),
        "inner": (255, 255, 238, 218),
        "accent": (127, 111, 83, 170),
        "style": "dust",
    },
    {
        "id": "fire",
        "outer": (197, 45, 12, 96),
        "mid": (245, 104, 21, 168),
        "inner": (255, 226, 96, 238),
        "accent": (255, 61, 14, 198),
        "style": "fire",
    },
    {
        "id": "ice",
        "outer": (59, 157, 232, 90),
        "mid": (91, 224, 255, 164),
        "inner": (231, 255, 255, 232),
        "accent": (30, 98, 226, 185),
        "style": "ice",
    },
    {
        "id": "lightning",
        "outer": (40, 113, 225, 90),
        "mid": (255, 221, 49, 176),
        "inner": (255, 255, 229, 246),
        "accent": (77, 190, 255, 194),
        "style": "lightning",
    },
    {
        "id": "poison",
        "outer": (54, 151, 36, 86),
        "mid": (92, 229, 50, 152),
        "inner": (201, 255, 101, 226),
        "accent": (139, 54, 173, 186),
        "style": "poison",
    },
]


def _draw_line(draw: ImageDraw.ImageDraw, points: list[tuple[int, int]], color, width: int) -> None:
    if len(points) >= 2:
        draw.line(points, fill=color, width=width, joint="curve")


def _arm_points(cx: int, cy: int, dx: int, dy: int, style: str, seed: int) -> list[tuple[int, int]]:
    end_x = cx + dx * (CELL // 2 + 1)
    end_y = cy + dy * (CELL // 2 + 1)

    if style == "lightning":
        rng = random.Random(seed)
        points = [(cx, cy)]
        for step in range(1, 4):
            t = step / 4.0
            px = round(cx + (end_x - cx) * t)
            py = round(cy + (end_y - cy) * t)
            jitter = rng.choice([-2, -1, 1, 2])
            if dx == 0:
                px += jitter
            else:
                py += jitter
            points.append((px, py))
        points.append((end_x, end_y))
        return points

    points = []
    for step in range(5):
        t = step / 4.0
        px = round(cx + (end_x - cx) * t)
        py = round(cy + (end_y - cy) * t)
        wave = round(math.sin(t * math.pi * 2.0) * 1.4)
        if dx == 0:
            px += wave
        else:
            py += wave
        points.append((px, py))
    return points


def _draw_particle(draw: ImageDraw.ImageDraw, x: int, y: int, color, size: int = 1) -> None:
    draw.rectangle((x, y, x + size - 1, y + size - 1), fill=color)


def _draw_style_particles(
    draw: ImageDraw.ImageDraw,
    element: dict,
    ox: int,
    oy: int,
    mask: int,
    seed: int,
) -> None:
    rng = random.Random(seed)
    style = element["style"]
    colors = [element["mid"], element["inner"], element["accent"]]

    for bit, (dx, dy) in DIRECTIONS:
        if mask & bit == 0:
            continue
        for _ in range(3):
            base_x = ox + CELL // 2 + dx * rng.randint(4, 10)
            base_y = oy + CELL // 2 + dy * rng.randint(4, 10)
            if dx == 0:
                base_x += rng.randint(-5, 5)
            else:
                base_y += rng.randint(-5, 5)
            color = rng.choice(colors)
            if style == "poison":
                radius = rng.choice([1, 2])
                draw.ellipse((base_x - radius, base_y - radius, base_x + radius, base_y + radius), fill=color)
            elif style == "ice":
                draw.polygon(
                    [
                        (base_x, base_y - 2),
                        (base_x + 2, base_y),
                        (base_x, base_y + 2),
                        (base_x - 2, base_y),
                    ],
                    fill=color,
                )
            elif style == "fire":
                draw.polygon(
                    [
                        (base_x, base_y - 3),
                        (base_x + 2, base_y + 1),
                        (base_x, base_y + 2),
                        (base_x - 2, base_y + 1),
                    ],
                    fill=color,
                )
            else:
                _draw_particle(draw, base_x, base_y, color, rng.choice([1, 2]))


def _draw_ring(draw: ImageDraw.ImageDraw, ox: int, oy: int, element: dict, strong: bool) -> None:
    cx = ox + CELL // 2
    cy = oy + CELL // 2
    ring_alpha = element["mid"] if strong else element["outer"]
    inner_alpha = element["inner"] if strong else element["mid"]
    draw.arc((cx - 7, cy - 7, cx + 7, cy + 7), 18, 148, fill=ring_alpha, width=2)
    draw.arc((cx - 7, cy - 7, cx + 7, cy + 7), 198, 334, fill=ring_alpha, width=2)
    draw.arc((cx - 4, cy - 4, cx + 4, cy + 4), 0, 360, fill=inner_alpha, width=1)


def _draw_cell(draw: ImageDraw.ImageDraw, element: dict, x: int, y: int, mask: int, is_origin: bool) -> None:
    ox = x * CELL
    oy = y * CELL
    cx = ox + CELL // 2
    cy = oy + CELL // 2
    style = element["style"]
    active_mask = mask

    _draw_ring(draw, ox, oy, element, is_origin or active_mask != 0)

    if active_mask == 0:
        draw.ellipse((cx - 2, cy - 2, cx + 2, cy + 2), fill=element["inner"])
        _draw_style_particles(draw, element, ox, oy, UP | RIGHT | DOWN | LEFT, y * 101 + x)
        return

    for bit, (dx, dy) in DIRECTIONS:
        if active_mask & bit == 0:
            continue
        points = _arm_points(cx, cy, dx, dy, style, y * 137 + x * 19 + bit)
        _draw_line(draw, points, element["outer"], 8 if style != "lightning" else 6)
        _draw_line(draw, points, element["mid"], 5 if style != "lightning" else 3)
        _draw_line(draw, points, element["inner"], 2)

        edge_x = cx + dx * (CELL // 2)
        edge_y = cy + dy * (CELL // 2)
        if style == "ice":
            draw.polygon(
                [
                    (edge_x, edge_y),
                    (edge_x - dy * 2 - dx, edge_y + dx * 2 - dy),
                    (edge_x + dx * 3, edge_y + dy * 3),
                    (edge_x + dy * 2 - dx, edge_y - dx * 2 - dy),
                ],
                fill=element["inner"],
            )
        elif style == "poison":
            draw.ellipse((edge_x - 2, edge_y - 2, edge_x + 2, edge_y + 2), fill=element["mid"])

    if is_origin:
        draw.ellipse((cx - 4, cy - 4, cx + 4, cy + 4), fill=element["mid"])
        draw.ellipse((cx - 2, cy - 2, cx + 2, cy + 2), fill=element["inner"])
    else:
        draw.ellipse((cx - 2, cy - 2, cx + 2, cy + 2), fill=element["mid"])

    _draw_style_particles(draw, element, ox, oy, active_mask, y * 211 + x * 17)


def build_atlas() -> Image.Image:
    cols = ORIGIN_COLUMN + 1
    rows = len(ELEMENTS)
    image = Image.new("RGBA", (cols * CELL, rows * CELL), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    for row, element in enumerate(ELEMENTS):
        for mask in range(16):
            _draw_cell(draw, element, mask, row, mask, False)
        _draw_cell(draw, element, ORIGIN_COLUMN, row, 0, True)

    return image


def _floor_tile(draw: ImageDraw.ImageDraw, x: int, y: int, cell: int) -> None:
    px = x * cell
    py = y * cell
    shade = 92 + ((x * 11 + y * 7) % 5) * 4
    draw.rectangle((px, py, px + cell - 1, py + cell - 1), fill=(shade, 82, 64, 255))
    draw.rectangle((px + 1, py + 1, px + cell - 2, py + cell - 2), outline=(25, 24, 21, 180), width=1)


def _mask_for(cell: tuple[int, int], cells: set[tuple[int, int]]) -> int:
    x, y = cell
    mask = 0
    if (x, y - 1) in cells:
        mask |= UP
    if (x + 1, y) in cells:
        mask |= RIGHT
    if (x, y + 1) in cells:
        mask |= DOWN
    if (x - 1, y) in cells:
        mask |= LEFT
    return mask


def build_preview(atlas: Image.Image) -> Image.Image:
    board_w = 7
    board_h = 7
    panel_gap = 14
    panel_w = board_w * CELL
    panel_h = board_h * CELL
    preview = Image.new(
        "RGBA",
        (len(ELEMENTS) * panel_w + (len(ELEMENTS) - 1) * panel_gap, panel_h),
        (7, 11, 13, 255),
    )
    draw = ImageDraw.Draw(preview)

    cross_cells = {(3, 3)}
    for i in range(1, 3):
        cross_cells.add((3, 3 - i))
        cross_cells.add((3, 3 + i))
        cross_cells.add((3 - i, 3))
        cross_cells.add((3 + i, 3))

    for row, _element in enumerate(ELEMENTS):
        ox = row * (panel_w + panel_gap)
        panel = Image.new("RGBA", (panel_w, panel_h), (7, 11, 13, 255))
        panel_draw = ImageDraw.Draw(panel)
        for y in range(board_h):
            for x in range(board_w):
                _floor_tile(panel_draw, x, y, CELL)

        for cell_pos in sorted(cross_cells, key=lambda c: abs(c[0] - 3) + abs(c[1] - 3), reverse=True):
            x, y = cell_pos
            col = _mask_for(cell_pos, cross_cells)
            src = atlas.crop((col * CELL, row * CELL, (col + 1) * CELL, (row + 1) * CELL))
            panel.alpha_composite(src, (x * CELL, y * CELL))
            if cell_pos == (3, 3):
                origin_src = atlas.crop(
                    (ORIGIN_COLUMN * CELL, row * CELL, (ORIGIN_COLUMN + 1) * CELL, (row + 1) * CELL)
                )
                panel.alpha_composite(origin_src, (x * CELL, y * CELL))

        preview.alpha_composite(panel, (ox, 0))

    return preview.resize((preview.width * PREVIEW_SCALE, preview.height * PREVIEW_SCALE), Image.Resampling.NEAREST)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)

    atlas = build_atlas()
    atlas.save(OUTPUT_PATH)

    preview = build_preview(atlas)
    preview.save(PREVIEW_PATH)

    manifest = {
        "texture": "res://assets/sprites/effects/element_connection_atlas_24.png",
        "cell_size": [CELL, CELL],
        "rows": [element["id"] for element in ELEMENTS],
        "columns": {str(mask): mask for mask in range(16)} | {"origin": ORIGIN_COLUMN},
        "mask_bits": {"up": UP, "right": RIGHT, "down": DOWN, "left": LEFT},
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    print(f"Wrote {OUTPUT_PATH}")
    print(f"Wrote {MANIFEST_PATH}")
    print(f"Wrote {PREVIEW_PATH}")


if __name__ == "__main__":
    main()
