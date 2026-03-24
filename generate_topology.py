"""Generate starter-kit/network-topology.png using only the Python standard library."""

from __future__ import annotations

import struct
import zlib


W = 1400
H = 900


def rgb(hex_color: str) -> tuple[int, int, int]:
    hex_color = hex_color.lstrip("#")
    return (int(hex_color[0:2], 16), int(hex_color[2:4], 16), int(hex_color[4:6], 16))


def new_canvas(width: int, height: int, color: tuple[int, int, int]) -> bytearray:
    r, g, b = color
    row = bytes([r, g, b]) * width
    return bytearray(row * height)


def set_px(buf: bytearray, x: int, y: int, color: tuple[int, int, int]) -> None:
    if x < 0 or y < 0 or x >= W or y >= H:
        return
    i = (y * W + x) * 3
    buf[i : i + 3] = bytes(color)


def fill_rect(buf: bytearray, x: int, y: int, w: int, h: int, color: tuple[int, int, int]) -> None:
    for yy in range(y, y + h):
        if yy < 0 or yy >= H:
            continue
        start = (yy * W + max(0, x)) * 3
        end_x = min(W, x + w)
        if end_x <= 0:
            continue
        segment = bytes(color) * (end_x - max(0, x))
        buf[start : start + len(segment)] = segment


def rect_outline(
    buf: bytearray, x: int, y: int, w: int, h: int, color: tuple[int, int, int], thickness: int = 2
) -> None:
    fill_rect(buf, x, y, w, thickness, color)
    fill_rect(buf, x, y + h - thickness, w, thickness, color)
    fill_rect(buf, x, y, thickness, h, color)
    fill_rect(buf, x + w - thickness, y, thickness, h, color)


FONT = {
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "B": ["11110", "10001", "11110", "10001", "10001", "10001", "11110"],
    "C": ["01111", "10000", "10000", "10000", "10000", "10000", "01111"],
    "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
    "E": ["11111", "10000", "11110", "10000", "10000", "10000", "11111"],
    "F": ["11111", "10000", "11110", "10000", "10000", "10000", "10000"],
    "G": ["01111", "10000", "10000", "10011", "10001", "10001", "01111"],
    "H": ["10001", "10001", "11111", "10001", "10001", "10001", "10001"],
    "I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
    "J": ["00111", "00010", "00010", "00010", "10010", "10010", "01100"],
    "K": ["10001", "10010", "11100", "10010", "10010", "10001", "10001"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    "Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
    "R": ["11110", "10001", "10001", "11110", "10010", "10001", "10001"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    "V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
    "W": ["10001", "10001", "10001", "10101", "10101", "10101", "01010"],
    "X": ["10001", "01010", "00100", "00100", "00100", "01010", "10001"],
    "Y": ["10001", "01010", "00100", "00100", "00100", "00100", "00100"],
    "Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
    "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
    "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
    "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
    "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    "5": ["11111", "10000", "10000", "11110", "00001", "00001", "11110"],
    "6": ["01110", "10000", "10000", "11110", "10001", "10001", "01110"],
    "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
    "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
    "9": ["01110", "10001", "10001", "01111", "00001", "00001", "01110"],
    "-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
    "/": ["00001", "00010", "00100", "01000", "10000", "00000", "00000"],
    ":": ["00000", "00100", "00100", "00000", "00100", "00100", "00000"],
    "(": ["00010", "00100", "01000", "01000", "01000", "00100", "00010"],
    ")": ["01000", "00100", "00010", "00010", "00010", "00100", "01000"],
    " ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"],
    ".": ["00000", "00000", "00000", "00000", "00000", "00110", "00110"],
    ",": ["00000", "00000", "00000", "00000", "00110", "00110", "00100"],
}


def draw_text(buf: bytearray, x: int, y: int, text: str, color: tuple[int, int, int], scale: int = 2) -> None:
    cursor = x
    for ch in text.upper():
        glyph = FONT.get(ch, FONT[" "])
        for gy, row in enumerate(glyph):
            for gx, px in enumerate(row):
                if px == "1":
                    fill_rect(buf, cursor + gx * scale, y + gy * scale, scale, scale, color)
        cursor += (5 * scale) + scale


def draw_arrow(buf: bytearray, x1: int, y1: int, x2: int, y2: int, color: tuple[int, int, int]) -> None:
    dx = x2 - x1
    dy = y2 - y1
    steps = max(abs(dx), abs(dy))
    if steps == 0:
        return
    for i in range(steps + 1):
        x = x1 + dx * i // steps
        y = y1 + dy * i // steps
        fill_rect(buf, x - 1, y - 1, 3, 3, color)
    fill_rect(buf, x2 - 5, y2 - 3, 6, 6, color)


def write_png(path: str, width: int, height: int, rgb_data: bytes) -> None:
    raw = bytearray()
    stride = width * 3
    for y in range(height):
        raw.append(0)
        start = y * stride
        raw.extend(rgb_data[start : start + stride])

    compressed = zlib.compress(bytes(raw), 9)

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", compressed) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def main() -> None:
    bg = rgb("#F7F7F7")
    buf = new_canvas(W, H, bg)

    c_vpc = rgb("#E8F4FB")
    c_vpc_edge = rgb("#1A73E8")
    c_public = rgb("#D4EDDA")
    c_public_edge = rgb("#28A745")
    c_private = rgb("#FFF3CD")
    c_private_edge = rgb("#FD7E14")
    c_data = rgb("#FDE8E8")
    c_data_edge = rgb("#DC3545")
    c_blue = rgb("#004085")
    c_black = rgb("#222222")

    # VPC wrapper
    fill_rect(buf, 40, 70, 1320, 790, c_vpc)
    rect_outline(buf, 40, 70, 1320, 790, c_vpc_edge, 4)

    # Internet + components row
    fill_rect(buf, 60, 20, 210, 45, rgb("#CCE5FF"))
    rect_outline(buf, 60, 20, 210, 45, c_blue, 3)
    draw_text(buf, 90, 35, "Internet", c_blue, 2)

    fill_rect(buf, 320, 20, 220, 45, rgb("#B8DAFF"))
    rect_outline(buf, 320, 20, 220, 45, c_blue, 2)
    draw_text(buf, 350, 35, "IGW", c_blue, 2)

    fill_rect(buf, 580, 20, 220, 45, rgb("#D1ECF1"))
    rect_outline(buf, 580, 20, 220, 45, rgb("#17A2B8"), 2)
    draw_text(buf, 620, 35, "NAT GW", rgb("#0C5460"), 2)

    fill_rect(buf, 850, 20, 280, 45, rgb("#D6D8F7"))
    rect_outline(buf, 850, 20, 280, 45, rgb("#6610F2"), 2)
    draw_text(buf, 920, 35, "ALB HTTPS 443", rgb("#4B0082"), 2)

    draw_arrow(buf, 270, 42, 320, 42, c_blue)
    draw_arrow(buf, 540, 42, 580, 42, c_blue)
    draw_arrow(buf, 540, 30, 850, 30, c_blue)

    # Public subnet band
    fill_rect(buf, 70, 130, 1260, 180, c_public)
    rect_outline(buf, 70, 130, 1260, 180, c_public_edge, 3)
    draw_text(buf, 90, 145, "Public Subnet Route 0.0.0.0/0 To IGW", c_public_edge, 2)

    fill_rect(buf, 90, 180, 560, 110, rgb("#B7E4C7"))
    rect_outline(buf, 90, 180, 560, 110, c_public_edge, 2)
    draw_text(buf, 110, 195, "AZ 1A 10.0.1.0/24", c_public_edge, 2)
    draw_text(buf, 120, 230, "Bastion Host", c_black, 2)

    fill_rect(buf, 750, 180, 560, 110, rgb("#B7E4C7"))
    rect_outline(buf, 750, 180, 560, 110, c_public_edge, 2)
    draw_text(buf, 770, 195, "AZ 1B 10.0.2.0/24", c_public_edge, 2)
    draw_text(buf, 780, 230, "Bastion Host", c_black, 2)

    # Private app subnet band
    fill_rect(buf, 70, 340, 1260, 200, c_private)
    rect_outline(buf, 70, 340, 1260, 200, c_private_edge, 3)
    draw_text(buf, 90, 355, "Private App Subnet Route 0.0.0.0/0 To NAT", c_private_edge, 2)

    fill_rect(buf, 90, 390, 560, 130, rgb("#FFF9C4"))
    rect_outline(buf, 90, 390, 560, 130, c_private_edge, 2)
    draw_text(buf, 110, 405, "AZ 1A 10.0.11.0/24", c_private_edge, 2)
    draw_text(buf, 110, 435, "App API ECS", c_black, 2)
    draw_text(buf, 110, 465, "Order Processor", c_black, 2)

    fill_rect(buf, 750, 390, 560, 130, rgb("#FFF9C4"))
    rect_outline(buf, 750, 390, 560, 130, c_private_edge, 2)
    draw_text(buf, 770, 405, "AZ 1B 10.0.12.0/24", c_private_edge, 2)
    draw_text(buf, 770, 435, "App API ECS", c_black, 2)
    draw_text(buf, 770, 465, "Order Processor", c_black, 2)

    # Private data subnet band
    fill_rect(buf, 70, 570, 1260, 250, c_data)
    rect_outline(buf, 70, 570, 1260, 250, c_data_edge, 3)
    draw_text(buf, 90, 585, "Private Data Subnet Local Route Only No Internet", c_data_edge, 2)

    fill_rect(buf, 90, 620, 560, 180, rgb("#FFC8C8"))
    rect_outline(buf, 90, 620, 560, 180, c_data_edge, 2)
    draw_text(buf, 110, 635, "AZ 1A 10.0.21.0/24", c_data_edge, 2)
    draw_text(buf, 110, 675, "RDS Primary 10.0.21.10", c_black, 2)
    draw_text(buf, 110, 705, "Redis Primary 10.0.21.20", c_black, 2)

    fill_rect(buf, 750, 620, 560, 180, rgb("#FFC8C8"))
    rect_outline(buf, 750, 620, 560, 180, c_data_edge, 2)
    draw_text(buf, 770, 635, "AZ 1B 10.0.22.0/24", c_data_edge, 2)
    draw_text(buf, 770, 675, "RDS Standby Sync 10.0.22.10", c_black, 2)
    draw_text(buf, 770, 705, "Redis Replica 10.0.22.20", c_black, 2)

    # Flow arrows
    draw_arrow(buf, 980, 65, 980, 170, rgb("#6610F2"))
    draw_arrow(buf, 980, 305, 980, 390, c_private_edge)
    draw_arrow(buf, 980, 520, 980, 620, c_data_edge)
    draw_arrow(buf, 650, 675, 750, 675, c_data_edge)

    draw_text(buf, 420, 88, "KijaniKiosk VPC Topology", c_vpc_edge, 3)
    draw_text(buf, 980, 850, "Only Public Subnet Has Direct Internet Routing", rgb("#8B0000"), 2)

    write_png("starter-kit/network-topology.png", W, H, bytes(buf))
    print("Saved starter-kit/network-topology.png")


if __name__ == "__main__":
    main()
