#!/usr/bin/env python3
"""
Travly - App Store Screenshot Generator
Generates 5 marketing screenshots for 6.7" and 6.5" iPhone displays.
"""

from PIL import Image, ImageDraw, ImageFont
import os
import math

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SIZES = {
    "6.7": (1290, 2796),
    "6.5": (1284, 2778),
}

OUTPUT_BASE = "/Users/kbux/code/travelplanner/screenshots"

# Colors
BLUE = (0, 122, 255)       # #007AFF
TEAL = (52, 199, 89)       # #34C759
WHITE = (255, 255, 255)
OFF_WHITE = (248, 248, 250)
LIGHT_GRAY = (230, 230, 235)
MID_GRAY = (199, 199, 204)
DARK_GRAY = (72, 72, 74)
DARKER_GRAY = (44, 44, 46)
BLACK = (0, 0, 0)

# Category colors
CAT_BLUE = (0, 122, 255)
CAT_RED = (255, 59, 48)
CAT_GREEN = (52, 199, 89)
CAT_ORANGE = (255, 149, 0)
CAT_PURPLE = (175, 82, 222)

# Trip card accent colors
TRIP_COLORS = [
    (0, 122, 255),    # Blue
    (255, 59, 48),    # Red
    (255, 149, 0),    # Orange
]

# ---------------------------------------------------------------------------
# Font loading
# ---------------------------------------------------------------------------

FONT_BOLD = "/System/Library/Fonts/SFNS.ttf"
FONT_REGULAR = "/System/Library/Fonts/SFNS.ttf"
FONT_ROUNDED = "/System/Library/Fonts/SFNSRounded.ttf"


def get_font(size, bold=False, rounded=False):
    """Load a font at the given size. Falls back to default if needed."""
    path = FONT_ROUNDED if rounded else (FONT_BOLD if bold else FONT_REGULAR)
    try:
        return ImageFont.truetype(path, size)
    except Exception:
        return ImageFont.load_default()


# ---------------------------------------------------------------------------
# Drawing helpers
# ---------------------------------------------------------------------------

def lerp_color(c1, c2, t):
    """Linearly interpolate between two RGB colors."""
    t = max(0.0, min(1.0, t))
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def draw_gradient_fast(img, c1, c2, direction="vertical"):
    """Fast gradient using line/block drawing."""
    draw = ImageDraw.Draw(img)
    w, h = img.size
    if direction == "vertical":
        for y in range(h):
            color = lerp_color(c1, c2, y / h)
            draw.line([(0, y), (w, y)], fill=color)
    elif direction == "horizontal":
        for x in range(w):
            color = lerp_color(c1, c2, x / w)
            draw.line([(x, 0), (x, h)], fill=color)
    elif direction in ("diagonal", "diagonal_reverse"):
        block = 4
        for y in range(0, h, block):
            for x in range(0, w, block):
                if direction == "diagonal":
                    t = (x / w * 0.4 + y / h * 0.6)
                else:
                    t = ((w - x) / w * 0.4 + y / h * 0.6)
                t = max(0, min(1, t))
                color = lerp_color(c1, c2, t)
                draw.rectangle([x, y, x + block, y + block], fill=color)


def rounded_rect(draw, bbox, radius, fill=None, outline=None, width=1):
    """Draw a rounded rectangle."""
    draw.rounded_rectangle(bbox, radius=radius, fill=fill, outline=outline, width=width)


def text_centered(draw, text, y, font, fill=WHITE, img_width=0):
    """Draw text centered horizontally at given y."""
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    x = (img_width - tw) // 2
    draw.text((x, y), text, font=font, fill=fill)


def text_width(draw, text, font):
    bbox = draw.textbbox((0, 0), text, font=font)
    return bbox[2] - bbox[0]


def text_height(draw, text, font):
    bbox = draw.textbbox((0, 0), text, font=font)
    return bbox[3] - bbox[1]


def draw_circle(draw, cx, cy, r, fill):
    """Draw a filled circle."""
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill)


def draw_icon_placeholder(draw, x, y, size, icon_type, color):
    """Draw simple iconic representations."""
    if icon_type == "airplane":
        cx, cy = x + size // 2, y + size // 2
        r = size // 2 - 4
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(235, 245, 255))
        # Wing shape
        pts = [
            (cx - r * 0.7, cy),
            (cx, cy - r * 0.5),
            (cx + r * 0.7, cy),
            (cx, cy + r * 0.2),
        ]
        draw.polygon(pts, fill=color)
        draw.rectangle([cx - r * 0.12, cy - r * 0.7, cx + r * 0.12, cy + r * 0.6], fill=color)
        pts_tail = [
            (cx - r * 0.35, cy + r * 0.4),
            (cx, cy + r * 0.15),
            (cx + r * 0.35, cy + r * 0.4),
        ]
        draw.polygon(pts_tail, fill=color)

    elif icon_type == "hotel":
        cx, cy = x + size // 2, y + size // 2
        r = size // 2 - 4
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 240, 235))
        bw = r * 0.8
        bh = r * 1.0
        bx = cx - bw / 2
        by = cy - bh / 2
        draw.rectangle([bx, by, bx + bw, by + bh], fill=color)
        wsize = bw * 0.2
        gap = bw * 0.1
        for row in range(2):
            for col in range(2):
                wx = bx + gap + col * (wsize + gap * 1.5)
                wy = by + gap + row * (wsize + gap)
                draw.rectangle([wx, wy, wx + wsize, wy + wsize], fill=WHITE)
        dw = bw * 0.25
        dx = cx - dw / 2
        dy = by + bh - bh * 0.35
        draw.rectangle([dx, dy, dx + dw, by + bh], fill=WHITE)

    elif icon_type == "car":
        cx, cy = x + size // 2, y + size // 2
        r = size // 2 - 4
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(235, 255, 240))
        bw = r * 1.2
        bh = r * 0.4
        bx = cx - bw / 2
        by = cy - bh / 2 + r * 0.1
        draw.rounded_rectangle([bx, by, bx + bw, by + bh], radius=bh * 0.3, fill=color)
        rw = bw * 0.5
        rh = bh * 0.7
        rx = cx - rw / 2
        ry = by - rh + 2
        draw.rounded_rectangle([rx, ry, rx + rw, ry + rh], radius=rh * 0.4, fill=color)
        wheel_r = bh * 0.3
        draw.ellipse([bx + bw * 0.15 - wheel_r, by + bh - wheel_r,
                       bx + bw * 0.15 + wheel_r, by + bh + wheel_r], fill=DARKER_GRAY)
        draw.ellipse([bx + bw * 0.85 - wheel_r, by + bh - wheel_r,
                       bx + bw * 0.85 + wheel_r, by + bh + wheel_r], fill=DARKER_GRAY)

    elif icon_type == "sun":
        cx, cy = x + size // 2, y + size // 2
        r = size // 3
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 204, 0))
        ray_len = r * 0.5
        for angle in range(0, 360, 45):
            rad = math.radians(angle)
            x1 = cx + math.cos(rad) * (r + 4)
            y1 = cy + math.sin(rad) * (r + 4)
            x2 = cx + math.cos(rad) * (r + ray_len)
            y2 = cy + math.sin(rad) * (r + ray_len)
            draw.line([(x1, y1), (x2, y2)], fill=(255, 204, 0), width=max(3, size // 20))

    elif icon_type == "cloud":
        cx, cy = x + size // 2, y + size // 2
        r = size // 4
        draw.ellipse([cx - r * 1.5, cy - r * 0.3, cx + r * 1.5, cy + r], fill=(200, 210, 220))
        draw.ellipse([cx - r * 0.8, cy - r * 1.0, cx + r * 0.5, cy + r * 0.1], fill=(200, 210, 220))
        draw.ellipse([cx - r * 0.2, cy - r * 1.2, cx + r * 1.2, cy - r * 0.0], fill=(200, 210, 220))

    elif icon_type == "cloud_sun":
        cx, cy = x + size // 2, y + size // 2
        sr = size // 4
        sx, sy = cx - sr * 0.5, cy - sr * 0.7
        draw.ellipse([sx - sr * 0.6, sy - sr * 0.6, sx + sr * 0.6, sy + sr * 0.6], fill=(255, 204, 0))
        for angle in range(0, 360, 45):
            rad = math.radians(angle)
            rl = sr * 0.4
            x1i = sx + math.cos(rad) * (sr * 0.6 + 2)
            y1i = sy + math.sin(rad) * (sr * 0.6 + 2)
            x2i = sx + math.cos(rad) * (sr * 0.6 + rl)
            y2i = sy + math.sin(rad) * (sr * 0.6 + rl)
            draw.line([(x1i, y1i), (x2i, y2i)], fill=(255, 204, 0), width=max(2, size // 25))
        r = size // 4
        draw.ellipse([cx - r * 1.3, cy - r * 0.1, cx + r * 1.3, cy + r * 1.0], fill=(210, 218, 226))
        draw.ellipse([cx - r * 0.7, cy - r * 0.7, cx + r * 0.4, cy + r * 0.2], fill=(210, 218, 226))
        draw.ellipse([cx - r * 0.1, cy - r * 0.9, cx + r * 1.1, cy + r * 0.1], fill=(210, 218, 226))

    elif icon_type == "walk":
        cx, cy = x + size // 2, y + size // 2
        r = size // 2 - 4
        hr = r * 0.2
        draw.ellipse([cx - hr, cy - r * 0.7 - hr, cx + hr, cy - r * 0.7 + hr], fill=color)
        draw.line([(cx, cy - r * 0.5), (cx, cy + r * 0.15)], fill=color, width=max(3, size // 18))
        draw.line([(cx, cy + r * 0.15), (cx - r * 0.3, cy + r * 0.65)], fill=color, width=max(3, size // 18))
        draw.line([(cx, cy + r * 0.15), (cx + r * 0.3, cy + r * 0.65)], fill=color, width=max(3, size // 18))
        draw.line([(cx, cy - r * 0.25), (cx - r * 0.35, cy + r * 0.05)], fill=color, width=max(3, size // 18))
        draw.line([(cx, cy - r * 0.25), (cx + r * 0.35, cy - r * 0.05)], fill=color, width=max(3, size // 18))

    elif icon_type == "share":
        cx, cy = x + size // 2, y + size // 2
        r = size // 2 - 4
        draw.line([(cx, cy - r * 0.6), (cx, cy + r * 0.2)], fill=color, width=max(4, size // 12))
        draw.line([(cx - r * 0.3, cy - r * 0.3), (cx, cy - r * 0.6)], fill=color, width=max(4, size // 12))
        draw.line([(cx + r * 0.3, cy - r * 0.3), (cx, cy - r * 0.6)], fill=color, width=max(4, size // 12))
        bx1 = cx - r * 0.5
        bx2 = cx + r * 0.5
        by1 = cy - r * 0.05
        by2 = cy + r * 0.6
        draw.line([(bx1, by1), (bx1, by2)], fill=color, width=max(4, size // 12))
        draw.line([(bx1, by2), (bx2, by2)], fill=color, width=max(4, size // 12))
        draw.line([(bx2, by1), (bx2, by2)], fill=color, width=max(4, size // 12))


# ---------------------------------------------------------------------------
# Phone frame + status bar helper
# ---------------------------------------------------------------------------

def get_phone_metrics(W, H):
    """Compute phone frame dimensions relative to screenshot size."""
    margin_x = int(W * 0.10)
    phone_w = W - 2 * margin_x
    phone_h = int(H * 0.62)
    phone_x = margin_x
    phone_y = int(H * 0.28)
    phone_radius = int(W * 0.06)
    return phone_x, phone_y, phone_w, phone_h, phone_radius


def draw_status_bar(draw, px, py, pw, font_size):
    """Draw a simulated iOS status bar inside the phone frame."""
    sb_font = get_font(font_size, bold=True)
    sb_y = py + int(font_size * 0.6)
    draw.text((px + int(pw * 0.07), sb_y), "9:41", font=sb_font, fill=DARK_GRAY)
    # Battery
    ri_x = px + pw - int(pw * 0.22)
    bw2 = int(pw * 0.065)
    bh2 = int(font_size * 0.55)
    by2 = sb_y + int(font_size * 0.15)
    draw.rounded_rectangle([ri_x, by2, ri_x + bw2, by2 + bh2], radius=3, outline=DARK_GRAY, width=2)
    draw.rounded_rectangle([ri_x + 2, by2 + 2, ri_x + int(bw2 * 0.75), by2 + bh2 - 2], radius=2, fill=CAT_GREEN)
    draw.rounded_rectangle([ri_x + bw2, by2 + bh2 // 4, ri_x + bw2 + 4, by2 + 3 * bh2 // 4], radius=1, fill=DARK_GRAY)
    # Signal bars
    sd_x = ri_x - int(pw * 0.10)
    for i in range(4):
        dot_h = int(bh2 * (0.4 + 0.2 * i))
        dot_w = int(pw * 0.012)
        dot_y = by2 + bh2 - dot_h
        dot_xi = sd_x + i * (dot_w + 4)
        draw.rounded_rectangle([dot_xi, dot_y, dot_xi + dot_w, by2 + bh2], radius=2, fill=DARK_GRAY)
    # WiFi
    wf_x = sd_x - int(pw * 0.055)
    for i in range(3):
        arc_r = int(bh2 * 0.25 * (i + 1))
        arc_w = max(2, int(pw * 0.004))
        if i < 2:
            draw.arc([wf_x - arc_r, by2 + bh2 - 2 * arc_r, wf_x + arc_r, by2 + bh2],
                     200, 340, fill=DARK_GRAY, width=arc_w)
    draw_circle(draw, wf_x, by2 + bh2 - 2, 3, DARK_GRAY)


def draw_nav_bar(draw, px, py, pw, ph, title, font):
    """Draw a simulated navigation bar title."""
    bar_y = py + int(ph * 0.07)
    bbox = draw.textbbox((0, 0), title, font=font)
    tw = bbox[2] - bbox[0]
    tx = px + (pw - tw) // 2
    draw.text((tx, bar_y), title, font=font, fill=BLACK)
    sep_y = bar_y + int((bbox[3] - bbox[1]) * 1.8)
    draw.line([(px + int(pw * 0.05), sep_y), (px + pw - int(pw * 0.05), sep_y)], fill=LIGHT_GRAY, width=2)
    return sep_y + 10


# ---------------------------------------------------------------------------
# Screenshot content renderers
# ---------------------------------------------------------------------------

def draw_screenshot_1(draw, px, py, pw, ph, scale):
    """Trip list screen with 3 trip cards."""
    sb_font_size = int(28 * scale)
    draw_status_bar(draw, px, py, pw, sb_font_size)

    nav_font = get_font(int(42 * scale), bold=True)
    content_y = draw_nav_bar(draw, px, py, pw, ph, "My Trips", nav_font)

    trips = [
        ("Paris, France", "Jun 15 - Jun 22, 2025", TRIP_COLORS[0]),
        ("Tokyo, Japan", "Aug 3 - Aug 14, 2025", TRIP_COLORS[1]),
        ("Barcelona, Spain", "Oct 1 - Oct 8, 2025", TRIP_COLORS[2]),
    ]

    card_margin = int(pw * 0.06)
    card_w = pw - 2 * card_margin
    card_h = int(ph * 0.20)
    card_gap = int(ph * 0.025)
    card_x = px + card_margin
    card_y = content_y + int(ph * 0.025)

    title_font = get_font(int(36 * scale), bold=True)
    sub_font = get_font(int(24 * scale))
    detail_font = get_font(int(20 * scale))

    trip_details = ["7 days · 12 activities", "11 days · 18 activities", "7 days · 9 activities"]

    for i, (dest, dates, accent) in enumerate(trips):
        cy = card_y + i * (card_h + card_gap)
        draw.rounded_rectangle([card_x, cy, card_x + card_w, cy + card_h],
                               radius=int(20 * scale), fill=OFF_WHITE, outline=LIGHT_GRAY, width=2)
        # Accent stripe on left
        stripe_w = int(8 * scale)
        draw.rounded_rectangle([card_x, cy, card_x + stripe_w + int(20 * scale), cy + card_h],
                               radius=int(20 * scale), fill=accent)
        draw.rectangle([card_x + int(20 * scale), cy, card_x + stripe_w + int(20 * scale), cy + card_h], fill=accent)
        # Photo placeholder
        img_margin = int(20 * scale)
        img_size = card_h - 2 * img_margin
        img_x = card_x + stripe_w + img_margin + int(8 * scale)
        img_y = cy + img_margin
        for row in range(img_size):
            t = row / img_size
            c = lerp_color(accent, lerp_color(accent, WHITE, 0.3), t * 0.5)
            draw.line([(img_x, img_y + row), (img_x + img_size, img_y + row)], fill=c)
        draw.rounded_rectangle([img_x, img_y, img_x + img_size, img_y + img_size],
                               radius=int(12 * scale), outline=accent, width=2)
        # City initial
        initial_font = get_font(int(48 * scale), bold=True)
        initial = dest[0]
        ib = draw.textbbox((0, 0), initial, font=initial_font)
        ix = img_x + (img_size - (ib[2] - ib[0])) // 2
        iy = img_y + (img_size - (ib[3] - ib[1])) // 2
        draw.text((ix, iy), initial, font=initial_font, fill=WHITE)
        # Text
        text_x = img_x + img_size + int(20 * scale)
        draw.text((text_x, cy + int(card_h * 0.22)), dest, font=title_font, fill=BLACK)
        draw.text((text_x, cy + int(card_h * 0.50)), dates, font=sub_font, fill=DARK_GRAY)
        draw.text((text_x, cy + int(card_h * 0.72)), trip_details[i], font=detail_font, fill=MID_GRAY)

    # FAB
    fab_r = int(35 * scale)
    fab_cx = px + pw - card_margin - fab_r
    fab_cy = card_y + 3 * (card_h + card_gap) + int(20 * scale)
    if fab_cy + fab_r < py + ph - int(20 * scale):
        draw.ellipse([fab_cx - fab_r, fab_cy - fab_r, fab_cx + fab_r, fab_cy + fab_r], fill=BLUE)
        plus_font = get_font(int(44 * scale), bold=True)
        pb = draw.textbbox((0, 0), "+", font=plus_font)
        draw.text((fab_cx - (pb[2] - pb[0]) // 2, fab_cy - (pb[3] - pb[1]) // 2 - int(4 * scale)),
                  "+", font=plus_font, fill=WHITE)


def draw_screenshot_2(draw, px, py, pw, ph, scale):
    """Day-by-day itinerary screen."""
    sb_font_size = int(28 * scale)
    draw_status_bar(draw, px, py, pw, sb_font_size)

    nav_font = get_font(int(42 * scale), bold=True)
    content_y = draw_nav_bar(draw, px, py, pw, ph, "Paris, France", nav_font)

    margin = int(pw * 0.06)
    inner_x = px + margin
    inner_w = pw - 2 * margin

    # Day tabs
    day_font = get_font(int(26 * scale), bold=True)
    tab_y = content_y + int(15 * scale)
    tab_w = int(inner_w / 3.5)
    tab_h = int(50 * scale)
    days_labels = ["Day 1", "Day 2", "Day 3"]
    for i, label in enumerate(days_labels):
        tx = inner_x + i * (tab_w + int(10 * scale))
        if i == 0:
            draw.rounded_rectangle([tx, tab_y, tx + tab_w, tab_y + tab_h],
                                   radius=int(12 * scale), fill=BLUE)
            draw.text((tx + int(15 * scale), tab_y + int(12 * scale)), label, font=day_font, fill=WHITE)
        else:
            draw.rounded_rectangle([tx, tab_y, tx + tab_w, tab_y + tab_h],
                                   radius=int(12 * scale), fill=LIGHT_GRAY)
            draw.text((tx + int(15 * scale), tab_y + int(12 * scale)), label, font=day_font, fill=DARK_GRAY)

    # Day header
    header_y = tab_y + tab_h + int(25 * scale)
    header_font = get_font(int(34 * scale), bold=True)
    draw.text((inner_x, header_y), "Day 1 — June 15", font=header_font, fill=BLACK)
    header_sub_font = get_font(int(22 * scale))
    draw.text((inner_x, header_y + int(42 * scale)), "4 activities planned", font=header_sub_font, fill=MID_GRAY)

    # Timeline stops
    stops = [
        ("9:00 AM", "Cafe de Flore", "Breakfast & coffee", CAT_BLUE, "Restaurant"),
        ("11:30 AM", "Eiffel Tower", "Guided tour - 2hrs", CAT_RED, "Attraction"),
        ("2:00 PM", "Le Jules Verne", "Lunch reservation", CAT_BLUE, "Restaurant"),
        ("4:30 PM", "Hotel Le Marais", "Check-in & rest", CAT_GREEN, "Hotel"),
    ]

    stop_y = header_y + int(85 * scale)
    time_font = get_font(int(24 * scale), bold=True)
    stop_title_font = get_font(int(30 * scale), bold=True)
    stop_sub_font = get_font(int(22 * scale))
    cat_font = get_font(int(18 * scale))

    timeline_x = inner_x + int(110 * scale)
    card_h = int(ph * 0.14)
    card_gap = int(15 * scale)

    for i, (time, title, sub, color, cat) in enumerate(stops):
        sy = stop_y + i * (card_h + card_gap)
        # Time label
        draw.text((inner_x, sy + int(15 * scale)), time, font=time_font, fill=DARK_GRAY)
        # Timeline line
        line_x = timeline_x - int(15 * scale)
        if i < len(stops) - 1:
            draw.line([(line_x, sy + int(18 * scale)), (line_x, sy + card_h + card_gap)],
                      fill=LIGHT_GRAY, width=3)
        # Timeline dot
        draw_circle(draw, line_x, sy + int(18 * scale), int(8 * scale), color)
        # Card
        card_x = timeline_x + int(10 * scale)
        card_w2 = inner_x + inner_w - card_x
        draw.rounded_rectangle([card_x, sy, card_x + card_w2, sy + card_h],
                               radius=int(16 * scale), fill=OFF_WHITE, outline=LIGHT_GRAY, width=2)
        draw.text((card_x + int(18 * scale), sy + int(14 * scale)), title, font=stop_title_font, fill=BLACK)
        draw.text((card_x + int(18 * scale), sy + int(50 * scale)), sub, font=stop_sub_font, fill=DARK_GRAY)
        # Category pill
        pill_y = sy + int(80 * scale)
        cat_bb = draw.textbbox((0, 0), cat, font=cat_font)
        cat_tw = cat_bb[2] - cat_bb[0]
        pill_w2 = cat_tw + int(20 * scale)
        pill_h = int(28 * scale)
        pill_x = card_x + int(18 * scale)
        pill_color = lerp_color(color, WHITE, 0.85)
        draw.rounded_rectangle([pill_x, pill_y, pill_x + pill_w2, pill_y + pill_h],
                               radius=pill_h // 2, fill=pill_color)
        draw.text((pill_x + int(10 * scale), pill_y + int(4 * scale)), cat, font=cat_font, fill=color)


def draw_screenshot_3(draw, px, py, pw, ph, scale):
    """Bookings tracking screen."""
    sb_font_size = int(28 * scale)
    draw_status_bar(draw, px, py, pw, sb_font_size)

    nav_font = get_font(int(42 * scale), bold=True)
    content_y = draw_nav_bar(draw, px, py, pw, ph, "Bookings", nav_font)

    margin = int(pw * 0.06)
    inner_x = px + margin
    inner_w = pw - 2 * margin

    bookings = [
        ("airplane", CAT_BLUE, "Delta DL123", "JFK -> CDG", "Jun 15, 2025 - 7:30 PM", "Confirmed"),
        ("hotel", CAT_RED, "Hotel Le Marais", "Confirmation: ABC123", "Jun 15 - Jun 22", "Confirmed"),
        ("car", CAT_GREEN, "Hertz Rental", "Confirmation: XY789", "Jun 15 - Jun 22", "Confirmed"),
    ]

    card_y = content_y + int(20 * scale)
    card_h = int(ph * 0.22)
    card_gap = int(20 * scale)

    title_font = get_font(int(32 * scale), bold=True)
    sub_font = get_font(int(24 * scale))
    detail_font = get_font(int(20 * scale))
    badge_font = get_font(int(18 * scale), bold=True)

    for i, (icon_type, color, title, detail, date, status) in enumerate(bookings):
        cy = card_y + i * (card_h + card_gap)

        draw.rounded_rectangle([inner_x, cy, inner_x + inner_w, cy + card_h],
                               radius=int(20 * scale), fill=OFF_WHITE, outline=LIGHT_GRAY, width=2)
        # Top accent bar
        draw.rounded_rectangle([inner_x, cy, inner_x + inner_w, cy + int(22 * scale)],
                               radius=int(20 * scale), fill=color)
        draw.rectangle([inner_x, cy + int(12 * scale), inner_x + inner_w, cy + int(22 * scale)], fill=color)
        draw.rectangle([inner_x + 1, cy + int(22 * scale), inner_x + inner_w - 1, cy + int(24 * scale)],
                       fill=OFF_WHITE)
        # Icon
        icon_size = int(65 * scale)
        icon_x = inner_x + int(20 * scale)
        icon_y = cy + int(35 * scale)
        draw_icon_placeholder(draw, icon_x, icon_y, icon_size, icon_type, color)
        # Text
        text_x = icon_x + icon_size + int(20 * scale)
        draw.text((text_x, cy + int(38 * scale)), title, font=title_font, fill=BLACK)
        draw.text((text_x, cy + int(75 * scale)), detail, font=sub_font, fill=DARK_GRAY)
        draw.text((text_x, cy + int(108 * scale)), date, font=detail_font, fill=MID_GRAY)
        # Status badge
        badge_bb = draw.textbbox((0, 0), status, font=badge_font)
        badge_tw = badge_bb[2] - badge_bb[0]
        badge_w = badge_tw + int(24 * scale)
        badge_h_val = int(30 * scale)
        badge_x = inner_x + inner_w - badge_w - int(18 * scale)
        badge_y = cy + int(card_h * 0.7)
        badge_bg = lerp_color(CAT_GREEN, WHITE, 0.85)
        draw.rounded_rectangle([badge_x, badge_y, badge_x + badge_w, badge_y + badge_h_val],
                               radius=badge_h_val // 2, fill=badge_bg)
        draw.text((badge_x + int(12 * scale), badge_y + int(5 * scale)), status, font=badge_font, fill=CAT_GREEN)


def draw_screenshot_4(draw, px, py, pw, ph, scale):
    """Weather & travel times screen."""
    sb_font_size = int(28 * scale)
    draw_status_bar(draw, px, py, pw, sb_font_size)

    nav_font = get_font(int(42 * scale), bold=True)
    content_y = draw_nav_bar(draw, px, py, pw, ph, "Weather & Travel", nav_font)

    margin = int(pw * 0.06)
    inner_x = px + margin
    inner_w = pw - 2 * margin

    # Weather section
    section_font = get_font(int(30 * scale), bold=True)
    sy = content_y + int(20 * scale)
    draw.text((inner_x, sy), "Weather Forecast", font=section_font, fill=BLACK)

    weather = [
        ("Mon", "sun", "72F", "Sunny"),
        ("Tue", "cloud_sun", "68F", "Partly Cloudy"),
        ("Wed", "sun", "75F", "Sunny"),
    ]

    card_y = sy + int(50 * scale)
    card_w = int((inner_w - 2 * int(12 * scale)) / 3)
    card_h_w = int(ph * 0.26)

    temp_font = get_font(int(38 * scale), bold=True)
    day_font = get_font(int(24 * scale), bold=True)
    desc_font = get_font(int(18 * scale))

    for i, (day, icon, temp, desc) in enumerate(weather):
        cx = inner_x + i * (card_w + int(12 * scale))
        draw.rounded_rectangle([cx, card_y, cx + card_w, card_y + card_h_w],
                               radius=int(18 * scale), fill=OFF_WHITE, outline=LIGHT_GRAY, width=2)
        db = draw.textbbox((0, 0), day, font=day_font)
        dtw = db[2] - db[0]
        draw.text((cx + (card_w - dtw) // 2, card_y + int(15 * scale)), day, font=day_font, fill=DARK_GRAY)
        icon_size = int(70 * scale)
        draw_icon_placeholder(draw, cx + (card_w - icon_size) // 2,
                              card_y + int(50 * scale), icon_size, icon, DARK_GRAY)
        tb = draw.textbbox((0, 0), temp, font=temp_font)
        ttw = tb[2] - tb[0]
        draw.text((cx + (card_w - ttw) // 2, card_y + int(130 * scale)), temp, font=temp_font, fill=BLACK)
        dbb = draw.textbbox((0, 0), desc, font=desc_font)
        ddtw = dbb[2] - dbb[0]
        draw.text((cx + (card_w - ddtw) // 2, card_y + int(175 * scale)), desc, font=desc_font, fill=MID_GRAY)

    # Travel times section
    travel_y = card_y + card_h_w + int(35 * scale)
    draw.text((inner_x, travel_y), "Travel Times", font=section_font, fill=BLACK)

    travel_card_y = travel_y + int(50 * scale)
    travel_card_h = int(ph * 0.14)
    draw.rounded_rectangle([inner_x, travel_card_y, inner_x + inner_w, travel_card_y + travel_card_h],
                           radius=int(18 * scale), fill=OFF_WHITE, outline=LIGHT_GRAY, width=2)

    half_w = inner_w // 2
    entries = [
        ("car", "By Car", "15 min", CAT_BLUE),
        ("walk", "Walking", "32 min", CAT_GREEN),
    ]

    time_font_t = get_font(int(34 * scale), bold=True)
    label_font = get_font(int(20 * scale))

    for j, (icon, label, time_str, color) in enumerate(entries):
        ex = inner_x + j * half_w
        ecy = travel_card_y + travel_card_h // 2
        if j == 1:
            draw.line([(ex, travel_card_y + int(15 * scale)),
                       (ex, travel_card_y + travel_card_h - int(15 * scale))],
                      fill=LIGHT_GRAY, width=2)
        icon_s = int(50 * scale)
        draw_icon_placeholder(draw, ex + int(20 * scale),
                              ecy - icon_s // 2, icon_s, icon, color)
        txx = ex + int(80 * scale)
        draw.text((txx, ecy - int(25 * scale)), time_str, font=time_font_t, fill=BLACK)
        draw.text((txx, ecy + int(12 * scale)), label, font=label_font, fill=MID_GRAY)

    # Route info
    route_y = travel_card_y + travel_card_h + int(20 * scale)
    route_h = int(ph * 0.08)
    if route_y + route_h < py + ph - int(15 * scale):
        draw.rounded_rectangle([inner_x, route_y, inner_x + inner_w, route_y + route_h],
                               radius=int(14 * scale), fill=lerp_color(BLUE, WHITE, 0.9),
                               outline=lerp_color(BLUE, WHITE, 0.7), width=2)
        draw.text((inner_x + int(20 * scale), route_y + int(route_h * 0.15)),
                  "Eiffel Tower -> Le Jules Verne", font=get_font(int(24 * scale), bold=True), fill=BLUE)
        route_font = get_font(int(22 * scale))
        draw.text((inner_x + int(20 * scale), route_y + int(route_h * 0.55)),
                  "1.2 km - Scenic route available", font=route_font, fill=DARK_GRAY)


def draw_screenshot_5(draw, px, py, pw, ph, scale):
    """Share itinerary screen."""
    sb_font_size = int(28 * scale)
    draw_status_bar(draw, px, py, pw, sb_font_size)

    nav_font = get_font(int(42 * scale), bold=True)
    content_y = draw_nav_bar(draw, px, py, pw, ph, "Share Trip", nav_font)

    margin = int(pw * 0.06)
    inner_x = px + margin
    inner_w = pw - 2 * margin

    # PDF preview
    pdf_y = content_y + int(20 * scale)
    pdf_h = int(ph * 0.52)
    draw.rounded_rectangle([inner_x, pdf_y, inner_x + inner_w, pdf_y + pdf_h],
                           radius=int(18 * scale), fill=WHITE, outline=LIGHT_GRAY, width=3)

    pdf_inner_margin = int(25 * scale)
    pdf_ix = inner_x + pdf_inner_margin
    pdf_iw = inner_w - 2 * pdf_inner_margin

    # PDF header
    logo_y = pdf_y + pdf_inner_margin
    logo_font = get_font(int(36 * scale), bold=True)
    draw.text((pdf_ix, logo_y), "Travly", font=logo_font, fill=BLUE)
    sub_logo = get_font(int(20 * scale))
    draw.text((pdf_ix, logo_y + int(44 * scale)), "Trip Itinerary", font=sub_logo, fill=MID_GRAY)

    div_y = logo_y + int(80 * scale)
    draw.line([(pdf_ix, div_y), (pdf_ix + pdf_iw, div_y)], fill=LIGHT_GRAY, width=2)

    trip_title_y = div_y + int(20 * scale)
    trip_font = get_font(int(30 * scale), bold=True)
    draw.text((pdf_ix, trip_title_y), "Paris, France", font=trip_font, fill=BLACK)
    trip_date_font = get_font(int(20 * scale))
    draw.text((pdf_ix, trip_title_y + int(38 * scale)), "June 15 - June 22, 2025", font=trip_date_font, fill=DARK_GRAY)

    # Simulated text lines
    line_y = trip_title_y + int(80 * scale)
    line_h = int(12 * scale)
    line_gap = int(18 * scale)
    line_configs = [
        (DARKER_GRAY, 1.0),
        (MID_GRAY, 0.85),
        (MID_GRAY, 0.70),
        (LIGHT_GRAY, 0.60),
        (DARKER_GRAY, 0.95),
        (MID_GRAY, 0.80),
        (MID_GRAY, 0.55),
        (LIGHT_GRAY, 0.45),
        (DARKER_GRAY, 0.90),
        (MID_GRAY, 0.75),
        (MID_GRAY, 0.50),
    ]
    for i, (color, width_pct) in enumerate(line_configs):
        ly = line_y + i * (line_h + line_gap)
        if ly + line_h > pdf_y + pdf_h - pdf_inner_margin:
            break
        lw = int(pdf_iw * width_pct)
        if i in (0, 4, 8):
            draw.rounded_rectangle([pdf_ix, ly, pdf_ix + lw, ly + line_h + 2],
                                   radius=3, fill=lerp_color(color, WHITE, 0.3))
        else:
            draw.rounded_rectangle([pdf_ix, ly, pdf_ix + lw, ly + line_h],
                                   radius=3, fill=lerp_color(color, WHITE, 0.5))

    # Share FAB
    share_size = int(80 * scale)
    share_cx = inner_x + inner_w - int(50 * scale)
    share_cy = pdf_y + pdf_h - int(50 * scale)
    draw.ellipse([share_cx - share_size // 2, share_cy - share_size // 2,
                  share_cx + share_size // 2, share_cy + share_size // 2], fill=BLUE)
    draw_icon_placeholder(draw, share_cx - int(25 * scale), share_cy - int(25 * scale),
                          int(50 * scale), "share", WHITE)

    # Share options
    options_y = pdf_y + pdf_h + int(25 * scale)
    option_font = get_font(int(24 * scale), bold=True)
    option_sub = get_font(int(20 * scale))

    share_options = [
        ("Share as PDF", "Generate a downloadable PDF", BLUE),
        ("Share Link", "Create a shareable web link", CAT_PURPLE),
        ("AirDrop", "Send to nearby Apple devices", CAT_GREEN),
    ]

    opt_h = int(ph * 0.08)
    opt_gap = int(10 * scale)

    for i, (label, sub, color) in enumerate(share_options):
        oy = options_y + i * (opt_h + opt_gap)
        if oy + opt_h > py + ph - int(10 * scale):
            break
        draw.rounded_rectangle([inner_x, oy, inner_x + inner_w, oy + opt_h],
                               radius=int(14 * scale), fill=OFF_WHITE, outline=LIGHT_GRAY, width=2)
        draw_circle(draw, inner_x + int(30 * scale), oy + opt_h // 2, int(8 * scale), color)
        draw.text((inner_x + int(50 * scale), oy + int(opt_h * 0.12)), label, font=option_font, fill=BLACK)
        draw.text((inner_x + int(50 * scale), oy + int(opt_h * 0.50)), sub, font=option_sub, fill=MID_GRAY)


# ---------------------------------------------------------------------------
# Main generation logic
# ---------------------------------------------------------------------------

SCREENSHOTS = [
    {
        "title": "Plan Your Perfect Trip",
        "subtitle": "Organize every detail of your journey",
        "gradient": ("vertical", BLUE, TEAL),
        "renderer": draw_screenshot_1,
    },
    {
        "title": "Day-by-Day Itinerary",
        "subtitle": "Every stop, perfectly organized",
        "gradient": ("diagonal", (0, 100, 220), TEAL),
        "renderer": draw_screenshot_2,
    },
    {
        "title": "Track All Your Bookings",
        "subtitle": "Flights, hotels, and rentals in one place",
        "gradient": ("horizontal", TEAL, BLUE),
        "renderer": draw_screenshot_3,
    },
    {
        "title": "Weather & Travel Times",
        "subtitle": "Know what to expect, always",
        "gradient": ("diagonal_reverse", BLUE, (0, 180, 120)),
        "renderer": draw_screenshot_4,
    },
    {
        "title": "Share Your Itinerary",
        "subtitle": "Export and share with anyone",
        "gradient": ("vertical", (0, 80, 200), TEAL),
        "renderer": draw_screenshot_5,
    },
]


def generate_screenshot(index, config, size_label, dimensions):
    W, H = dimensions
    scale = W / 1290.0

    img = Image.new("RGB", (W, H), WHITE)
    draw = ImageDraw.Draw(img)

    # Background gradient
    grad_dir, c1, c2 = config["gradient"]
    draw_gradient_fast(img, c1, c2, grad_dir)

    # Marketing title
    title_font_size = int(72 * scale)
    subtitle_font_size = int(36 * scale)
    title_font = get_font(title_font_size, bold=True)
    subtitle_font = get_font(subtitle_font_size)

    title = config["title"]
    subtitle = config["subtitle"]

    title_y = int(H * 0.06)

    # Check if title is too wide, shrink if needed
    tb = draw.textbbox((0, 0), title, font=title_font)
    title_tw = tb[2] - tb[0]
    if title_tw > W * 0.88:
        title_font = get_font(int(title_font_size * 0.85), bold=True)

    text_centered(draw, title, title_y, title_font, fill=WHITE, img_width=W)

    subtitle_y = title_y + int(90 * scale)
    text_centered(draw, subtitle, subtitle_y, subtitle_font, fill=WHITE, img_width=W)

    # App name badge
    badge_font_obj = get_font(int(24 * scale), bold=True, rounded=True)
    badge_text = "Travly"
    badge_bb = draw.textbbox((0, 0), badge_text, font=badge_font_obj)
    badge_tw = badge_bb[2] - badge_bb[0]
    badge_w = badge_tw + int(40 * scale)
    badge_h = int(38 * scale)
    badge_x = (W - badge_w) // 2
    badge_y_pos = title_y - int(52 * scale)
    pill_bg = lerp_color(c1, WHITE, 0.25)
    draw.rounded_rectangle([badge_x, badge_y_pos, badge_x + badge_w, badge_y_pos + badge_h],
                           radius=badge_h // 2, fill=pill_bg)
    draw.text((badge_x + int(20 * scale), badge_y_pos + int(7 * scale)), badge_text, font=badge_font_obj, fill=WHITE)

    # Phone frame
    phone_x, phone_y, phone_w, phone_h, phone_radius = get_phone_metrics(W, H)

    # Phone shadow layers
    for s in range(12, 0, -1):
        shadow_alpha = max(0, 60 - s * 5)
        sc = lerp_color(lerp_color(c1, c2, phone_y / H), (0, 0, 0), shadow_alpha / 255)
        draw.rounded_rectangle(
            [phone_x - s // 2, phone_y + s, phone_x + phone_w + s // 2, phone_y + phone_h + s * 2],
            radius=phone_radius + s,
            fill=sc
        )

    # Main phone body
    draw.rounded_rectangle(
        [phone_x, phone_y, phone_x + phone_w, phone_y + phone_h],
        radius=phone_radius,
        fill=WHITE
    )

    # Dynamic Island
    notch_w = int(phone_w * 0.28)
    notch_h = int(22 * scale)
    notch_x = phone_x + (phone_w - notch_w) // 2
    notch_y = phone_y + int(12 * scale)
    draw.rounded_rectangle([notch_x, notch_y, notch_x + notch_w, notch_y + notch_h],
                           radius=notch_h // 2, fill=DARKER_GRAY)

    # Home indicator
    indicator_w = int(phone_w * 0.35)
    indicator_h = int(8 * scale)
    indicator_x = phone_x + (phone_w - indicator_w) // 2
    indicator_y = phone_y + phone_h - int(25 * scale)
    draw.rounded_rectangle([indicator_x, indicator_y, indicator_x + indicator_w, indicator_y + indicator_h],
                           radius=indicator_h // 2, fill=LIGHT_GRAY)

    # Screen content
    content_pad = int(15 * scale)
    screen_x = phone_x + content_pad
    screen_y = phone_y + content_pad
    screen_w = phone_w - 2 * content_pad
    screen_h = phone_h - 2 * content_pad
    config["renderer"](draw, screen_x, screen_y, screen_w, screen_h, scale)

    # Page indicator dots
    dot_y = int(H * 0.955)
    dot_r = int(6 * scale)
    dot_gap = int(22 * scale)
    total_dots_w = 5 * (2 * dot_r) + 4 * dot_gap
    dot_start_x = (W - total_dots_w) // 2
    for d in range(5):
        dx = dot_start_x + d * (2 * dot_r + dot_gap) + dot_r
        if d == index:
            draw.ellipse([dx - dot_r, dot_y - dot_r, dx + dot_r, dot_y + dot_r], fill=WHITE)
        else:
            dot_c = lerp_color(lerp_color(c1, c2, 0.7), WHITE, 0.4)
            draw.ellipse([dx - dot_r, dot_y - dot_r, dx + dot_r, dot_y + dot_r], fill=dot_c)

    # Save
    dir_path = os.path.join(OUTPUT_BASE, size_label)
    os.makedirs(dir_path, exist_ok=True)
    file_path = os.path.join(dir_path, f"screenshot_{index + 1}.png")
    img.save(file_path, "PNG")
    print(f"  Saved: {file_path} ({W}x{H})")


def main():
    print("Generating Travly App Store Screenshots...")
    print("=" * 50)
    for size_label, dimensions in SIZES.items():
        print(f"\n{size_label}\" display ({dimensions[0]}x{dimensions[1]}):")
        for i, config in enumerate(SCREENSHOTS):
            generate_screenshot(i, config, size_label, dimensions)
    print("\nDone! All screenshots generated successfully.")


if __name__ == "__main__":
    main()
