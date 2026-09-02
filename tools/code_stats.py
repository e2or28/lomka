#!/usr/bin/env python3
"""Сколько в проекте кода и где он лежит.

Кладёт на рабочий стол HTML-страницу: строки по каталогам, доля комментариев,
самые крупные файлы и рост по коммитам. Открывается двойным кликом, ничего
не требует — ни сервера, ни интернета.

    python3 tools/code_stats.py            # собрать и положить на десктоп
    python3 tools/code_stats.py --print    # то же в терминал
    python3 tools/code_stats.py --out ПУТЬ

Почему отдельный инструмент, а не строчка в README: число строк живёт своей
жизнью и устаревает в тот же день. Смотреть на него имеет смысл, когда
хочешь понять, куда разрастается проект, — а для этого нужна и разбивка по
каталогам, и динамика, а не одна цифра.

В игру не входит, игра о нём не знает (docs/LEVEL_EDITOR.md, правило
автономности).
"""

import argparse
import html
import json
import subprocess
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path

# Что считаем и как называем. Порядок задаёт порядок в таблице.
KINDS = [
    ("GDScript", {".gd"}),
    ("Python", {".py"}),
    ("Shell", {".sh"}),
    ("Документы", {".md"}),
    ("Данные", {".json", ".godot", ".tscn", ".cfg"}),
]

# Каталоги верхнего уровня, которые вообще смотрим.
ROOTS = ["sim", "game", "tools", "tests", "docs", "art", "assets"]

SKIP_DIRS = {".git", ".godot", "export", "build", "__pycache__"}

# Комментарии в этих языках начинаются одинаково, поэтому одна проверка.
COMMENT_PREFIXES = ("#", "//", ";")


def kind_of(path: Path) -> str:
    for name, suffixes in KINDS:
        if path.suffix in suffixes:
            return name
    return ""


def measure(path: Path) -> dict:
    """Строки файла: всего, кода, комментариев, пустых."""
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").split("\n")
    except OSError:
        return {"total": 0, "code": 0, "comment": 0, "blank": 0}
    if lines and lines[-1] == "":
        lines.pop()

    counts = {"total": len(lines), "code": 0, "comment": 0, "blank": 0}
    for line in lines:
        stripped = line.strip()
        if not stripped:
            counts["blank"] += 1
        elif stripped.startswith(COMMENT_PREFIXES):
            counts["comment"] += 1
        else:
            counts["code"] += 1
    return counts


def walk(root: Path):
    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        if kind_of(path):
            yield path


def collect(project: Path) -> dict:
    by_dir = defaultdict(lambda: defaultdict(int))
    by_kind = defaultdict(lambda: defaultdict(int))
    files = []

    targets = [project / name for name in ROOTS if (project / name).is_dir()]
    targets.append(project)  # файлы в корне

    seen = set()
    for target in targets:
        paths = walk(target) if target != project else (
            p for p in sorted(project.glob("*")) if p.is_file() and kind_of(p))
        for path in paths:
            if path in seen:
                continue
            seen.add(path)
            counts = measure(path)
            relative = path.relative_to(project)
            group = relative.parts[0] if len(relative.parts) > 1 else "."
            kind = kind_of(path)
            for key, value in counts.items():
                by_dir[group][key] += value
                by_kind[kind][key] += value
            by_dir[group]["files"] += 1
            by_kind[kind]["files"] += 1
            files.append({"path": str(relative), "kind": kind, **counts})

    files.sort(key=lambda f: -f["total"])
    return {"by_dir": by_dir, "by_kind": by_kind, "files": files}


CACHE = Path(".cache") / "code_stats.json"


def _blob_lines(project: Path, refs: list) -> dict:
    """Сколько строк в каждом объекте. Одним процессом на весь коммит.

    Раньше здесь был git show на каждый файл: тридцать коммитов по восемьдесят
    файлов — это две с половиной тысячи запусков git и двадцать шесть секунд.
    git cat-file --batch читает всё за один заход.
    """
    if not refs:
        return {}
    proc = subprocess.run(
        ["git", "-C", str(project), "cat-file", "--batch"],
        input="\n".join(refs).encode() + b"\n",
        capture_output=True)

    out = proc.stdout
    result = {}
    offset = 0
    for ref in refs:
        newline = out.find(b"\n", offset)
        if newline < 0:
            break
        header = out[offset:newline].split(b" ")
        if len(header) < 3:
            # Объекта нет — git отвечает "<ref> missing"
            offset = newline + 1
            result[ref] = 0
            continue
        size = int(header[2])
        body = out[newline + 1:newline + 1 + size]
        result[ref] = body.count(b"\n")
        offset = newline + 1 + size + 1
    return result


def history(project: Path, limit: int = 60) -> list:
    """Сколько строк было на каждом коммите.

    Считается по дереву коммита, а не по диффам: так число совпадает с тем,
    что даёт обход файлов, и не копит ошибку от переименований.

    Готовые коммиты кладутся в кеш: прошлое не меняется, пересчитывать его
    при каждом запуске незачем. Без кеша дашборд нельзя было бы вешать на
    хук — он бы стоил секунд, а не мгновения.
    """
    try:
        log = subprocess.run(
            ["git", "-C", str(project), "log", "--format=%h\t%at\t%s",
             "--reverse", f"-{limit}"],
            capture_output=True, text=True, check=True).stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return []
    if not log:
        return []

    cache_path = project / CACHE
    cached = {}
    if cache_path.exists():
        try:
            cached = json.loads(cache_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            cached = {}

    points = []
    fresh = 0
    for line in log.split("\n"):
        sha, stamp, subject = line.split("\t", 2)
        if sha in cached:
            points.append(cached[sha])
            continue

        listing = subprocess.run(
            ["git", "-C", str(project), "ls-tree", "-r", "--name-only", sha],
            capture_output=True, text=True).stdout.split("\n")

        names = [n for n in listing
                 if n and kind_of(Path(n))
                 and not any(part in SKIP_DIRS for part in Path(n).parts)]
        counts = _blob_lines(project, [f"{sha}:{n}" for n in names])

        totals = defaultdict(int)
        for name in names:
            count = counts.get(f"{sha}:{name}", 0)
            group = Path(name).parts[0] if len(Path(name).parts) > 1 else "."
            totals[group] += count
            totals["всего"] += count

        point = {
            "sha": sha,
            "date": datetime.fromtimestamp(int(stamp)).strftime("%d.%m %H:%M"),
            "subject": subject,
            "totals": dict(totals),
        }
        cached[sha] = point
        points.append(point)
        fresh += 1

    if fresh:
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        cache_path.write_text(json.dumps(cached, ensure_ascii=False),
                              encoding="utf-8")
    return points


def bar(value: int, peak: int, width: int = 28) -> str:
    filled = round(width * value / peak) if peak else 0
    return "█" * filled + "·" * (width - filled)


def print_report(data: dict) -> None:
    print("\nСТРОКИ ПО КАТАЛОГАМ\n")
    rows = sorted(data["by_dir"].items(), key=lambda kv: -kv[1]["total"])
    peak = max((r[1]["total"] for r in rows), default=1)
    print(f"  {'каталог':<10} {'файлов':>7} {'строк':>7} {'кода':>7} "
          f"{'коммент':>8} {'пустых':>7}")
    for name, counts in rows:
        print(f"  {name:<10} {counts['files']:>7} {counts['total']:>7} "
              f"{counts['code']:>7} {counts['comment']:>8} {counts['blank']:>7}"
              f"  {bar(counts['total'], peak)}")

    total = sum(c["total"] for c in data["by_dir"].values())
    code = sum(c["code"] for c in data["by_dir"].values())
    comment = sum(c["comment"] for c in data["by_dir"].values())
    files = sum(c["files"] for c in data["by_dir"].values())
    print(f"\n  ВСЕГО: {total} строк в {files} файлах "
          f"({code} кода, {comment} комментариев, "
          f"{comment / max(code + comment, 1):.0%} комментариев)\n")


def render(data: dict, points: list, project: Path) -> str:
    rows = sorted(data["by_dir"].items(), key=lambda kv: -kv[1]["total"])
    peak = max((r[1]["total"] for r in rows), default=1)
    total = sum(c["total"] for c in data["by_dir"].values())
    code = sum(c["code"] for c in data["by_dir"].values())
    comment = sum(c["comment"] for c in data["by_dir"].values())
    blank = sum(c["blank"] for c in data["by_dir"].values())
    files = sum(c["files"] for c in data["by_dir"].values())

    # Что за каталог, человеческими словами
    notes = {
        "sim": "симуляция: считает игру, о картинке не знает",
        "game": "представление: стенд и отрисовка",
        "tests": "проверки без окна",
        "tools": "генераторы и скрипты, в игру не входят",
        "docs": "план, решения, роадмап",
        "art": "спрайты",
        "assets": "готовые ассеты",
        ".": "файлы в корне",
    }

    def dir_rows() -> str:
        out = []
        for name, counts in rows:
            share = counts["total"] / max(total, 1)
            width = 100 * counts["total"] / peak
            out.append(f"""
      <tr>
        <td class="name">{html.escape(name)}<span class="note">{html.escape(notes.get(name, ""))}</span></td>
        <td class="num">{counts['files']}</td>
        <td class="num strong">{counts['total']}</td>
        <td class="num">{counts['code']}</td>
        <td class="num dim">{counts['comment']}</td>
        <td class="num dim">{counts['blank']}</td>
        <td class="barcell"><span class="bar" style="width:{width:.1f}%"></span><span class="share">{share:.0%}</span></td>
      </tr>""")
        return "".join(out)

    def kind_rows() -> str:
        out = []
        kinds = sorted(data["by_kind"].items(), key=lambda kv: -kv[1]["total"])
        kpeak = max((k[1]["total"] for k in kinds), default=1)
        for name, counts in kinds:
            width = 100 * counts["total"] / kpeak
            out.append(f"""
      <tr>
        <td class="name">{html.escape(name)}</td>
        <td class="num">{counts['files']}</td>
        <td class="num strong">{counts['total']}</td>
        <td class="barcell"><span class="bar alt" style="width:{width:.1f}%"></span></td>
      </tr>""")
        return "".join(out)

    def file_rows() -> str:
        out = []
        for entry in data["files"][:20]:
            out.append(f"""
      <tr>
        <td class="path">{html.escape(entry['path'])}</td>
        <td class="num dim">{html.escape(entry['kind'])}</td>
        <td class="num strong">{entry['total']}</td>
        <td class="num">{entry['code']}</td>
        <td class="num dim">{entry['comment']}</td>
      </tr>""")
        return "".join(out)

    def growth() -> str:
        if not points:
            return '<p class="empty">История недоступна — это не git-репозиторий.</p>'
        top = max(p["totals"].get("всего", 0) for p in points) or 1
        bars = []
        for point in points:
            value = point["totals"].get("всего", 0)
            height = 100 * value / top
            title = f"{point['date']} · {point['sha']} · {value} строк\n{point['subject']}"
            bars.append(f'<div class="col" title="{html.escape(title)}">'
                        f'<span style="height:{height:.1f}%"></span></div>')
        first = points[0]["totals"].get("всего", 0)
        last = points[-1]["totals"].get("всего", 0)
        return f"""
    <div class="chart">{''.join(bars)}</div>
    <p class="caption">{len(points)} коммитов · от {first} до {last} строк ·
       наведи на столбик, чтобы увидеть коммит</p>"""

    stamp = datetime.now().strftime("%d.%m.%Y %H:%M")
    test_lines = data["by_dir"].get("tests", {}).get("total", 0)
    product = data["by_dir"].get("sim", {}).get("total", 0) + \
        data["by_dir"].get("game", {}).get("total", 0)
    ratio = f"{test_lines / product:.0%}" if product else "—"

    return f"""<!doctype html>
<html lang="ru"><head><meta charset="utf-8">
<title>Ломка — код</title>
<style>
  :root {{
    --bg: #16161a; --panel: #1e1e24; --line: #2c2c34;
    --text: #e6e6ea; --dim: #8b8b96; --accent: #7fc8a9; --alt: #c8a97f;
  }}
  * {{ box-sizing: border-box; }}
  body {{
    margin: 0; padding: 32px 28px 64px;
    background: var(--bg); color: var(--text);
    font: 14px/1.5 ui-monospace, SFMono-Regular, Menlo, monospace;
  }}
  h1 {{ font-size: 20px; margin: 0 0 4px; font-weight: 600; }}
  .stamp {{ color: var(--dim); font-size: 12px; margin-bottom: 28px; }}
  h2 {{ font-size: 13px; text-transform: uppercase; letter-spacing: .08em;
        color: var(--dim); margin: 32px 0 10px; font-weight: 600; }}
  .cards {{ display: flex; gap: 12px; flex-wrap: wrap; margin-bottom: 8px; }}
  .card {{ background: var(--panel); border: 1px solid var(--line);
           border-radius: 8px; padding: 14px 18px; min-width: 130px; }}
  .card b {{ display: block; font-size: 26px; font-weight: 600; }}
  .card span {{ color: var(--dim); font-size: 12px; }}
  table {{ width: 100%; border-collapse: collapse; background: var(--panel);
           border: 1px solid var(--line); border-radius: 8px; overflow: hidden; }}
  th {{ text-align: right; font-weight: 600; color: var(--dim); font-size: 12px;
        padding: 10px 12px; border-bottom: 1px solid var(--line); }}
  th:first-child {{ text-align: left; }}
  td {{ padding: 9px 12px; border-bottom: 1px solid var(--line); }}
  tr:last-child td {{ border-bottom: none; }}
  .name {{ font-weight: 600; }}
  .note {{ display: block; color: var(--dim); font-weight: 400; font-size: 12px; }}
  .path {{ color: var(--text); }}
  .num {{ text-align: right; font-variant-numeric: tabular-nums; }}
  .strong {{ font-weight: 600; }}
  .dim {{ color: var(--dim); }}
  .barcell {{ width: 34%; position: relative; }}
  .bar {{ display: inline-block; height: 8px; border-radius: 4px;
          background: var(--accent); vertical-align: middle; }}
  .bar.alt {{ background: var(--alt); }}
  .share {{ color: var(--dim); font-size: 12px; margin-left: 8px; }}
  .chart {{ display: flex; align-items: flex-end; gap: 3px; height: 150px;
            background: var(--panel); border: 1px solid var(--line);
            border-radius: 8px; padding: 12px; }}
  .col {{ flex: 1; height: 100%; display: flex; align-items: flex-end; }}
  .col span {{ width: 100%; background: var(--accent); border-radius: 2px 2px 0 0;
               opacity: .85; }}
  .col:hover span {{ opacity: 1; background: #a5e0c6; }}
  .caption, .empty {{ color: var(--dim); font-size: 12px; margin-top: 10px; }}
  footer {{ margin-top: 40px; color: var(--dim); font-size: 12px; }}
  code {{ background: var(--panel); padding: 2px 6px; border-radius: 4px; }}
</style></head><body>

<h1>Ломка — сколько кода</h1>
<div class="stamp">{stamp} · {html.escape(str(project))}</div>

<div class="cards">
  <div class="card"><b>{total}</b><span>строк всего</span></div>
  <div class="card"><b>{code}</b><span>кода</span></div>
  <div class="card"><b>{comment}</b><span>комментариев</span></div>
  <div class="card"><b>{blank}</b><span>пустых</span></div>
  <div class="card"><b>{files}</b><span>файлов</span></div>
  <div class="card"><b>{ratio}</b><span>тестов к коду</span></div>
</div>

<h2>По каталогам</h2>
<table>
  <tr><th>каталог</th><th>файлов</th><th>строк</th><th>кода</th>
      <th>коммент.</th><th>пустых</th><th></th></tr>
  {dir_rows()}
</table>

<h2>По языкам</h2>
<table>
  <tr><th>язык</th><th>файлов</th><th>строк</th><th></th></tr>
  {kind_rows()}
</table>

<h2>Рост по коммитам</h2>
{growth()}

<h2>Самые крупные файлы</h2>
<table>
  <tr><th>файл</th><th>язык</th><th>строк</th><th>кода</th><th>коммент.</th></tr>
  {file_rows()}
</table>

<footer>Пересобрать: <code>tools/code_stats.sh</code></footer>
</body></html>"""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", type=Path, default=None)
    parser.add_argument("--print", dest="to_terminal", action="store_true")
    parser.add_argument("--no-history", action="store_true")
    args = parser.parse_args()

    project = Path(__file__).resolve().parent.parent
    data = collect(project)

    if args.to_terminal:
        print_report(data)
        return 0

    points = [] if args.no_history else history(project)
    target = args.out or Path.home() / "Desktop" / "Ломка — код.html"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(render(data, points, project), encoding="utf-8")

    total = sum(c["total"] for c in data["by_dir"].values())
    files = sum(c["files"] for c in data["by_dir"].values())
    print(f"{target}")
    print(f"  {total} строк в {files} файлах, {len(points)} коммитов в истории")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
