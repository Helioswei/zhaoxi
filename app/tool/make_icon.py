#!/usr/bin/env python3
"""生成「朝夕」应用图标。

用法：
    python3 tool/make_icon.py

产物（assets/icon/）：
    icon.png             1024×1024，圆角方块 + 「朝」（macOS / 旧版 Android）
    icon_foreground.png  1024×1024，透明底 + 「朝」（Android 自适应图标前景）

依赖：Pillow（pip install pillow）
"""

import os

from PIL import Image, ImageDraw, ImageFont

SIZE = 1024
BG = (59, 122, 110)  # #3B7A6E（03 §6.1 主色）
FG = (255, 255, 255, 255)
FONT = os.path.join(os.path.dirname(__file__), "..", "assets", "fonts", "ZhaoxiSerif-Regular.ttf")
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "icon")


def draw_glyph(img: Image.Image, ratio: float) -> None:
    draw = ImageDraw.Draw(img)
    font = ImageFont.truetype(FONT, int(SIZE * ratio))
    text = "朝"
    left, top, right, bottom = draw.textbbox((0, 0), text, font=font)
    draw.text(
        ((SIZE - (right - left)) / 2 - left, (SIZE - (bottom - top)) / 2 - top),
        text,
        font=font,
        fill=FG,
    )


def main() -> int:
    os.makedirs(OUT, exist_ok=True)

    # 圆角方块 + 字（给 macOS / 旧版 Android 用）
    icon = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(icon).rounded_rectangle(
        [0, 0, SIZE - 1, SIZE - 1], radius=int(SIZE * 0.22), fill=BG
    )
    draw_glyph(icon, 0.60)
    icon.save(os.path.join(OUT, "icon.png"))

    # 自适应图标前景：字更小，留在安全区内
    foreground = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw_glyph(foreground, 0.44)
    foreground.save(os.path.join(OUT, "icon_foreground.png"))

    print("已生成 assets/icon/icon.png 与 icon_foreground.png")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
