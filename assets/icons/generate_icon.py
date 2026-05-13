"""
화장실 찾기 앱 아이콘 생성기 v2
남성(파란색) + 여성(분홍색) 픽토그램 나란히
"""
from PIL import Image, ImageDraw
import os

SIZE = 1024
OUT_DIR = os.path.dirname(__file__)

BG_DARK   = (25,  118, 210)   # #1976D2
BG_LIGHT  = (66,  165, 245)   # #42A5F5
WHITE     = (255, 255, 255)
MALE_C    = (255, 255, 255)    # 흰색 남성
FEMALE_C  = (255, 220, 240)    # 연분홍 여성


# ── 그라디언트 배경 ──────────────────────────────────────────────────
def make_gradient(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size))
    for y in range(size):
        t = y / size
        r = int(BG_DARK[0] + t * (BG_LIGHT[0] - BG_DARK[0]))
        g = int(BG_DARK[1] + t * (BG_LIGHT[1] - BG_DARK[1]))
        b = int(BG_DARK[2] + t * (BG_LIGHT[2] - BG_DARK[2]))
        for x in range(size):
            img.putpixel((x, y), (r, g, b, 255))
    return img


def round_corners(img: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([0, 0, img.width-1, img.height-1],
                            radius=radius, fill=255)
    result = img.copy()
    result.putalpha(mask)
    return result


# ── 남성 픽토그램 ────────────────────────────────────────────────────
def draw_male(draw: ImageDraw.ImageDraw, cx: int, cy: int,
              unit: int, color: tuple):
    """
    unit = 기본 단위 (머리 반지름 기준)
    cx, cy = 픽토그램 전체 중심
    """
    head_r  = unit
    head_cy = cy - int(unit * 3.2)

    # 머리
    draw.ellipse([cx - head_r, head_cy - head_r,
                  cx + head_r, head_cy + head_r], fill=color)

    # 몸통 (직사각형)
    body_w  = int(unit * 1.35)
    body_h  = int(unit * 2.4)
    body_y0 = head_cy + head_r + int(unit * 0.35)
    body_y1 = body_y0 + body_h
    draw.rounded_rectangle(
        [cx - body_w, body_y0, cx + body_w, body_y1],
        radius=int(unit * 0.35), fill=color)

    # 다리 (두 직사각형)
    leg_w   = int(unit * 0.55)
    leg_h   = int(unit * 2.2)
    gap     = int(unit * 0.20)
    leg_y0  = body_y1 + int(unit * 0.12)
    leg_y1  = leg_y0 + leg_h
    # 왼쪽 다리
    draw.rounded_rectangle(
        [cx - leg_w*2 - gap//2, leg_y0,
         cx - gap//2,           leg_y1],
        radius=int(unit * 0.28), fill=color)
    # 오른쪽 다리
    draw.rounded_rectangle(
        [cx + gap//2,           leg_y0,
         cx + leg_w*2 + gap//2, leg_y1],
        radius=int(unit * 0.28), fill=color)


# ── 여성 픽토그램 ────────────────────────────────────────────────────
def draw_female(draw: ImageDraw.ImageDraw, cx: int, cy: int,
                unit: int, color: tuple):
    head_r  = unit
    head_cy = cy - int(unit * 3.2)

    # 머리
    draw.ellipse([cx - head_r, head_cy - head_r,
                  cx + head_r, head_cy + head_r], fill=color)

    # 상체 (좁은 직사각형)
    top_w  = int(unit * 0.90)
    top_h  = int(unit * 1.30)
    top_y0 = head_cy + head_r + int(unit * 0.35)
    top_y1 = top_y0 + top_h
    draw.rounded_rectangle(
        [cx - top_w, top_y0, cx + top_w, top_y1],
        radius=int(unit * 0.28), fill=color)

    # 치마 (아래로 넓어지는 사다리꼴)
    skirt_top_w  = int(unit * 1.05)
    skirt_bot_w  = int(unit * 2.40)
    skirt_h      = int(unit * 2.60)
    skirt_y0     = top_y1
    skirt_y1     = skirt_y0 + skirt_h

    skirt_pts = [
        (cx - skirt_top_w, skirt_y0),
        (cx + skirt_top_w, skirt_y0),
        (cx + skirt_bot_w, skirt_y1),
        (cx - skirt_bot_w, skirt_y1),
    ]
    draw.polygon(skirt_pts, fill=color)


# ── 구분선 ───────────────────────────────────────────────────────────
def draw_divider(draw: ImageDraw.ImageDraw, cx: int,
                 y_top: int, y_bot: int, width: int, color: tuple):
    half = width // 2
    draw.rounded_rectangle(
        [cx - half, y_top, cx + half, y_bot],
        radius=half, fill=color)


# ── 메인 ─────────────────────────────────────────────────────────────
def make_app_icon(rounded: bool = True) -> Image.Image:
    bg   = make_gradient(SIZE)
    draw = ImageDraw.Draw(bg)

    unit = int(SIZE * 0.080)      # 기본 단위

    # 두 픽토그램 중심 X
    male_cx   = SIZE // 2 - int(SIZE * 0.215)
    female_cx = SIZE // 2 + int(SIZE * 0.215)
    cy = SIZE // 2 + int(SIZE * 0.06)   # 약간 아래

    draw_male(draw,   male_cx,   cy, unit, MALE_C)
    draw_female(draw, female_cx, cy, unit, FEMALE_C)

    # 중앙 구분선
    div_top = int(SIZE * 0.18)
    div_bot = int(SIZE * 0.85)
    div_w   = int(SIZE * 0.018)
    draw_divider(draw, SIZE // 2, div_top, div_bot, div_w,
                 (255, 255, 255, 120))

    if rounded:
        bg = round_corners(bg, radius=int(SIZE * 0.225))
    return bg


def make_fg_icon() -> Image.Image:
    """Adaptive icon foreground (Android) — 투명 배경"""
    img  = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    unit      = int(SIZE * 0.080)
    male_cx   = SIZE // 2 - int(SIZE * 0.215)
    female_cx = SIZE // 2 + int(SIZE * 0.215)
    cy        = SIZE // 2 + int(SIZE * 0.06)

    draw_male(draw,   male_cx,   cy, unit, WHITE)
    draw_female(draw, female_cx, cy, unit, (255, 220, 240))

    draw_divider(draw, SIZE // 2,
                 int(SIZE * 0.18), int(SIZE * 0.85),
                 int(SIZE * 0.018), (255, 255, 255, 120))
    return img


if __name__ == "__main__":
    print("아이콘 생성 중...")

    icon = make_app_icon(rounded=True)
    path = os.path.join(OUT_DIR, "app_icon.png")
    icon.save(path, "PNG")
    print(f"  app_icon.png     → {path}")

    fg = make_fg_icon()
    fg_path = os.path.join(OUT_DIR, "app_icon_fg.png")
    fg.save(fg_path, "PNG")
    print(f"  app_icon_fg.png  → {fg_path}")

    print("완료!")
