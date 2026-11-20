"""Build architecture.html from current.md and ideal.md.

Run from this folder:  python build_page.py
Each ```mermaid block becomes its own diagram card, titled by the nearest
heading above it. Prose sections are rendered with a tiny Markdown subset.
"""
import html
import re
from pathlib import Path

HERE = Path(__file__).parent


def inline(t):
    t = html.escape(t)
    t = re.sub(r"`([^`]+)`", r"<code>\1</code>", t)
    t = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", t)
    return t


def md_to_html(md):
    """Headings, paragraphs, ordered lists, tables, code fences, mermaid."""
    out, lines, i = [], md.split("\n"), 0
    while i < len(lines):
        l = lines[i]
        if l.startswith("```"):
            lang = l[3:].strip()
            j = i + 1
            while not lines[j].startswith("```"):
                j += 1
            body = "\n".join(lines[i + 1:j])
            if lang == "mermaid":
                out.append(f'<div class="diagram"><pre class="mermaid">{html.escape(body)}</pre></div>')
            else:
                out.append(f'<pre class="layout">{html.escape(body)}</pre>')
            i = j + 1
        elif l.startswith("#"):
            n = len(l) - len(l.lstrip("#"))
            lvl = min(n + 1, 4)  # '#' -> h2, '##' -> h3, '###' -> h4
            out.append(f"<h{lvl}>{inline(l[n:].strip())}</h{lvl}>")
            i += 1
        elif l.startswith("|"):
            rows = []
            while i < len(lines) and lines[i].startswith("|"):
                if not set(lines[i]) <= set("|-: "):
                    rows.append([c.strip() for c in lines[i].strip().strip("|").split("|")])
                i += 1
            h = "<div class='tw'><table><thead><tr>" + "".join(f"<th>{inline(c)}</th>" for c in rows[0]) + "</tr></thead><tbody>"
            h += "".join("<tr>" + "".join(f"<td>{inline(c)}</td>" for c in r) + "</tr>" for r in rows[1:])
            out.append(h + "</tbody></table></div>")
        elif re.match(r"\s*- ", l):
            # bullet block, nested by indent (2 spaces per level)
            items = []  # (level, text)
            while i < len(lines) and lines[i].strip():
                m = re.match(r"(\s*)- (.*)", lines[i])
                if m:
                    items.append([len(m.group(1)) // 2, m.group(2)])
                else:
                    items[-1][1] += " " + lines[i].strip()
                i += 1
            h, depth = "", -1
            for lvl, txt in items:
                while depth < lvl:
                    h += "<ul>"
                    depth += 1
                while depth > lvl:
                    h += "</li></ul>"
                    depth -= 1
                if h.endswith("<ul>"):
                    h += f"<li>{inline(txt)}"
                else:
                    h += f"</li><li>{inline(txt)}"
            h += "</li></ul>" * (depth + 1)
            out.append(h)
        elif re.match(r"\d+\. ", l):
            items = []
            while i < len(lines) and lines[i].strip():
                if re.match(r"\d+\. ", lines[i]):
                    items.append(re.sub(r"^\d+\.\s*", "", lines[i]))
                else:
                    items[-1] += " " + lines[i].strip()
                i += 1
            out.append("<ol>" + "".join(f"<li>{inline(x)}</li>" for x in items) + "</ol>")
        elif l.strip():
            para = []
            while i < len(lines) and lines[i].strip() and not lines[i].startswith(("#", "```", "|")):
                para.append(lines[i].strip())
                i += 1
            out.append(f"<p>{inline(' '.join(para))}</p>")
        else:
            i += 1
    return "\n".join(out)


CSS = """
/* Layout: one reading column; each diagram is its own card at full column width */
:root{--bg:#fbfbf8;--fg:#1d2228;--muted:#5d6670;--line:#dde0e3;--panel:#f1f3f2;--accent:#2f6f5e;--diagram:#ffffff;
--display:'Fraunces',Georgia,serif;--body:'IBM Plex Sans',system-ui,sans-serif;--mono:'IBM Plex Mono',ui-monospace,monospace}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--bg:#15191c;--fg:#e4e7e9;--muted:#9aa3ab;--line:#2c3338;--panel:#1d2327;--accent:#7cc4ad;color-scheme:dark}}
:root[data-theme="dark"]{--bg:#15191c;--fg:#e4e7e9;--muted:#9aa3ab;--line:#2c3338;--panel:#1d2327;--accent:#7cc4ad;color-scheme:dark}
body{background:var(--bg);color:var(--fg);font:15px/1.6 var(--body);padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px));padding-block:32px 64px}
main{max-width:1000px;margin:0 auto}
nav{display:flex;flex-wrap:wrap;gap:6px 14px;font:500 .8rem var(--mono);margin:12px 0 8px}
nav a{color:var(--accent)}
h1{font:600 2rem/1.15 var(--display);margin:0 0 8px;text-wrap:balance}
h2{font:600 1.5rem/1.2 var(--display);margin:48px 0 8px;padding-top:16px;border-top:2px solid var(--line);text-wrap:balance}
h3{font:600 1.15rem/1.25 var(--display);margin:32px 0 8px}
h4{font:600 1rem/1.3 var(--body);margin:24px 0 6px}
p,ol,ul{margin:0 0 10px;max-width:72ch}
ul ul{margin:4px 0 0}
.eyebrow{font:500 .75rem var(--mono);letter-spacing:.08em;text-transform:uppercase;color:var(--accent)}
code,pre.layout{font-family:var(--mono);font-size:.85em}
code{background:var(--panel);padding:1px 4px;border-radius:3px}
.diagram{overflow-x:auto;border:1px solid var(--line);border-radius:6px;background:var(--diagram);padding:12px;margin:8px 0 16px}
.diagram pre{margin:0}
pre.layout{overflow-x:auto;background:var(--panel);padding:14px;border-radius:6px;line-height:1.45}
.tw{overflow-x:auto}
table{border-collapse:collapse;width:100%;font-size:.88rem}
th,td{text-align:left;vertical-align:top;padding:7px 10px;border-bottom:1px solid var(--line)}
th{font-weight:600;color:var(--muted)}
"""


def build():
    cur = (HERE / "current.md").read_text(encoding="utf-8")
    ide = (HERE / "ideal.md").read_text(encoding="utf-8")
    plan = (HERE / "implementation-plan.md").read_text(encoding="utf-8")
    page = f"""<title>CombResearch Pipeline Map</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;600&family=IBM+Plex+Mono:wght@400;500&family=Fraunces:opsz,wght@9..144,600&display=swap">
<style>{CSS}</style>
<main>
<div class="eyebrow">Repo map · commit b4d4b20 · 2026-11-20</div>
<h1>CombResearch Pipeline Map</h1>
<p>How every tracked file connects today, then a target layout that lets another researcher clone the repo and rebuild the data and figures. The per-file inventory is in <code>docs/architecture/inventory.md</code>.</p>
<nav><a href="#today">Today</a><a href="#target">Target</a><a href="#plan">Implementation plan</a></nav>
<section id="today">{md_to_html(cur)}</section>
<section id="target">{md_to_html(ide)}</section>
<section id="plan">{md_to_html(plan)}</section>
</main>"""
    (HERE / "architecture.html").write_text(page, encoding="utf-8")
    print("wrote architecture.html,", page.count('class="mermaid"'), "diagrams")


if __name__ == "__main__":
    build()
