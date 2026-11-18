"""Render an MP4 playback from the exported GAMA pedestrian trace."""
import csv
from collections import defaultdict
from pathlib import Path

import imageio.v2 as imageio
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "results"
MODEL = ROOT / "model"
TRACE = RESULTS / "gama_midpoint_trace.csv"
WEATHER = MODEL / "environment_2020-08-13.csv"
OUTPUT = RESULTS / "DaxueRoad_GAMA_TraceReplay.mp4"
POSTER = RESULTS / "DaxueRoad_GAMA_TraceReplay_poster.png"

WIDTH, HEIGHT = 1280, 720
ROAD_LENGTH = 262.821
SITE_B = 135.0
DEVICE_LENGTH = 8.0
DEVICE_SPAN = 4.6
LANE_OFFSET = 6.5
FRAMES_PER_SECOND = 24

BG = "#F4F2EB"
INK = "#20342F"
MUTED = "#6D7A73"
ROAD = "#C8CBC7"
WALK = "#E4E3DB"
GREEN = "#96B69B"
GREEN_DARK = "#52765D"
GOLD = "#E9C975"
TEAL = "#287E79"
BLUE = "#466E9B"
ORANGE = "#D97746"
WHITE = "#FFFFFF"


def load_font(size, bold=False):
    candidates = [
        r"C:\Windows\Fonts\msyhbd.ttc" if bold else r"C:\Windows\Fonts\msyh.ttc",
        r"C:\Windows\Fonts\msyh.ttc",
        r"C:\Windows\Fonts\arial.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


FONT_12 = load_font(12)
FONT_14 = load_font(14)
FONT_16 = load_font(16)
FONT_18 = load_font(18)
FONT_20 = load_font(20, True)
FONT_28 = load_font(28, True)
FONT_32 = load_font(32, True)


def read_rows(path):
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


trace_rows = read_rows(TRACE)
weather_rows = read_rows(WEATHER)
frames = defaultdict(list)
for row in trace_rows:
    frames[int(row["frame"])].append(row)
frame_ids = sorted(frames)
if not frame_ids:
    raise SystemExit("GAMA trace has no frames")

# Geometry in the view stays proportionate to the simplified 262.8 x 38 m GAMA world.
MAP_X0, MAP_X1 = 112, 1168
MAP_CENTER_Y = 382
SCALE_X = (MAP_X1 - MAP_X0) / ROAD_LENGTH
SCALE_Y = SCALE_X


def map_x(chainage):
    return MAP_X0 + float(chainage) * SCALE_X


def map_y(lateral):
    return MAP_CENTER_Y - (float(lateral) - 19.0) * SCALE_Y


def rounded(draw, box, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def draw_text(draw, xy, text, font=FONT_14, fill=INK, anchor=None):
    draw.text(xy, text, font=font, fill=fill, anchor=anchor)


def draw_base(image, row, frame_id, total_frames):
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, WIDTH, HEIGHT), fill=BG)

    # Header
    draw_text(draw, (56, 28), "大学路酷热 · GAMA 行人情景回放", FONT_32)
    draw_text(draw, (58, 76), "B 点试点：NW 步行侧的树荫缺口补充遮阴", FONT_16, MUTED)
    rounded(draw, (954, 31, 1224, 76), 20, "#E7EDE6")
    draw_text(draw, (1089, 53), "2020-08-13  ·  区域气象回放", FONT_14, GREEN_DARK, "mm")

    # Weather cards
    cards = [
        ("气温 Ta", "%.1f °C" % float(row["air_temperature_C"]), "#F7E6D2"),
        ("相对湿度", "%.0f %%" % float(row["RH_pct"]), "#E2ECEA"),
        ("全球水平辐射 GHI", "%.0f W/m²" % float(row["GHI_W_m2"]), "#F7E8BA"),
        ("10 m 风速", "%.2f m/s" % float(row["wind10_m_s"]), "#E1E8F0"),
    ]
    x = 56
    for label, value, color in cards:
        rounded(draw, (x, 111, x + 270, 177), 14, WHITE)
        rounded(draw, (x + 12, 124, x + 50, 164), 12, color)
        draw_text(draw, (x + 62, 122), label, FONT_12, MUTED)
        draw_text(draw, (x + 62, 143), value, FONT_20)
        x += 286

    # Map panel and corridor.
    rounded(draw, (42, 198, 1238, 511), 20, WHITE)
    draw_text(draw, (64, 212), "平面路段 · 链程 0–262.8 m", FONT_14, MUTED)
    state_cn = {"CLOSED": "高遮阳", "ANGLED": "叶片倾斜", "OPEN": "通风展开"}.get(row["panel_state"], row["panel_state"])
    rounded(draw, (1025, 207, 1209, 244), 17, "#F5E8C2")
    draw_text(draw, (1117, 226), "叶片假设状态：" + state_cn, FONT_12, INK, "mm")

    # Sidewalk and road bands in local GAMA coordinates.
    px_left, px_right = map_x(0), map_x(ROAD_LENGTH)
    y_nw = map_y(19.0 + LANE_OFFSET)
    y_se = map_y(19.0 - LANE_OFFSET)
    road_top, road_bottom = map_y(24.0), map_y(14.0)
    draw.rounded_rectangle((px_left, road_top, px_right, road_bottom), radius=10, fill=ROAD)
    draw.rounded_rectangle((px_left, y_nw - 12, px_right, y_nw + 12), radius=6, fill=WALK)
    draw.rounded_rectangle((px_left, y_se - 12, px_right, y_se + 12), radius=6, fill=WALK)
    draw.line((px_left + 8, MAP_CENTER_Y, px_right - 8, MAP_CENTER_Y), fill="#F4F4F1", width=3)
    draw_text(draw, (px_left, y_nw - 30), "NW 北西侧", FONT_12, GREEN_DARK)
    draw_text(draw, (px_left, y_se + 20), "SE 东南侧", FONT_12, MUTED)

    # OSM-tree-derived broad shade bands used by the model (not canopy outlines).
    nw_bands = [(24.3, 119.6), (149.7, 249.1)]
    se_bands = [(24.4, 31.4), (39.8, 109.3), (150.5, 247.3)]
    for a, b in nw_bands:
        draw.rounded_rectangle((map_x(a), y_nw - 8, map_x(b), y_nw + 8), radius=7, fill=GREEN)
    for a, b in se_bands:
        draw.rounded_rectangle((map_x(a), y_se - 8, map_x(b), y_se + 8), radius=7, fill=GREEN)

    # Candidate marks A/B/C and selected B.
    candidates = [(65.0, "A"), (135.0, "B"), (200.0, "C")]
    for chainage, label in candidates:
        sx = map_x(chainage)
        color = ORANGE if label == "B" else "#8C9892"
        draw.line((sx, 266, sx, 469), fill=color, width=2 if label == "B" else 1)
        draw.ellipse((sx - 12, 253, sx + 12, 277), fill=color, outline=WHITE, width=2)
        draw_text(draw, (sx, 265), label, FONT_12, WHITE, "mm")

    # Dynamic shadow proxy from the solar geometry; bench/canopy footprint is assumed.
    sim_time = float(row["sim_time_s"])
    hour_i = min(6, int(sim_time // 3600.0))
    sun = weather_rows[hour_i]
    shadow_s = float(sun["body_plane_shadow_along_axis_m"])
    shadow_nw = float(sun["body_plane_shadow_nw_m"])
    shade_center_x = map_x(SITE_B + shadow_s)
    shade_center_y = map_y(19.0 + LANE_OFFSET + shadow_nw)
    shade_w = DEVICE_LENGTH * SCALE_X
    shade_h = DEVICE_SPAN * SCALE_Y
    shade_layer = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    shade_draw = ImageDraw.Draw(shade_layer)
    shade_draw.rounded_rectangle(
        (shade_center_x - shade_w / 2, shade_center_y - shade_h / 2,
         shade_center_x + shade_w / 2, shade_center_y + shade_h / 2),
        radius=7, fill=(232, 194, 93, 110), outline=(166, 125, 52, 220), width=2
    )
    image.alpha_composite(shade_layer)
    draw = ImageDraw.Draw(image)
    bench_x = map_x(SITE_B)
    draw.line((bench_x - 16, y_nw + 8, bench_x + 16, y_nw + 8), fill="#986443", width=5)
    draw.line((bench_x - 15, y_nw + 13, bench_x + 15, y_nw + 13), fill="#986443", width=3)
    draw_text(draw, (bench_x + 24, y_nw - 18), "B · 座椅 + 模块化遮阳", FONT_12, INK)

    # Agents from the exported GAMA trace.
    active_rows = frames[frame_id]
    for agent in active_rows:
        chainage = float(agent["chainage_m"])
        side = float(agent["route_side"])
        state = agent["state"]
        lateral = 19.0 + (1.0 if state == "resting" else side) * LANE_OFFSET
        cx, cy = map_x(chainage), map_y(lateral)
        if agent["activity_class"] == "short_pause":
            color = ORANGE if state == "resting" else "#AE6A53"
        else:
            color = TEAL if side > 0 else BLUE
        radius = 5 if state == "walking" else 7
        draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=color, outline=WHITE, width=1)
        if agent["under_device"].lower() == "true":
            draw.ellipse((cx - 9, cy - 9, cx + 9, cy + 9), outline="#B18331", width=1)

    # Endpoints, legends, and directional cue.
    draw_text(draw, (px_left, 475), "智星路 · NE 起点  0 m", FONT_12, MUTED)
    draw_text(draw, (px_right, 475), "SW 终点 · 锦创路  262.8 m", FONT_12, MUTED, "ra")
    draw.line((px_left + 120, 485, px_right - 118, 485), fill="#AAB3AE", width=1)
    draw.polygon([(px_right - 118, 485), (px_right - 128, 480), (px_right - 128, 490)], fill="#AAB3AE")
    draw.ellipse((78, 492, 88, 502), fill=TEAL)
    draw_text(draw, (96, 489), "通行行人", FONT_12, MUTED)
    draw.ellipse((189, 492, 199, 502), fill=ORANGE)
    draw_text(draw, (207, 489), "短暂停留", FONT_12, MUTED)
    draw.rounded_rectangle((300, 493, 320, 501), radius=4, fill=GREEN)
    draw_text(draw, (328, 489), "树荫代理带", FONT_12, MUTED)
    draw.rounded_rectangle((437, 493, 457, 501), radius=4, fill=GOLD)
    draw_text(draw, (465, 489), "装置投影代理", FONT_12, MUTED)

    # GHI timeline and current playback marker.
    rounded(draw, (42, 528, 1238, 651), 18, WHITE)
    draw_text(draw, (64, 542), "太阳辐射时序", FONT_16)
    draw_text(draw, (210, 545), "区域 ERA5 · 小时值按模型回放", FONT_12, MUTED)
    chart_left, chart_right = 260, 1158
    chart_top, chart_bottom = 570, 625
    ghi_values = [float(r["GHI_W_m2"]) for r in weather_rows]
    max_ghi = max(ghi_values) or 1.0
    points = []
    for i, value in enumerate(ghi_values):
        xx = chart_left + i * (chart_right - chart_left) / 6.0
        yy = chart_bottom - (value / max_ghi) * (chart_bottom - chart_top)
        points.append((xx, yy))
    draw.line(points, fill=ORANGE, width=3, joint="curve")
    for (xx, yy), value, wr in zip(points, ghi_values, weather_rows):
        draw.ellipse((xx - 4, yy - 4, xx + 4, yy + 4), fill=ORANGE)
        draw_text(draw, (xx, yy - 11), str(int(value)), FONT_12, MUTED, "ms")
        draw_text(draw, (xx, chart_bottom + 14), wr["hour_label"] + ":00", FONT_12, MUTED, "mm")
    progress = min(1.0, max(0.0, sim_time / 21600.0))
    marker_x = chart_left + progress * (chart_right - chart_left)
    draw.ellipse((marker_x - 7, chart_bottom - 5, marker_x + 7, chart_bottom + 9), fill=INK, outline=WHITE, width=2)
    current_clock = 10.0 + sim_time / 3600.0
    hh = int(current_clock)
    mm = int((current_clock - hh) * 60)
    draw_text(draw, (1198, 545), "%02d:%02d" % (hh, mm), FONT_20, INK, "ra")

    # Evidence limits footer.
    draw_text(draw, (56, 674), "说明：行人轨迹来自 GAMA 导出回放；树冠、客流与装置光学参数为简化假设。区域 ERA5 ≠ 大学路现场微气候，坐标仅作试点锚点。", FONT_12, MUTED)
    draw_text(draw, (1220, 674), "%d / %d" % (frame_id, total_frames), FONT_12, MUTED, "ra")
    return image


poster_frame = max(frame_ids, key=lambda f: len(frames[f]))
poster = Image.new("RGBA", (WIDTH, HEIGHT), BG)
poster = draw_base(poster, frames[poster_frame][0], poster_frame, len(frame_ids))
poster.convert("RGB").save(POSTER, quality=92)

ffmpeg_params = ["-pix_fmt", "yuv420p", "-movflags", "+faststart"]
with imageio.get_writer(
    str(OUTPUT),
    format="FFMPEG",
    mode="I",
    fps=FRAMES_PER_SECOND,
    codec="libx264",
    quality=8,
    macro_block_size=1,
    ffmpeg_params=ffmpeg_params,
) as writer:
    for frame_id in frame_ids:
        image = Image.new("RGBA", (WIDTH, HEIGHT), BG)
        image = draw_base(image, frames[frame_id][0], frame_id, len(frame_ids))
        writer.append_data(np.asarray(image.convert("RGB")))

print("frames=%d fps=%d duration_s=%.2f" % (len(frame_ids), FRAMES_PER_SECOND, len(frame_ids) / float(FRAMES_PER_SECOND)))
print("mp4=%s" % OUTPUT)
print("poster=%s" % POSTER)
