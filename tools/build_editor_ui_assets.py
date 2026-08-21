from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw


PROJECT_ROOT = Path("/Users/kabuto/Downloads/pokedan_dungeon_prototype")
ATLAS_PATH = PROJECT_ROOT / "assets/sprites/gadget_editor_ui_parts_sheet_64_capacity5.png"
OUT_DIR = PROJECT_ROOT / "assets/sprites/editor_ui"
MANIFEST_PATH = OUT_DIR / "editor_ui_manifest.json"

CELL = 64
ATLAS_COLUMNS = 4

PARTS = [
    "editor_panel_frame",
    "code_line_slot_normal",
    "code_line_slot_selected",
    "code_line_slot_error",
    "capacity_unit_empty",
    "capacity_unit_filled",
    "capacity_unit_error",
    "capacity_meter_frame",
    "capacity_meter_fill",
    "capacity_meter_error",
    "input_cursor",
    "syntax_valid_badge",
    "syntax_error_badge",
    "line_cost_chip_frame",
    "gadget_editor_icon",
    "selection_glow_plate",
]

COLORS = {
    "transparent": (0, 0, 0, 0),
    "background": (9, 16, 18, 255),
    "grid": (56, 82, 82, 40),
    "shell": (3, 5, 5, 235),
    "panel": (9, 12, 13, 245),
    "panel_inner": (14, 19, 19, 245),
    "field": (5, 8, 9, 250),
    "field_selected": (8, 14, 14, 250),
    "border": (78, 118, 108, 150),
    "border_strong": (43, 220, 191, 255),
    "border_error": (255, 79, 93, 255),
    "border_dim": (55, 84, 81, 210),
    "teal": (43, 220, 191, 255),
    "red": (255, 79, 93, 255),
    "shadow": (0, 0, 0, 85),
}

FIXED_FRAMES = {
    "backdrop": (1152, 648),
    "shell": (1088, 592),
    "panel_header": (1040, 96),
    "panel_program": (688, 318),
    "panel_memory": (320, 318),
    "panel_output": (1032, 78),
    "row_normal": (652, 62),
    "row_selected": (652, 62),
    "row_error": (652, 62),
    "input_field": (296, 40),
    "meter_wide": (196, 26),
    "meter_small": (126, 28),
    "cost_number_normal": (40, 32),
    "cost_number_error": (40, 32),
    "status_normal": (268, 36),
    "status_error": (268, 36),
    "chip_attack": (132, 30),
    "chip_land": (132, 30),
    "chip_wall": (132, 30),
    "chip_number": (132, 30),
    "chip_trail": (132, 30),
}


def rect(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int, int, int],
    fill: tuple[int, int, int, int],
    outline: tuple[int, int, int, int] | None = None,
    width: int = 1,
) -> None:
    draw.rectangle(xy, fill=fill, outline=outline, width=width)


def draw_panel(size: tuple[int, int], fill: tuple[int, int, int, int], border: tuple[int, int, int, int]) -> Image.Image:
    w, h = size
    img = Image.new("RGBA", size, COLORS["transparent"])
    draw = ImageDraw.Draw(img)
    rect(draw, (0, 0, w - 1, h - 1), fill, border, 2)
    rect(draw, (3, 3, w - 4, h - 4), COLORS["transparent"], (35, 55, 52, 145), 1)
    return img


def draw_backdrop(size: tuple[int, int]) -> Image.Image:
    w, h = size
    img = Image.new("RGBA", size, COLORS["background"])
    draw = ImageDraw.Draw(img)
    for x in range(0, w + 1, 24):
        draw.line((x, 0, x, h), fill=COLORS["grid"], width=1)
    for y in range(0, h + 1, 24):
        draw.line((0, y, w, y), fill=COLORS["grid"], width=1)
    return img


def draw_row(size: tuple[int, int], mode: str) -> Image.Image:
    border = COLORS["border_dim"]
    fill = COLORS["field"]
    if mode == "selected":
        border = COLORS["border_strong"]
        fill = COLORS["field_selected"]
    elif mode == "error":
        border = COLORS["border_error"]

    w, h = size
    img = Image.new("RGBA", size, COLORS["transparent"])
    draw = ImageDraw.Draw(img)
    rect(draw, (0, 0, w - 1, h - 1), fill, border, 2)
    rect(draw, (2, 2, w - 3, h - 3), COLORS["transparent"], (18, 28, 28, 140), 1)
    return img


def draw_input(size: tuple[int, int]) -> Image.Image:
    w, h = size
    img = Image.new("RGBA", size, COLORS["transparent"])
    draw = ImageDraw.Draw(img)
    rect(draw, (0, 0, w - 1, h - 1), COLORS["shadow"])
    rect(draw, (5, 5, w - 6, h - 6), COLORS["field"], COLORS["border_dim"], 1)
    return img


def draw_meter_frame(size: tuple[int, int]) -> Image.Image:
    w, h = size
    img = Image.new("RGBA", size, COLORS["transparent"])
    draw = ImageDraw.Draw(img)
    rect(draw, (0, 0, w - 1, h - 1), COLORS["field"], COLORS["border"], 2)
    rect(draw, (3, 3, w - 4, h - 4), COLORS["transparent"], (19, 32, 31, 160), 1)
    return img


def draw_status(size: tuple[int, int], error: bool) -> Image.Image:
    w, h = size
    img = Image.new("RGBA", size, COLORS["transparent"])
    draw = ImageDraw.Draw(img)
    border = COLORS["border_error"] if error else COLORS["border_strong"]
    rect(draw, (0, 0, w - 1, h - 1), COLORS["field"], border, 1)
    return img


def draw_cost_number(size: tuple[int, int], error: bool) -> Image.Image:
    w, h = size
    img = Image.new("RGBA", size, COLORS["transparent"])
    draw = ImageDraw.Draw(img)
    border = COLORS["border_error"] if error else COLORS["border"]
    rect(draw, (0, 0, w - 1, h - 1), COLORS["field"], border, 1)
    rect(draw, (2, 2, w - 3, h - 3), COLORS["transparent"], (18, 28, 28, 140), 1)
    return img


def draw_chip(size: tuple[int, int]) -> Image.Image:
    w, h = size
    img = Image.new("RGBA", size, COLORS["transparent"])
    draw = ImageDraw.Draw(img)
    rect(draw, (0, 0, w - 1, h - 1), COLORS["field"], COLORS["border_dim"], 1)
    return img


def save_fixed_frames() -> dict[str, dict[str, int | str]]:
    frames: dict[str, dict[str, int | str]] = {}
    generated = {
        "backdrop": draw_backdrop(FIXED_FRAMES["backdrop"]),
        "shell": draw_panel(FIXED_FRAMES["shell"], COLORS["shell"], COLORS["border"]),
        "panel_header": draw_panel(FIXED_FRAMES["panel_header"], COLORS["panel_inner"], COLORS["border"]),
        "panel_program": draw_panel(FIXED_FRAMES["panel_program"], COLORS["panel"], COLORS["border"]),
        "panel_memory": draw_panel(FIXED_FRAMES["panel_memory"], COLORS["panel"], COLORS["border"]),
        "panel_output": draw_panel(FIXED_FRAMES["panel_output"], COLORS["panel_inner"], COLORS["border"]),
        "row_normal": draw_row(FIXED_FRAMES["row_normal"], "normal"),
        "row_selected": draw_row(FIXED_FRAMES["row_selected"], "selected"),
        "row_error": draw_row(FIXED_FRAMES["row_error"], "error"),
        "input_field": draw_input(FIXED_FRAMES["input_field"]),
        "meter_wide": draw_meter_frame(FIXED_FRAMES["meter_wide"]),
        "meter_small": draw_meter_frame(FIXED_FRAMES["meter_small"]),
        "cost_number_normal": draw_cost_number(FIXED_FRAMES["cost_number_normal"], False),
        "cost_number_error": draw_cost_number(FIXED_FRAMES["cost_number_error"], True),
        "status_normal": draw_status(FIXED_FRAMES["status_normal"], False),
        "status_error": draw_status(FIXED_FRAMES["status_error"], True),
        "chip_attack": draw_chip(FIXED_FRAMES["chip_attack"]),
        "chip_land": draw_chip(FIXED_FRAMES["chip_land"]),
        "chip_wall": draw_chip(FIXED_FRAMES["chip_wall"]),
        "chip_number": draw_chip(FIXED_FRAMES["chip_number"]),
        "chip_trail": draw_chip(FIXED_FRAMES["chip_trail"]),
    }

    for name, img in generated.items():
        path = OUT_DIR / f"{name}.png"
        validate_image(name, img, FIXED_FRAMES[name], require_full_alpha_bbox=True)
        img.save(path)
        frames[name] = {
            "path": f"res://assets/sprites/editor_ui/{path.name}",
            "width": img.width,
            "height": img.height,
        }

    return frames


def trim_atlas_parts() -> dict[str, dict[str, int | str]]:
    atlas = Image.open(ATLAS_PATH).convert("RGBA")
    parts: dict[str, dict[str, int | str]] = {}

    for index, name in enumerate(PARTS):
        x = (index % ATLAS_COLUMNS) * CELL
        y = (index // ATLAS_COLUMNS) * CELL
        cell = atlas.crop((x, y, x + CELL, y + CELL))
        bbox = cell.getchannel("A").getbbox()
        if bbox is None:
            raise ValueError(f"{name} is fully transparent")
        trimmed = cell.crop(bbox)
        validate_image(name, trimmed, (trimmed.width, trimmed.height), require_full_alpha_bbox=True)
        path = OUT_DIR / f"part_{name}.png"
        trimmed.save(path)
        parts[name] = {
            "path": f"res://assets/sprites/editor_ui/{path.name}",
            "width": trimmed.width,
            "height": trimmed.height,
        }

    return parts


def validate_image(
    name: str,
    img: Image.Image,
    expected_size: tuple[int, int],
    require_full_alpha_bbox: bool,
) -> None:
    if img.mode != "RGBA":
        raise ValueError(f"{name}: expected RGBA, got {img.mode}")
    if img.size != expected_size:
        raise ValueError(f"{name}: expected {expected_size}, got {img.size}")
    bbox = img.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError(f"{name}: image has no visible pixels")
    if require_full_alpha_bbox and bbox != (0, 0, img.width, img.height):
        raise ValueError(f"{name}: unexpected transparent padding, alpha bbox={bbox}, size={img.size}")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    frames = save_fixed_frames()
    parts = trim_atlas_parts()

    manifest = {
        "atlas_source": str(ATLAS_PATH),
        "output_dir": str(OUT_DIR),
        "frames": frames,
        "parts": parts,
        "layout": {
            "design_width": 1152,
            "design_height": 648,
            "shell": {"x": 32, "y": 28, "w": 1088, "h": 592},
            "header": {"x": 56, "y": 50, "w": 1040, "h": 96},
            "program": {"x": 60, "y": 168, "w": 688, "h": 318},
            "memory": {"x": 772, "y": 168, "w": 320, "h": 318},
            "output": {"x": 60, "y": 502, "w": 1032, "h": 78},
            "code_row": {"w": 652, "h": 62},
            "input_field": {"w": 296, "h": 40},
            "capacity": {"limit": 5, "slot_count": 5},
        },
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(MANIFEST_PATH)


if __name__ == "__main__":
    main()
