#!/usr/bin/env python3
"""
Extract LuaLS-annotated doc blocks from iter8.lua → docs/api.md.

Run from the repo root:
    python docs/extract.py
"""

import re
from pathlib import Path

SRC = Path(__file__).parent.parent / "iter8.lua"
OUT = Path(__file__).parent / "api.md"


# ── helpers ──────────────────────────────────────────────────────────────────

def strip_prefix(line: str) -> str:
    """'---text' → 'text',  '--->text' → '>text' (preserves alert '>')."""
    if line.startswith("--->"):
        return line[3:]
    if line.startswith("---"):
        return line[3:]
    return line


def to_anchor(name: str) -> str:
    """'Iter8.range' → 'iter8-range', 'iterator:map' → 'iterator-map'."""
    s = name.lower().replace(".", "-").replace(":", "-").replace("_", "-")
    return re.sub(r"[^a-z0-9-]", "", s)


def overload_sig(name: str, ov: str) -> str:
    """'fun(x: int): T' → 'name(x: int) → T'."""
    m = re.match(r"^fun(\(.*\)):\s*(.+)$", ov)
    if m:
        return f"{name}{m.group(1)} → {m.group(2)}"
    return f"{name} {ov}"


def see_link(target: str) -> str:
    if re.match(r"^(Iter8|iterator)[.:]", target):
        return f"[`{target}`](#{to_anchor(target)})"
    return f"`{target}`"


# ── parser ───────────────────────────────────────────────────────────────────

def convert_alerts(lines: list) -> list:
    """Replace '> [!Note]\\n> body' sequences with MkDocs admonition blocks."""
    out, i = [], 0
    while i < len(lines):
        m = re.match(r"^> \[!(note|warning|tip|important)\]\s*$", lines[i], re.I)
        if m:
            kind = m.group(1).lower()
            out.append(f"!!! {kind}")
            i += 1
            while i < len(lines):
                if lines[i] == ">":
                    out.append("    ")
                    i += 1
                elif lines[i].startswith("> "):
                    out.append("    " + lines[i][2:])
                    i += 1
                else:
                    break
        else:
            out.append(lines[i])
            i += 1
    return out


def parse_doc_block(raw_block: list, def_line: str) -> dict | None:
    """Parse a list of raw --- lines + the following definition line."""
    content = [strip_prefix(l) for l in raw_block]

    desc_raw, params, returns, overloads, sees = [], [], [], [], []
    class_name = None

    for line in content:
        if line.startswith("@param "):
            m = re.match(r"@param\s+(\S+)\s+(.*)", line)
            if m:
                params.append((m.group(1).strip("`"), m.group(2).strip()))
        elif line.startswith("@return "):
            m = re.match(r"@return\s+(.*)", line)
            if m:
                returns.append(m.group(1).strip())
        elif line.startswith("@overload "):
            m = re.match(r"@overload\s+(.*)", line)
            if m:
                overloads.append(m.group(1).strip())
        elif line.startswith("@see "):
            m = re.match(r"@see\s+(.*)", line)
            if m:
                sees.append(m.group(1).strip())
        elif line.startswith("@class "):
            m = re.match(r"@class\s+(\w+)", line)
            if m:
                class_name = m.group(1)
        elif not line.startswith("@"):
            desc_raw.append(line)

    # Strip leading/trailing blank description lines
    while desc_raw and not desc_raw[0].strip():
        desc_raw.pop(0)
    while desc_raw and not desc_raw[-1].strip():
        desc_raw.pop()

    desc = convert_alerts(desc_raw)

    base = dict(
        desc=desc, params=params, returns=returns,
        overloads=overloads, sees=sees,
    )

    # Function definition
    m = re.match(r"^function\s+([\w.:]+)\s*\((.*?)\)", def_line)
    if m:
        fname, fargs = m.group(1), m.group(2)
        args = [
            a.strip() for a in fargs.split(",")
            if a.strip() and a.strip() != "self"
        ]
        sig = f"{fname}({', '.join(args)})"
        return dict(type="function", name=fname, sig=sig, **base)

    # Class intro (e.g. @class Iter8 or @class iterator)
    if class_name:
        return dict(type="class", name=class_name, sig="", **base)

    # Alias (e.g. Iter8.list = Iter8.ivalues)
    m = re.match(r"^(Iter8\.\w+)\s*=\s*(Iter8\.\w+)\s*$", def_line)
    if m and not def_line.startswith("local"):
        return dict(
            type="alias", name=m.group(1), alias_of=m.group(2),
            sig="", **base,
        )

    return None


def parse_entries(src: str) -> list:
    lines = src.splitlines()
    entries = []
    i = 0

    while i < len(lines):
        line = lines[i]

        # Skip pure divider lines (-----, ====)
        if re.match(r"^[-=]{4,}\s*$", line):
            i += 1
            continue

        # Section header: "-- Name --" (must not be "---")
        if (
            line.startswith("-- ")
            and line.rstrip().endswith(" --")
            and not line.startswith("---")
        ):
            name = line.strip().strip("-").strip()
            if name:
                entries.append({"type": "section", "name": name})
            i += 1
            continue

        # Doc block: one or more consecutive --- lines
        if line.startswith("---"):
            raw_block = []
            while i < len(lines) and lines[i].startswith("---"):
                raw_block.append(lines[i])
                i += 1
            # Skip blank lines before definition
            while i < len(lines) and lines[i].strip() == "":
                i += 1
            def_line = lines[i].rstrip() if i < len(lines) else ""
            entry = parse_doc_block(raw_block, def_line)
            if entry:
                entries.append(entry)
            # def_line will be consumed by the outer loop naturally
            continue

        i += 1

    return entries


# ── renderer ─────────────────────────────────────────────────────────────────

def render_function(e: dict, level: int) -> list:
    hashes = "#" * level
    name = e["name"]
    anc = to_anchor(name)
    out = []

    if e["overloads"]:
        out.append(f"\n{hashes} `{name}` {{ #{anc} }}\n")
        out.append("```lua")
        for ov in e["overloads"]:
            out.append(overload_sig(name, ov))
        out.append("```\n")
    else:
        out.append(f"\n{hashes} `{e['sig']}` {{ #{anc} }}\n")

    if e["desc"]:
        out.extend(e["desc"])
        out.append("")

    if e["params"]:
        out.append("\n**Parameters:**\n")
        out.append("| Name | Type |")
        out.append("|------|------|")
        for pname, ptype in e["params"]:
            # Strip LuaLS generic backtick markers from types
            ptype = ptype.strip("`")
            out.append(f"| `{pname}` | `{ptype}` |")
        out.append("")

    if e["returns"]:
        ret = ", ".join(f"`{r.strip('`')}`" for r in e["returns"])
        out.append(f"\n**Returns:** {ret}\n")

    if e["sees"]:
        links = ", ".join(see_link(s) for s in e["sees"])
        out.append(f"\n**See also:** {links}\n")

    out.append("\n---\n")
    return out


def render(entries: list) -> str:
    lines = [
        "# iter8 API Reference\n",
        "**iter8** is a lazy iterator library for Lua 5.1+ and LuaJIT.\n",
        "",
        "```lua",
        'local Iter8 = require "iter8"',
        "```",
        "",
        "---",
        "",
    ]

    fn_level = 3
    in_methods = False
    methods_has_subsection = False

    for e in entries:
        t = e["type"]

        if t == "section":
            name = e["name"]
            if name == "Constructors":
                lines.append("\n## Constructors\n")
                fn_level = 3
                in_methods = False
                methods_has_subsection = False
            elif name == "Methods":
                lines.append("\n## iterator Methods\n")
                # Functions before the first subsection use ###; once a
                # subsection appears they drop to ####.
                fn_level = 3
                in_methods = True
                methods_has_subsection = False
            elif in_methods:
                lines.append(f"\n### {name}\n")
                fn_level = 4
                methods_has_subsection = True
            continue

        if t == "class":
            if e["overloads"]:
                # Iter8 callable — render like a function entry
                lines.extend(render_function(e, fn_level))
            elif e["desc"]:
                lines.extend(e["desc"])
                lines.append("")
            continue

        if t == "alias":
            target = e.get("alias_of", "")
            if target:
                anc = to_anchor(e["name"])
                hashes = "#" * fn_level
                lines.append(
                    f"\n{hashes} `{e['name']}` {{ #{anc} }}\n"
                    f"\nAlias for [`{target}`](#{to_anchor(target)}).\n"
                    "\n---\n"
                )
            continue

        if t == "function":
            lines.extend(render_function(e, fn_level))
            continue

    return "\n".join(lines) + "\n"


# ── main ─────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    src = SRC.read_text()
    entries = parse_entries(src)
    md = render(entries)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(md)
    n_fn = sum(1 for e in entries if e["type"] == "function")
    n_sec = sum(1 for e in entries if e["type"] == "section")
    print(f"Written: {OUT}  ({n_fn} functions, {n_sec} sections)")
