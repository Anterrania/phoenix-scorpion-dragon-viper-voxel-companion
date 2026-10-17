#!/usr/bin/env python3
"""Build-time seed export for the in-app Viper OS admin (tracker / wiki / repository timeline).

Writes (all read-only seeds, shipped under res://data/admin/):
  repo_log.json     - git log (sha, author, date, subject) -> read-only "Repository" timeline
  wiki_seed.json    - docs/*.md + docs/modules/*.md -> Trac-style wiki pages (WikiName from filename)
  tickets_seed.json - docs/TASK_TRACKER.csv -> tickets

Run from the repo root before exporting:  python3 tools/export_admin_seed.py
No personal data: only commit subjects, author display names and docs already in the repo.
"""
import csv, json, os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "admin")
MAX_COMMITS = 400
MAX_PAGE = 24000

def clip_page(text: str, source: str) -> str:
    """Cap a page at MAX_PAGE on a line boundary and say so (2026-10-17 audit: pages used to stop mid-sentence)."""
    if len(text) <= MAX_PAGE: return text
    cut = text.rfind("\n", 0, MAX_PAGE)
    cut = cut if cut > 0 else MAX_PAGE
    return text[:cut].rstrip() + f"\n\n(Shortened in the app at {MAX_PAGE // 1000} KB. The full page is {source} in the repo.)\n"

def wiki_name(fn: str) -> str:
    base = os.path.splitext(os.path.basename(fn))[0]
    return "".join(p.capitalize() for p in re.split(r"[_\-\s]+", base.lower()) if p)

def repo_log():
    fmt = "%h%x1f%an%x1f%aI%x1f%s"
    try:
        out = subprocess.run(["git", "-C", ROOT, "log", f"-n{MAX_COMMITS}", f"--format={fmt}", "--first-parent", "HEAD"],
                             capture_output=True, text=True, check=True).stdout
    except Exception as e:  # not a git checkout (e.g. CI tarball)
        print("git log unavailable:", e, file=sys.stderr)
        return []
    rows = []
    for line in out.splitlines():
        sha, author, date, subject = (line.split("\x1f") + ["", "", "", ""])[:4]
        rows.append({"sha": sha, "author": author, "date": date, "subject": subject[:200]})
    return rows

def wiki_seed():
    pages = {}
    for d in ["docs", os.path.join("docs", "modules"), os.path.join("docs", "wiki")]:
        full = os.path.join(ROOT, d)
        if not os.path.isdir(full): continue
        for fn in sorted(os.listdir(full)):
            if fn.endswith(".md"):
                with open(os.path.join(full, fn), encoding="utf-8", errors="replace") as f:
                    text = f.read()
                name = wiki_name(fn)
                if name in pages: name += "Guide"   # docs/wiki page shares a name with a design doc
                pages[name] = {"text": clip_page(text, f"{d}/{fn}"), "source": f"{d}/{fn}", "truncated": len(text) > MAX_PAGE}
    pages.setdefault("WikiStart", {"text": "= Viper OS Wiki =\n\nStart here. Pages: " + ", ".join(sorted(pages)) + "\n", "source": "generated", "truncated": False})
    return pages

def tickets_seed():
    path = os.path.join(ROOT, "docs", "TASK_TRACKER.csv")
    tickets = []
    if not os.path.exists(path): return tickets
    status_map = {"done": "closed", "done_untested": "closed", "done_headless": "closed", "in_progress": "accepted", "blocked": "assigned", "todo": "new"}
    with open(path, encoding="utf-8") as f:
        for i, row in enumerate(csv.DictReader(f), start=1):
            st = status_map.get((row.get("status") or "todo").strip(), "new")
            tickets.append({"id": i, "type": "task", "summary": (row.get("task") or "").strip()[:200],
                            "status": st, "resolution": "fixed" if st == "closed" else "",
                            "priority": (row.get("priority") or "P2").strip(), "component": "general",
                            "milestone": (row.get("milestone") or "").strip(), "owner": "",
                            "source": "docs/TASK_TRACKER.csv"})
    return tickets

def main():
    os.makedirs(OUT, exist_ok=True)
    for name, data in [("repo_log.json", repo_log()), ("wiki_seed.json", wiki_seed()), ("tickets_seed.json", tickets_seed())]:
        with open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
            json.dump(data, f, indent=1, ensure_ascii=False)
        print(name, len(data))

if __name__ == "__main__":
    main()
