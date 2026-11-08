from pathlib import Path
import argparse

import imageio.v2 as imageio
from PIL import Image


VIDEO_DEFAULT = Path(r"G:\数据驱动和基于实证的设计\outputs\2026-11-08-presentation-media\Tongji_全校域全天路网热度.mp4")
WIDTH = 960
FPS = 10  # source MP4 is 5 fps, so this plays at 2x speed


def main():
    parser = argparse.ArgumentParser(description="Create a 2x GIF from the full-day road heat MP4.")
    parser.add_argument("--video", type=Path, default=VIDEO_DEFAULT)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    video = args.video
    gif = args.output or video.with_name("Tongji_全校域全天路网热度_2x.gif")
    reader = imageio.get_reader(str(video))
    frames = []
    for array in reader:
        image = Image.fromarray(array).convert("RGB")
        image = image.resize((WIDTH, round(image.height * WIDTH / image.width)), Image.Resampling.LANCZOS)
        frames.append(image.quantize(colors=160, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE))
    reader.close()
    frames[0].save(gif, save_all=True, append_images=frames[1:], duration=1000 // FPS, loop=0, optimize=True, disposal=2)
    print(f"gif={gif}")
    print(f"frames={len(frames)} duration_seconds={len(frames)/FPS:.1f} speed=2x size_bytes={gif.stat().st_size}")


if __name__ == "__main__":
    main()

