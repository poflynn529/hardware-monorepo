"""Parse two Vivado utilization and timing reports and print a side-by-side comparison.

Usage: compare.py <util_a> <timing_a> <util_b> <timing_b> <output>
"""

import re
import sys


_METRICS = [
    "Slice LUTs",
    "LUT as Logic",
    "LUT as Memory",
    "Slice Registers",
    "F7 Muxes",
    "F8 Muxes",
    "DSPs",
]

# Rows indented with leading spaces are sub-categories; detect by original line.
_SUB_RE          = re.compile(r'^\|\s{3,}')
_ROW_RE          = re.compile(r'^\|\s+(.*?)\s*\*?\s*\|\s+(\d+)\s*\|\s+\d+\s*\|\s+(\d+)\s*\|')
_DESIGN_RE       = re.compile(r'^\|\s*Design\s*:\s*(\S+)')
_LOGIC_LEVELS_RE = re.compile(r'Logic Levels:\s+(\d+)')


def _parse(path):
    module  = path
    metrics = {}     # name → (used, available)
    indented = set() # names that appear as sub-rows

    with open(path) as f:
        for line in f:
            m = _DESIGN_RE.match(line)
            if m:
                module = m.group(1)
                continue

            row = _ROW_RE.match(line)
            if row:
                name  = row.group(1).rstrip("*").strip()
                used  = int(row.group(2))
                avail = int(row.group(3))
                metrics[name] = (used, avail)
                if _SUB_RE.match(line):
                    indented.add(name)

    return module, metrics, indented


def _parse_timing(path):
    """Return the maximum logic level count found in a Vivado timing report."""
    max_levels = None
    with open(path) as f:
        for line in f:
            m = _LOGIC_LEVELS_RE.search(line)
            if m:
                lvl = int(m.group(1))
                if max_levels is None or lvl > max_levels:
                    max_levels = lvl
    return max_levels


def _pct(a, b):
    if b == 0:
        return ""
    return " ({:+.0f}%)".format(100.0 * (a - b) / b)


def _write(out, module_a, module_b, metrics_a, metrics_b, indented, levels_a, levels_b):
    col = 24
    w   = 10

    header = "{:<{col}}  {:>{w}}  {:>{w}}  {:>{w}}".format(
        "Metric", module_a[:w], module_b[:w], "Δ",
        col=col, w=w,
    )
    rule = "─" * len(header)

    lines = [
        "=== Synthesis comparison ===",
        header,
        rule,
    ]

    lvl_a_str = str(levels_a) if levels_a is not None else "n/a"
    lvl_b_str = str(levels_b) if levels_b is not None else "n/a"
    if levels_a is not None and levels_b is not None:
        delta     = levels_b - levels_a
        delta_str = "{:+d}{}".format(delta, _pct(levels_b, levels_a)) if delta else "0"
    else:
        delta_str = ""
    lines.append("{:<{col}}  {:>{w}}  {:>{w}}  {}".format(
        "Max Logic Levels", lvl_a_str, lvl_b_str, delta_str,
        col=col, w=w,
    ))
    lines.append(rule)

    for name in _METRICS:
        used_a = metrics_a.get(name, (0, 0))[0]
        used_b = metrics_b.get(name, (0, 0))[0]
        delta  = used_b - used_a
        delta_str = "{:+d}{}".format(delta, _pct(used_b, used_a)) if delta else "0"
        indent = "  " if name in (indented | (metrics_b.keys() & indented)) else ""
        lines.append("{}{:<{col}}  {:>{w}}  {:>{w}}  {}".format(
            indent, name, used_a, used_b, delta_str,
            col=col - len(indent), w=w,
        ))

    out.write("\n".join(lines) + "\n")


def main():
    if len(sys.argv) != 6:
        sys.exit("usage: compare.py <util_a> <timing_a> <util_b> <timing_b> <output>")

    util_a, timing_a, util_b, timing_b, output = sys.argv[1:]

    module_a, metrics_a, indented_a = _parse(util_a)
    module_b, metrics_b, indented_b = _parse(util_b)
    indented = indented_a | indented_b
    levels_a = _parse_timing(timing_a)
    levels_b = _parse_timing(timing_b)

    with open(output, "w") as f:
        _write(f, module_a, module_b, metrics_a, metrics_b, indented, levels_a, levels_b)

    # Also echo to stdout so `buck2 build --show-output` + cat is convenient.
    _write(sys.stdout, module_a, module_b, metrics_a, metrics_b, indented, levels_a, levels_b)


if __name__ == "__main__":
    main()
