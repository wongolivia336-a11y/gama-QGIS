import csv
import argparse
import json
import math
from pathlib import Path

import imageio.v2 as imageio
import numpy as np
from PIL import Image, ImageDraw, ImageFont


ROOT_DEFAULT = Path(r"G:\数据驱动和基于实证的设计\output\TongjiDailyScope_全天模拟_20261108_review\TongjiDailyScope_全天模拟_20261108")
ROOT = ROOT_DEFAULT
GIS = ROOT / "includes" / "gis"
RESULTS = ROOT / "results" / "baseline"
OUT = Path(__file__).resolve().parent
VIDEO = OUT / "Tongji_全校域全天路网热度.mp4"
POSTER = OUT / "Tongji_全校域路网热度_11-35.png"

W, H = 1280, 720
BG = (248, 250, 249)
INK = (28, 83, 82)
MUTED = (100, 122, 122)
BUILDING = (230, 237, 234)
BUILDING_LINE = (212, 222, 219)
FOCUS = (219, 232, 226)
PARK = (225, 239, 222)
ROAD = (198, 211, 208)
FONT_PATH = Path(r"C:\Windows\Fonts\msyh.ttc")


def load_geo(name):
    return json.loads((GIS / name).read_text(encoding="utf-8-sig"))


def flatten_points(coords):
    if isinstance(coords, list) and coords and isinstance(coords[0], (int, float)):
        yield coords
    elif isinstance(coords, list):
        for item in coords:
            yield from flatten_points(item)


def read_rows(path):
    with path.open(encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def load_data():
    roads_geo = load_geo("roads.geojson")["features"]
    buildings = load_geo("research_buildings.geojson")["features"]
    backgrounds = load_geo("other_buildings.geojson")["features"]
    parks = load_geo("green_spaces.geojson")["features"]
    all_features = roads_geo + buildings + backgrounds + parks
    coords = [p for ft in all_features for p in flatten_points(ft["geometry"]["coordinates"])]
    bounds = (min(p[0] for p in coords), min(p[1] for p in coords), max(p[0] for p in coords), max(p[1] for p in coords))
    road_rows = read_rows(RESULTS / "road_instant.csv")
    state_rows = read_rows(RESULTS / "states.csv")
    road_frames = {}
    for row in road_rows:
        road_frames.setdefault(row["clock"], {})[str(row["road_id"])] = float(row["people_per_m"] or 0)
    walking = {row["clock"]: int(float(row["walking"] or 0)) for row in state_rows}
    times = sorted(road_frames, key=lambda s: int(s[:2]) * 60 + int(s[3:]))
    return roads_geo, buildings, backgrounds, parks, bounds, road_frames, walking, times


def make_transform(bounds, rect):
    x0, y0, x1, y1 = bounds
    left, top, width, height = rect
    scale = min(width / (x1 - x0), height / (y1 - y0))
    drawn_w, drawn_h = (x1 - x0) * scale, (y1 - y0) * scale
    ox, oy = left + (width - drawn_w) / 2, top + (height - drawn_h) / 2

    def xy(point):
        return (round(ox + (point[0] - x0) * scale), round(oy + (y1 - point[1]) * scale))

    return xy


def draw_polygon_geometry(draw, geometry, xy, fill, outline=None, width=1):
    kind, coords = geometry["type"], geometry["coordinates"]
    polygons = [coords] if kind == "Polygon" else coords if kind == "MultiPolygon" else []
    for polygon in polygons:
        for ring in polygon:
            pts = [xy(p) for p in ring]
            if len(pts) >= 3:
                draw.polygon(pts, fill=fill, outline=outline)
                if outline and width > 1:
                    draw.line(pts + [pts[0]], fill=outline, width=width, joint="curve")


def color_for(value, vmax):
    if value <= 0.01:
        return ROAD, 2
    t = max(0.0, min(1.0, math.sqrt(value / vmax)))
    stops = [(0.0, (35, 137, 131)), (0.55, (242, 174, 59)), (1.0, (224, 76, 58))]
    for (a, ca), (b, cb) in zip(stops, stops[1:]):
        if t <= b:
            u = (t - a) / (b - a)
            rgb = tuple(round(ca[i] + (cb[i] - ca[i]) * u) for i in range(3))
            return rgb, 3 + round(t * 6)
    return stops[-1][1], 9


def render_frame(time, roads, research, background, parks, xy, flow, walking_count, walking_series, progress, vmax, font_regular, font_bold, peak):
    image = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(image)
    d.text((42, 25), "TONGJI / FIELD ATLAS", font=font_regular, fill=MUTED)
    d.text((42, 57), "四平路校区全天路网人流热度", font=font_bold, fill=INK)
    d.text((1025, 33), time, font=font_bold, fill=INK)
    d.text((1028, 73), "全校域  ·  全天 07:30—17:30", font=font_regular, fill=MUTED)

    for ft in parks:
        draw_polygon_geometry(d, ft["geometry"], xy, PARK)
    for ft in background:
        draw_polygon_geometry(d, ft["geometry"], xy, BUILDING, BUILDING_LINE)
    for ft in research:
        draw_polygon_geometry(d, ft["geometry"], xy, FOCUS, (183, 207, 198))

    road_index = {str(ft["properties"]["id"]): ft for ft in roads}
    # Draw the full network first, then its time-specific people-per-metre heat.
    for ft in roads:
        pts = [xy(p) for p in ft["geometry"]["coordinates"]]
        if len(pts) > 1:
            d.line(pts, fill=ROAD, width=2, joint="curve")
    for road_id, value in flow.items():
        ft = road_index.get(road_id)
        if not ft:
            continue
        pts = [xy(p) for p in ft["geometry"]["coordinates"]]
        if len(pts) > 1:
            color, width = color_for(value, vmax)
            d.line(pts, fill=color, width=width, joint="curve")

    # Right-side live summary and day curve.
    d.rounded_rectangle((905, 126, 1238, 602), radius=18, fill=(237, 243, 241))
    d.text((932, 153), "当前移动人数", font=font_regular, fill=MUTED)
    d.text((932, 188), f"{walking_count:,}", font=font_bold, fill=INK)
    d.text((932, 238), "路网瞬时人数", font=font_regular, fill=MUTED)
    active = sum(1 for v in flow.values() if v > 0)
    d.text((932, 282), f"{active} / {len(roads)}", font=font_bold, fill=(39, 139, 132))
    d.text((932, 324), "当前有流量的道路段", font=font_regular, fill=MUTED)
    d.line((932, 372, 1210, 372), fill=(210, 222, 218), width=2)
    d.text((932, 392), "全天移动节律", font=font_bold, fill=INK)
    chart = (932, 442, 1210, 544)
    d.line((chart[0], chart[3], chart[2], chart[3]), fill=(199, 214, 210), width=2)
    vals = [max(0, v) for v in walking_series.values()]
    vmax_walk = max(vals) or 1
    curve = []
    for i, val in enumerate(vals):
        px = chart[0] + i * (chart[2] - chart[0]) / max(1, len(vals) - 1)
        py = chart[3] - val / vmax_walk * (chart[3] - chart[1])
        curve.append((round(px), round(py)))
    if len(curve) > 1:
        d.line(curve, fill=(33, 139, 126), width=3, joint="curve")
    marker_x = chart[0] + progress * (chart[2] - chart[0])
    d.line((marker_x, chart[1], marker_x, chart[3]), fill=(232, 150, 43), width=2)
    d.text((932, 559), "07:30", font=font_regular, fill=MUTED)
    d.text((1155, 559), "17:30", font=font_regular, fill=MUTED)

    # Flow legend and a compact playback timeline.
    d.text((54, 633), "路段瞬时人流密度（人/米）", font=font_regular, fill=MUTED)
    for i in range(80):
        color, _ = color_for((i + 1) / 80 * vmax, vmax)
        d.line((255 + i * 4, 647, 255 + i * 4, 647), fill=color, width=5)
    d.text((590, 633), "低", font=font_regular, fill=MUTED)
    d.text((642, 633), "高", font=font_regular, fill=MUTED)
    d.text((790, 633), f"全天峰值 {peak[1]:.1f} 人/米 · {peak[0]}", font=font_regular, fill=INK)
    d.rounded_rectangle((54, 678, 1225, 686), radius=4, fill=(222, 231, 228))
    d.rounded_rectangle((54, 678, 54 + round(1171 * progress), 686), radius=4, fill=(30, 114, 109))
    d.ellipse((49 + round(1171 * progress), 673, 63 + round(1171 * progress), 691), fill=(30, 114, 109))
    d.text((54, 694), "GAMA road_instant.csv  ·  五分钟快照", font=font_regular, fill=MUTED)
    return image


def main():
    global ROOT, GIS, RESULTS, OUT, VIDEO, POSTER
    parser = argparse.ArgumentParser(description="Render a full-day campus road-flow animation from GAMA outputs.")
    parser.add_argument("--project-root", type=Path, default=ROOT_DEFAULT, help="Extracted TongjiDailyScope project directory")
    parser.add_argument("--output-dir", type=Path, default=Path(__file__).resolve().parent, help="Directory for the MP4 and poster")
    args = parser.parse_args()
    ROOT = args.project_root
    GIS = ROOT / "includes" / "gis"
    RESULTS = ROOT / "results" / "baseline"
    OUT = args.output_dir
    VIDEO = OUT / "Tongji_全校域全天路网热度.mp4"
    POSTER = OUT / "Tongji_全校域路网热度_11-35.png"
    OUT.mkdir(parents=True, exist_ok=True)
    roads, research, background, parks, bounds, road_frames, walking, times = load_data()
    xy = make_transform(bounds, (48, 130, 820, 475))
    font_regular = ImageFont.truetype(str(FONT_PATH), 17)
    font_bold = ImageFont.truetype(str(FONT_PATH), 27)
    peak_time, peak_value = max(((t, max(v.values(), default=0)) for t, v in road_frames.items()), key=lambda x: x[1])
    vmax = max(peak_value, 1.0)
    frames = []
    n = len(times)
    for i, time in enumerate(times):
        minute = int(time[:2]) * 60 + int(time[3:])
        state_clock = min(walking, key=lambda s: abs((int(s[:2]) * 60 + int(s[3:])) - minute))
        frames.append(render_frame(time, roads, research, background, parks, xy, road_frames[time], walking[state_clock], walking, i / max(1, n - 1), vmax, font_regular, font_bold, (peak_time, peak_value)))

    frames[min(range(len(times)), key=lambda i: abs((int(times[i][:2]) * 60 + int(times[i][3:])) - (11 * 60 + 35)))].save(POSTER)
    with imageio.get_writer(VIDEO, fps=5, codec="libx264", quality=8, macro_block_size=16, output_params=["-pix_fmt", "yuv420p"]) as writer:
        for frame in frames:
            writer.append_data(np.asarray(frame))
    print(f"video={VIDEO}")
    print(f"poster={POSTER}")
    print(f"frames={len(frames)} duration_seconds={len(frames)/5:.1f} peak={peak_value:.3f}@{peak_time}")


if __name__ == "__main__":
    main()

