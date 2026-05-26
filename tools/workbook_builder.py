#!/usr/bin/env python3
"""Build a styled HTML workbook from a Markdown study guide.

The script intentionally supports the Markdown subset used by this repository's
study guides: headings, paragraphs, bullet/numbered lists, tables, inline code,
bold text, and fenced code blocks.
"""

from __future__ import annotations

import argparse
import html
import re
import shutil
from pathlib import Path


DEFAULT_WORKBOOK_DIR = Path.home() / "Library/Mobile Documents/com~apple~CloudDocs/Workbooks/swift"


def inline(markdown: str) -> str:
    escaped = html.escape(markdown)
    escaped = re.sub(r"`([^`]+)`", r"<code>\1</code>", escaped)
    escaped = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", escaped)
    return escaped


def slugify(text: str, counts: dict[str, int]) -> str:
    base = re.sub(r"<[^>]+>", "", text).strip().lower()
    base = re.sub(r"[^0-9a-zA-Z가-힣]+", "-", base).strip("-") or "section"
    count = counts.get(base, 0)
    counts[base] = count + 1
    return base if count == 0 else f"{base}-{count + 1}"


def table_cells(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def is_table_separator(line: str) -> bool:
    stripped = line.replace("|", "").replace(":", "").replace("-", "").strip()
    return line.lstrip().startswith("|") and not stripped


def markdown_to_body(markdown: str) -> tuple[str, list[tuple[int, str, str]], str]:
    lines = markdown.splitlines()
    title = "Workbook"
    if lines and lines[0].startswith("# "):
        title = lines[0][2:].strip()

    slug_counts: dict[str, int] = {}
    headings: list[tuple[int, str, str]] = []
    blocks: list[str] = []
    paragraph: list[str] = []
    code_lines: list[str] = []
    in_code = False
    in_ul = False
    in_ol = False
    in_table = False

    def flush_para() -> None:
        nonlocal paragraph
        if paragraph:
            blocks.append(f"<p>{inline(' '.join(paragraph).strip())}</p>")
            paragraph = []

    def close_lists() -> None:
        nonlocal in_ul, in_ol
        if in_ul:
            blocks.append("</ul>")
            in_ul = False
        if in_ol:
            blocks.append("</ol>")
            in_ol = False

    def close_table() -> None:
        nonlocal in_table
        if in_table:
            blocks.append("</tbody></table></div>")
            in_table = False

    i = 0
    while i < len(lines):
        line = lines[i]

        if line.startswith("```"):
            flush_para()
            close_lists()
            close_table()
            if not in_code:
                in_code = True
                code_lines = []
            else:
                code = html.escape("\n".join(code_lines))
                blocks.append(f"<pre><code>{code}</code></pre>")
                in_code = False
            i += 1
            continue

        if in_code:
            code_lines.append(line)
            i += 1
            continue

        if not line.strip():
            flush_para()
            close_lists()
            close_table()
            i += 1
            continue

        if line.startswith("#"):
            flush_para()
            close_lists()
            close_table()
            level = len(line) - len(line.lstrip("#"))
            content = line[level:].strip()
            heading_id = slugify(content, slug_counts)
            if level == 1:
                blocks.append(f'<h1 id="{heading_id}">{inline(content)}</h1>')
            else:
                headings.append((level, content, heading_id))
                capped_level = min(level, 6)
                blocks.append(f'<h{capped_level} id="{heading_id}">{inline(content)}</h{capped_level}>')
            i += 1
            continue

        if line.lstrip().startswith("|") and "|" in line.strip()[1:]:
            flush_para()
            close_lists()
            if not in_table:
                headers = table_cells(line)
                next_line = lines[i + 1] if i + 1 < len(lines) else ""
                if is_table_separator(next_line):
                    heading_cells = "".join(f"<th>{inline(cell)}</th>" for cell in headers)
                    blocks.append(f'<div class="table-wrap"><table><thead><tr>{heading_cells}</tr></thead><tbody>')
                    in_table = True
                    i += 2
                    continue
            if in_table:
                cells = table_cells(line)
                row = "".join(f"<td>{inline(cell)}</td>" for cell in cells)
                blocks.append(f"<tr>{row}</tr>")
                i += 1
                continue

        if line.startswith("- "):
            flush_para()
            close_table()
            if in_ol:
                blocks.append("</ol>")
                in_ol = False
            if not in_ul:
                blocks.append("<ul>")
                in_ul = True
            blocks.append(f"<li>{inline(line[2:].strip())}</li>")
            i += 1
            continue

        numbered = re.match(r"^(\d+)\.\s+(.*)$", line)
        if numbered:
            flush_para()
            close_table()
            if in_ul:
                blocks.append("</ul>")
                in_ul = False
            if not in_ol:
                blocks.append("<ol>")
                in_ol = True
            blocks.append(f"<li>{inline(numbered.group(2).strip())}</li>")
            i += 1
            continue

        paragraph.append(line.strip())
        i += 1

    flush_para()
    close_lists()
    close_table()

    return "\n".join(blocks), headings, title


def workbook_html(title: str, subtitle: str, body: str, headings: list[tuple[int, str, str]], label: str) -> str:
    toc = "".join(
        f'<a href="#{heading_id}">{inline(content)}</a>'
        for level, content, heading_id in headings
        if level == 2
    )
    return f"""<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{html.escape(title)}</title>
  <style>
    :root {{
      --bg: #f7f4ed;
      --paper: #ffffff;
      --ink: #1f2428;
      --muted: #667085;
      --line: #ddd6c8;
      --accent: #0f766e;
      --code-bg: #15202b;
      --code-ink: #eef6f4;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      background: var(--bg);
      color: var(--ink);
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "Apple SD Gothic Neo", "Noto Sans KR", system-ui, sans-serif;
      line-height: 1.72;
    }}
    .page {{ max-width: 1120px; margin: 0 auto; padding: 48px 22px 80px; }}
    .hero {{
      padding: 34px 34px 30px;
      border: 1px solid var(--line);
      background: linear-gradient(135deg, #ffffff 0%, #f1fffc 48%, #fff7ed 100%);
      border-radius: 18px;
      box-shadow: 0 18px 45px rgba(31, 36, 40, 0.08);
    }}
    .eyebrow {{ margin: 0 0 8px; color: var(--accent); font-weight: 800; letter-spacing: .02em; }}
    h1 {{ margin: 0; font-size: clamp(2rem, 5vw, 3.7rem); line-height: 1.08; letter-spacing: 0; }}
    .subtitle {{ max-width: 820px; margin: 18px 0 0; color: var(--muted); font-size: 1.06rem; }}
    .toc {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(230px, 1fr)); gap: 10px; margin: 24px 0 28px; }}
    .toc a {{ display: block; padding: 10px 12px; border: 1px solid var(--line); border-radius: 10px; color: var(--accent); background: rgba(255,255,255,.72); text-decoration: none; font-weight: 700; font-size: .94rem; }}
    main {{ background: var(--paper); border: 1px solid var(--line); border-radius: 18px; padding: 34px; box-shadow: 0 18px 45px rgba(31, 36, 40, 0.06); }}
    main > h1 {{ display: none; }}
    h2 {{ margin: 48px 0 14px; font-size: 1.55rem; line-height: 1.25; border-top: 1px solid var(--line); padding-top: 28px; }}
    h2:first-of-type {{ margin-top: 6px; border-top: 0; padding-top: 0; }}
    p {{ margin: 13px 0; }}
    ul, ol {{ padding-left: 1.35rem; }}
    li {{ margin: 6px 0; }}
    code {{ font-family: "SF Mono", ui-monospace, Menlo, Consolas, monospace; background: #eef7f5; color: #0f4f49; border: 1px solid #c8e7e2; border-radius: 6px; padding: 0.12em 0.35em; font-size: 0.92em; }}
    pre {{ overflow-x: auto; background: var(--code-bg); color: var(--code-ink); border-radius: 14px; padding: 18px 20px; border: 1px solid #263849; line-height: 1.55; }}
    pre code {{ background: transparent; color: inherit; border: 0; padding: 0; }}
    .table-wrap {{ overflow-x: auto; margin: 18px 0; }}
    table {{ width: 100%; border-collapse: collapse; min-width: 620px; }}
    th, td {{ border: 1px solid var(--line); padding: 10px 12px; vertical-align: top; }}
    th {{ background: #f4fbfa; color: #164e48; text-align: left; }}
    tr:nth-child(even) td {{ background: #fbfaf7; }}
    a {{ color: var(--accent); }}
    @media (max-width: 720px) {{
      .page {{ padding: 24px 14px 56px; }}
      .hero, main {{ padding: 22px; border-radius: 14px; }}
      .toc {{ grid-template-columns: 1fr; }}
      h2 {{ font-size: 1.28rem; }}
    }}
  </style>
</head>
<body>
  <div class="page">
    <header class="hero">
      <p class="eyebrow">{html.escape(label)}</p>
      <h1>{html.escape(title)}</h1>
      <p class="subtitle">{html.escape(subtitle)}</p>
    </header>
    <nav class="toc">{toc}</nav>
    <main>
      {body}
    </main>
  </div>
</body>
</html>
"""


def validate(html_text: str, markdown: str, keywords: list[str]) -> list[str]:
    errors: list[str] = []
    h2_count = markdown.count("\n## ")
    toc_count = html_text.count('<a href="#')
    code_count = html_text.count("<pre><code>")
    if h2_count != toc_count:
        errors.append(f"TOC count mismatch: h2={h2_count}, toc={toc_count}")
    for keyword in keywords:
        if keyword and keyword not in markdown:
            errors.append(f"Missing keyword in Markdown: {keyword}")
        if keyword and keyword not in html_text:
            errors.append(f"Missing keyword in HTML: {keyword}")
    if code_count == 0:
        errors.append("No code blocks found. This may be okay, but check the guide.")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Build Desktop Organizer workbook HTML from Markdown.")
    parser.add_argument("markdown", type=Path, help="Source Markdown file.")
    parser.add_argument("--out", type=Path, help="HTML output path. Defaults to /private/tmp/<markdown-name>.html.")
    parser.add_argument("--publish", action="store_true", help="Copy the built HTML into the iCloud Workbooks/swift folder.")
    parser.add_argument("--workbook-dir", type=Path, default=DEFAULT_WORKBOOK_DIR, help="Destination folder for --publish.")
    parser.add_argument("--subtitle", default="Desktop Organizer 프로젝트 코드를 바탕으로 만든 visionOS 학습 교재입니다.")
    parser.add_argument("--label", default="Desktop Organizer Study Guide")
    parser.add_argument("--keyword", action="append", default=[], help="Keyword that must exist in both Markdown and HTML. Repeatable.")
    parser.add_argument("--strict", action="store_true", help="Exit with failure when validation warnings are found.")
    args = parser.parse_args()

    markdown_path = args.markdown.resolve()
    markdown = markdown_path.read_text(encoding="utf-8")
    body, headings, title = markdown_to_body(markdown)
    html_text = workbook_html(title, args.subtitle, body, headings, args.label)

    output_path = args.out or Path("/private/tmp") / f"{markdown_path.stem}.html"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(html_text, encoding="utf-8")

    publish_path = None
    if args.publish:
        args.workbook_dir.mkdir(parents=True, exist_ok=True)
        publish_path = args.workbook_dir / output_path.name
        shutil.copyfile(output_path, publish_path)

    errors = validate(html_text, markdown, args.keyword)
    print(f"markdown: {markdown_path}")
    print(f"html: {output_path} ({output_path.stat().st_size} bytes)")
    if publish_path:
        print(f"published: {publish_path} ({publish_path.stat().st_size} bytes)")
    print(f"h2: {markdown.count(chr(10) + '## ')}, toc: {html_text.count('<a href=\"#')}, code_blocks: {html_text.count('<pre><code>')}")

    if errors:
        for error in errors:
            print(f"warning: {error}")
        return 1 if args.strict else 0

    print("validation: ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
