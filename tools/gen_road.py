# -*- coding: utf-8 -*-
"""Генератор SVG-дороги роадмапа для вставки в Miro."""
import io

W, H = 1780, 1350
ROW_Y = [220, 620, 1020]
R = 200                      # радиус поворотов = половина зазора между рядами
ROAD_W, EDGE_W = 72, 80
X_LEFT, X_RIGHT = 160, 1490  # прямые участки
X_TAIL = 1700                # хвост третьего ряда

C = {
    "paper":   "#F4F6F2",
    "card":    "#FFFFFF",
    "rule":    "#D3D9D0",
    "ink":     "#141A18",
    "body":    "#3A4441",
    "muted":   "#58635E",
    "faint":   "#8A948E",
    "asphalt": "#2A322F",
    "edge":    "#4A544F",
    "dash":    "#E8ECE6",
    "dev":     "#1F6B5E",
    "devsoft": "#DFEAE5",
    "devink":  "#14483F",
    "mkt":     "#9A6B1E",
    "mktsoft": "#F3E8D4",
    "mktink":  "#6E4A12",
}

DEV, MKT, BOTH = "dev", "mkt", "both"

MILESTONES = [
    ("M0", "Разведка и фундамент", "1–7 сен 2026", "1 неделя", DEV, [
        "Каркас симуляции, потоки случайности",
        "Схема персонажа и предметов как данных",
        "Headless-тесты и проверка сейвов",
        "Рынок: девлог с нуля — аудитория копится годами",
    ]),
    ("M1", "Боевое ядро", "8–28 сен 2026", "3 недели", DEV, [
        "Стрельба, три врага, комната, зачистка",
        "Восемь предметов на стеке модификаторов",
        "Активные способности целиком",
        "Рынок: первые гифки",
    ]),
    ("M2", "Сеть — намеренно рано", "29 сен – 26 окт 2026", "4 недели", DEV, [
        "Авторитетный хост, лобби, подключение",
        "Предсказание движения на клиенте",
        "Позже прикручивать втрое дороже",
    ]),
    ("M3", "Забег целиком", "27 окт – 7 дек 2026", "6 недель", DEV, [
        "Зоны, органы, ломка, торговец, босс",
        "Падение и подъём, автоподъём на переходе",
        "Сейв на каждом уровне, слоты игроков",
        "Рынок: первый внешний плейтест",
    ]),
    ("M4", "Контент и выход на витрину", "8 дек 2026 – 1 фев 2027", "8 недель", BOTH, [
        "40 предметов, 12 врагов, 3 босса, зоны",
        "Все персонажи, реестр достижений",
        "Steam Direct, капсульный арт, трейлер",
        "Страница публикуется здесь, не на релизе",
    ]),
    ("M5", "Тон, арт, звук", "2 фев – 22 мар 2027", "7 недель", BOTH, [
        "Визуальная идентичность и звук",
        "Переименование пародийных персонажей",
        "Сборки Windows и macOS, нотаризация",
        "Демо-билд и Steam Playtest",
    ]),
    ("M6", "Вишлисты", "23 мар – 23 июл 2027", "4 месяца", MKT, [
        "Next Fest — один раз за всю жизнь игры",
        "Фесты ~3 раза в год: фев / июн / окт",
        "Стримеры: главный канал для рогалика",
        "Цель 12–14 тысяч с учётом региона",
    ]),
    ("M7", "Релиз", "24 июл – 23 авг 2027", "1 месяц", MKT, [
        "Ранний доступ или полный релиз",
        "Дата ставится ПОСЛЕ выбранного Next Fest",
        "Цена, региональные цены, пресс-кит",
    ]),
    ("M8", "После релиза", "с сен 2027", "постоянно", MKT, [
        "Первая неделя патчей решает отзывы",
        "Контентные обновления возвращают игроков",
        "Распродажи Steam",
    ]),
]

# позиции маркеров: ряды 1 и 3 слева направо, ряд 2 — справа налево
XS = [400, 835, 1270]
POS = []
for i in range(9):
    row = i // 3
    col = i % 3
    x = XS[col] if row != 1 else XS[2 - col]
    POS.append((x, ROW_Y[row]))


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


road_path = (
    f"M {X_LEFT} {ROW_Y[0]} H {X_RIGHT} "
    f"A {R} {R} 0 0 1 {X_RIGHT} {ROW_Y[1]} "
    f"H {X_LEFT + R} "
    f"A {R} {R} 0 0 0 {X_LEFT + R} {ROW_Y[2]} "
    f"H {X_TAIL}"
)

o = io.StringIO()
o.write(
    f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" '
    f'width="{W}" height="{H}" font-family="Helvetica Neue, Helvetica, Arial, sans-serif">\n'
)

# ---- defs ----
o.write("<defs>\n")
o.write(
    '<pattern id="checker" width="16" height="16" patternUnits="userSpaceOnUse">'
    '<rect width="16" height="16" fill="#F2F4F1"/>'
    '<rect width="8" height="8" fill="#121816"/>'
    '<rect x="8" y="8" width="8" height="8" fill="#121816"/>'
    "</pattern>\n"
)
o.write(
    f'<linearGradient id="fade" x1="0" x2="1">'
    f'<stop offset="0" stop-color="{C["paper"]}" stop-opacity="0"/>'
    f'<stop offset="1" stop-color="{C["paper"]}" stop-opacity="1"/>'
    "</linearGradient>\n"
)
o.write("</defs>\n")

o.write(f'<rect width="{W}" height="{H}" rx="6" fill="{C["paper"]}"/>\n')

# ---- заголовок ----
o.write(
    f'<text x="60" y="72" font-size="42" font-weight="700" fill="{C["ink"]}" '
    f'letter-spacing="-1">Ломка — производственный роадмап</text>\n'
)
o.write(
    f'<text x="60" y="104" font-size="16" fill="{C["muted"]}">'
    f"Кооперативный рогалик на Godot 4.7.2 · от каркаса до месяца после релиза в Steam</text>\n"
)
o.write(
    f'<text x="60" y="136" font-size="12.5" fill="{C["faint"]}" '
    f'font-family="Menlo, Consolas, monospace" letter-spacing="1.4">'
    f"СТАРТ 1 СЕНТЯБРЯ 2026 · ОРИЕНТИР РЕЛИЗА — КОНЕЦ АВГУСТА 2027 · ОЦЕНКА ДЛЯ РАБОТЫ ВЕЧЕРАМИ, ОДИН ЧЕЛОВЕК</text>\n"
)

# ---- легенда треков ----
lx, ly = 1180, 48
o.write(f'<g transform="translate({lx},{ly})">\n')
for i, (label, fill, ink, note) in enumerate([
    ("РАЗРАБОТКА", C["dev"], "#FFFFFF", "M0 → M5"),
    ("РЫНОК", C["mkt"], "#FFFFFF", "M4 → M8"),
]):
    y = i * 34
    o.write(f'<rect x="0" y="{y}" width="150" height="24" rx="3" fill="{fill}"/>\n')
    o.write(
        f'<text x="12" y="{y + 16.5}" font-size="11.5" fill="{ink}" '
        f'font-family="Menlo, Consolas, monospace" letter-spacing="1.2">{label}</text>\n'
    )
    o.write(
        f'<text x="164" y="{y + 16.5}" font-size="12.5" fill="{C["muted"]}" '
        f'font-family="Menlo, Consolas, monospace">{note}</text>\n'
    )
o.write(
    f'<text x="0" y="94" font-size="13" fill="{C["muted"]}">Треки идут параллельно и пересекаются</text>\n'
)
o.write(
    f'<text x="0" y="112" font-size="13" fill="{C["muted"]}">на M4–M5 — самый загруженный отрезок.</text>\n'
)
o.write("</g>\n")

# ---- дорога ----
o.write(
    f'<path d="{road_path}" fill="none" stroke="{C["edge"]}" '
    f'stroke-width="{EDGE_W}" stroke-linecap="round"/>\n'
)
o.write(
    f'<path d="{road_path}" fill="none" stroke="{C["asphalt"]}" '
    f'stroke-width="{ROAD_W}" stroke-linecap="round"/>\n'
)
o.write(
    f'<path d="{road_path}" fill="none" stroke="{C["dash"]}" stroke-width="4" '
    f'stroke-dasharray="26 30" stroke-linecap="butt" opacity="0.85"/>\n'
)

# финишная лента перед M7
fx, fy = POS[7][0] - 74, POS[7][1]
o.write(
    f'<rect x="{fx}" y="{fy - ROAD_W / 2}" width="22" height="{ROAD_W}" fill="url(#checker)"/>\n'
)

# хвост дороги растворяется — игра продолжается после M8
o.write(
    f'<rect x="{X_TAIL - 210}" y="{ROW_Y[2] - EDGE_W / 2 - 2}" width="216" '
    f'height="{EDGE_W + 4}" fill="url(#fade)"/>\n'
)

# ---- вехи ----
CARD_W = 400
for i, (code, title, dates, dur, track, bullets) in enumerate(MILESTONES):
    mx, my = POS[i]

    # маркер на дороге
    o.write(
        f'<circle cx="{mx}" cy="{my}" r="31" fill="{C["paper"]}" '
        f'stroke="{C["dev"] if track != MKT else C["mkt"]}" stroke-width="3"/>\n'
    )
    o.write(
        f'<text x="{mx}" y="{my + 6}" font-size="19" font-weight="700" text-anchor="middle" '
        f'fill="{C["devink"] if track != MKT else C["mktink"]}" '
        f'font-family="Menlo, Consolas, monospace">{code}</text>\n'
    )

    # карточка под дорогой
    cx, cy = mx - CARD_W / 2, my + 58
    ch = 96 + len(bullets) * 26
    o.write(f'<line x1="{mx}" y1="{my + 31}" x2="{mx}" y2="{cy}" stroke="{C["rule"]}" stroke-width="2"/>\n')
    o.write(
        f'<rect x="{cx}" y="{cy}" width="{CARD_W}" height="{ch}" rx="4" '
        f'fill="{C["card"]}" stroke="{C["rule"]}"/>\n'
    )
    # цветная полоса трека слева
    if track == BOTH:
        o.write(f'<rect x="{cx}" y="{cy}" width="4" height="{ch / 2}" fill="{C["dev"]}"/>\n')
        o.write(f'<rect x="{cx}" y="{cy + ch / 2}" width="4" height="{ch / 2}" fill="{C["mkt"]}"/>\n')
    else:
        o.write(
            f'<rect x="{cx}" y="{cy}" width="4" height="{ch}" '
            f'fill="{C["dev"] if track == DEV else C["mkt"]}"/>\n'
        )

    tx = cx + 20
    o.write(
        f'<text x="{tx}" y="{cy + 34}" font-size="20" font-weight="700" '
        f'fill="{C["ink"]}">{esc(title)}</text>\n'
    )
    o.write(
        f'<text x="{tx}" y="{cy + 58}" font-size="12.5" fill="{C["ink"]}" font-weight="600" '
        f'font-family="Menlo, Consolas, monospace">{esc(dates)}</text>\n'
    )
    o.write(
        f'<text x="{cx + CARD_W - 20}" y="{cy + 58}" font-size="11.5" fill="{C["faint"]}" '
        f'text-anchor="end" font-family="Menlo, Consolas, monospace">{esc(dur)}</text>\n'
    )
    o.write(f'<line x1="{tx}" y1="{cy + 74}" x2="{cx + CARD_W - 20}" y2="{cy + 74}" stroke="{C["rule"]}"/>\n')

    for j, b in enumerate(bullets):
        by = cy + 100 + j * 26
        is_mkt = b.startswith("Рынок:")
        dot = C["mkt"] if (is_mkt or track == MKT) else C["dev"]
        o.write(f'<circle cx="{tx + 3}" cy="{by - 5}" r="3" fill="{dot}"/>\n')
        o.write(
            f'<text x="{tx + 16}" y="{by}" font-size="14.5" fill="{C["body"]}">{esc(b)}</text>\n'
        )

o.write(
    f'<text x="60" y="{H - 28}" font-size="12.5" fill="{C["faint"]}" '
    f'font-family="Menlo, Consolas, monospace" letter-spacing="1.2">'
    f"ДАТЫ — ПОРЯДОК И ЗАВИСИМОСТИ, А НЕ ОБЯЗАТЕЛЬСТВА. КРИТЕРИИ ВЫХОДА И РИСКИ — В ПОЛНОМ ДОКУМЕНТЕ ПЛАНА</text>\n"
)
o.write("</svg>\n")

path = "/private/tmp/claude-501/-Users-egor-Desktop/30a5014b-8ff6-4927-be69-3756c5d38c9e/scratchpad/lomka-roadmap.svg"
io.open(path, "w", encoding="utf-8").write(o.getvalue())
print("готово:", path)
