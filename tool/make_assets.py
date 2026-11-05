"""Generates the app icon and Play Store graphics. Run: python3 tool/make_assets.py"""
from PIL import Image, ImageDraw, ImageFont
import os

OUT_ICON = "assets/icon"
OUT_STORE = "store"
os.makedirs(OUT_ICON, exist_ok=True)
os.makedirs(OUT_STORE, exist_ok=True)

C1, C2 = (108, 92, 231), (62, 52, 190)   # violet gradient
CORAL = (255, 77, 109)
MINT = (18, 184, 134)

def gradient(size, a, b):
    w, h = size
    img = Image.new("RGB", size)
    px = img.load()
    for y in range(h):
        for x in range(w):
            t = (x + y) / (w + h)
            px[x, y] = tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))
    return img

def calendar_glyph(size, scale=1.0, bg=None):
    """White calendar card with a coral 'spent' day and mint 'income' day, on transparent."""
    S = size
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    w = int(S * 0.56 * scale)
    h = int(S * 0.56 * scale)
    x0 = (S - w) // 2
    y0 = (S - h) // 2 + int(S * 0.02)
    r = int(w * 0.16)
    d.rounded_rectangle([x0, y0, x0 + w, y0 + h], r, fill=(255, 255, 255, 255))
    bar = int(h * 0.26)
    d.rounded_rectangle([x0, y0, x0 + w, y0 + bar + r], r, fill=(255, 255, 255, 255))
    d.rectangle([x0, y0 + bar, x0 + w, y0 + bar + r], fill=(255, 255, 255, 255))
    d.rounded_rectangle([x0, y0, x0 + w, y0 + bar], r, fill=(236, 233, 252, 255))
    d.rectangle([x0, y0 + r, x0 + w, y0 + bar], fill=(236, 233, 252, 255))
    # binder rings
    rw = int(w * 0.07); rh = int(h * 0.15)
    for fx in (0.28, 0.72):
        cx = x0 + int(w * fx)
        d.rounded_rectangle([cx - rw, y0 - rh // 2, cx + rw, y0 + rh // 2], rw, fill=(62, 52, 190, 255))
    # 4 x 3 dot grid
    gx0 = x0 + int(w * 0.14); gx1 = x0 + int(w * 0.86)
    gy0 = y0 + bar + int(h * 0.12); gy1 = y0 + h - int(h * 0.12)
    cols, rows = 4, 3
    dr = int(w * 0.055)
    for j in range(rows):
        for i in range(cols):
            cx = gx0 + (gx1 - gx0) * i // (cols - 1)
            cy = gy0 + (gy1 - gy0) * j // (rows - 1)
            col = (214, 210, 240, 255)
            if (i, j) == (1, 1):
                col = CORAL + (255,)
            if (i, j) == (3, 2):
                col = MINT + (255,)
            if (i, j) == (1, 1):
                d.ellipse([cx - dr * 1.7, cy - dr * 1.7, cx + dr * 1.7, cy + dr * 1.7], fill=col)
            else:
                d.ellipse([cx - dr, cy - dr, cx + dr, cy + dr], fill=col)
    return img

# Full-bleed icon (1024) and adaptive foreground (glyph inside the 66% safe zone).
bg = gradient((1024, 1024), C1, C2).convert("RGBA")
bg.alpha_composite(calendar_glyph(1024, 1.0))
bg.convert("RGB").save(f"{OUT_ICON}/icon.png")
calendar_glyph(1024, 0.80).save(f"{OUT_ICON}/icon_foreground.png")

# Play Store hi-res icon: 512x512 PNG
bg.convert("RGB").resize((512, 512), Image.LANCZOS).save(f"{OUT_STORE}/icon_512.png")

# Feature graphic 1024x500
fg = gradient((1024, 500), C1, C2).convert("RGBA")
glyph = calendar_glyph(520, 1.0)
fg.alpha_composite(glyph, (500, -10))
d = ImageDraw.Draw(fg)
def font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except Exception:
        return ImageFont.load_default()
bold = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
reg = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
d.text((64, 150), "DayWise", font=font(bold, 84), fill=(255, 255, 255))
d.text((68, 262), "Your money, day by day.", font=font(reg, 34), fill=(235, 232, 255))
d.text((68, 312), "Offline expense calendar", font=font(reg, 26), fill=(205, 200, 245))
fg.convert("RGB").save(f"{OUT_STORE}/feature_graphic_1024x500.png")
print("ok")
