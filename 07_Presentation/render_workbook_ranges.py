from pathlib import Path
import argparse

from openpyxl import load_workbook
from openpyxl.utils import get_column_letter
from PIL import Image, ImageDraw, ImageFont


BOOK_DEFAULT = Path(r"G:\数据驱动和基于实证的设计\outputs\2026-11-08-full-day-parameter-revision\同济大学全天Agent模拟参数归类_修订版.xlsx")
BOOK = BOOK_DEFAULT
OUT = Path(__file__).resolve().parent
FONT = r"C:\Windows\Fonts\msyh.ttc"
GRID = (211, 220, 217)
HEADER = (239, 244, 242)
INK = (34, 55, 54)
MUTED = (105, 123, 122)


def excel_color(color, fallback):
    if color and color.type == "rgb" and color.rgb and len(color.rgb) >= 6:
        raw = color.rgb[-6:]
        try:
            return tuple(int(raw[i:i + 2], 16) for i in (0, 2, 4))
        except ValueError:
            pass
    return fallback


def value_text(value, number_format, sheet_name, row, col):
    if value is None:
        return ""
    if sheet_name == "全天与课表" and 25 <= row <= 29 and 2 <= col <= 7 and isinstance(value, (int, float)):
        return f"{value:.0%}"
    if isinstance(value, float) and "%" in number_format:
        decimals = 1 if ".0" in number_format else 0
        return f"{value:.{decimals}%}"
    return str(value)


def wrap(text, font, max_width, draw):
    lines, current = [], ""
    for char in text:
        candidate = current + char
        if current and draw.textlength(candidate, font=font) > max_width:
            lines.append(current)
            current = char
        else:
            current = candidate
    if current:
        lines.append(current)
    return lines or [""]


def render(sheet_name, min_row, max_row, min_col, max_col, widths, heights, title, out_name):
    wb = load_workbook(BOOK, data_only=True, read_only=False)
    ws = wb[sheet_name]
    scale = 2
    font = ImageFont.truetype(FONT, 17 * scale)
    font_bold = ImageFont.truetype(FONT, 17 * scale)
    font_meta = ImageFont.truetype(FONT, 13 * scale)
    row_header_w = 48 * scale
    letters_h, title_h = 32 * scale, 52 * scale
    widths = [w * scale for w in widths]
    heights = [h * scale for h in heights]
    width = row_header_w + sum(widths)
    height = title_h + letters_h + sum(heights)
    image = Image.new("RGB", (width, height), "white")
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, width, title_h), fill=(248, 250, 249))
    draw.text((20 * scale, 9 * scale), title, font=font_bold, fill=INK)
    draw.text((20 * scale, 32 * scale), f"工作簿区域 · {sheet_name}!{ws.cell(min_row, min_col).coordinate}:{ws.cell(max_row, max_col).coordinate}", font=font_meta, fill=MUTED)

    y0 = title_h
    draw.rectangle((0, y0, width, y0 + letters_h), fill=HEADER)
    x = row_header_w
    for ci, col_width in enumerate(widths, min_col):
        letter = get_column_letter(ci)
        draw.text((x + 8 * scale, y0 + 5 * scale), letter, font=font_meta, fill=MUTED)
        x += col_width
    draw.rectangle((0, y0, row_header_w, y0 + letters_h), fill=HEADER, outline=GRID, width=scale)

    y = y0 + letters_h
    for ri, row_height in zip(range(min_row, max_row + 1), heights):
        draw.rectangle((0, y, row_header_w, y + row_height), fill=HEADER, outline=GRID, width=scale)
        draw.text((8 * scale, y + 6 * scale), str(ri), font=font_meta, fill=MUTED)
        x = row_header_w
        for ci, col_width in zip(range(min_col, max_col + 1), widths):
            cell = ws.cell(ri, ci)
            fill = excel_color(cell.fill.fgColor, (255, 255, 255)) if cell.fill.fill_type else (255, 255, 255)
            draw.rectangle((x, y, x + col_width, y + row_height), fill=fill, outline=GRID, width=scale)
            text = value_text(cell.value, cell.number_format, sheet_name, ri, ci)
            cell_font = font_bold if cell.font.bold else font
            color = excel_color(cell.font.color, INK) if cell.font.color else INK
            lines = wrap(text, cell_font, col_width - 18 * scale, draw)
            line_h = 23 * scale
            total_h = len(lines) * line_h
            ty = y + max(7 * scale, (row_height - total_h) // 2)
            for line in lines:
                draw.text((x + 9 * scale, ty), line, font=cell_font, fill=color)
                ty += line_h
            x += col_width
        y += row_height

    image.save(OUT / out_name)
    wb.close()


def main():
    global BOOK, OUT
    parser = argparse.ArgumentParser(description="Render selected source workbook ranges as image evidence.")
    parser.add_argument("--workbook", type=Path, default=BOOK_DEFAULT)
    parser.add_argument("--output-dir", type=Path, default=Path(__file__).resolve().parent)
    args = parser.parse_args()
    BOOK, OUT = args.workbook, args.output_dir
    OUT.mkdir(parents=True, exist_ok=True)
    render("全天与课表", 24, 29, 1, 8, [155, 95, 125, 150, 160, 115, 75, 150], [38, 62, 62, 62, 62, 62], "午间行为比例", "Excel_午间活动比例.png")
    render("行为推导留痕", 18, 20, 1, 3, [65, 165, 780], [76, 82, 72], "活动、路线与随机参数", "Excel_行为参数.png")
    print("rendered Excel_午间活动比例.png and Excel_行为参数.png")


if __name__ == "__main__":
    main()

