import pathlib
import re
import subprocess
import sys

import semantic_highlight


ANSI_RE = re.compile(r"\x1b\[([0-9;]*)m")


def _normalize_style(style):
    bold, underline, fg, bg = style
    if not bold and not underline and fg is None and bg is None:
        return None
    return (bold, underline, fg, bg)


def _apply_codes(style, code_text):
    bold, underline, fg, bg = style
    raw_parts = code_text.split(";") if code_text else ["0"]

    parts = []
    for raw in raw_parts:
        if raw == "":
            raw = "0"
        if not raw.isdigit():
            continue
        parts.append(int(raw))

    i = 0
    while i < len(parts):
        code = parts[i]

        if code == 0:
            bold = False
            underline = False
            fg = None
            bg = None
            i += 1
        elif code == 1:
            bold = True
            i += 1
        elif code == 4:
            underline = True
            i += 1
        elif code == 22:
            bold = False
            i += 1
        elif code == 24:
            underline = False
            i += 1
        elif 30 <= code <= 37:
            fg = str(code)
            i += 1
        elif code == 39:
            fg = None
            i += 1
        elif 40 <= code <= 47:
            bg = str(code)
            i += 1
        elif code == 49:
            bg = None
            i += 1
        elif code == 38 and i + 2 < len(parts) and parts[i + 1] == 5:
            # tree-sitter sometimes emits 38;5;<n>; map our simple palette back.
            ext = parts[i + 2]
            if 30 <= ext <= 37:
                fg = str(ext)
            i += 3
        elif code == 48 and i + 2 < len(parts) and parts[i + 1] == 5:
            ext = parts[i + 2]
            if 40 <= ext <= 47:
                bg = str(ext)
            i += 3
        else:
            i += 1

    return _normalize_style((bold, underline, fg, bg))


def _parse_ansi_text(ansi_text):
    plain_parts = []
    styles = []
    current_style = None
    last = 0

    for match in ANSI_RE.finditer(ansi_text):
        segment = ansi_text[last : match.start()]
        if segment:
            plain_parts.append(segment)
            styles.extend([current_style] * len(segment))

        code_text = match.group(1)
        current_style = _apply_codes(current_style or (False, False, None, None), code_text)
        last = match.end()

    tail = ansi_text[last:]
    if tail:
        plain_parts.append(tail)
        styles.extend([current_style] * len(tail))

    return "".join(plain_parts), styles


def _style_from_escape(escape_seq):
    if not escape_seq:
        return None
    if not escape_seq.startswith("\x1b[") or not escape_seq.endswith("m"):
        return None
    return _apply_codes((False, False, None, None), escape_seq[2:-1])


def _render_with_styles(text, styles):
    out = []
    prev = None

    for ch, style in zip(text, styles):
        if style != prev:
            if prev is not None:
                out.append("\x1b[0m")
            if style is not None:
                bold, underline, fg, bg = style
                codes = []
                if bold:
                    codes.append("1")
                if underline:
                    codes.append("4")
                if fg is not None:
                    codes.append(fg)
                if bg is not None:
                    codes.append(bg)
                if codes:
                    out.append(f"\x1b[{';'.join(codes)}m")
            prev = style
        out.append(ch)

    if prev is not None:
        out.append("\x1b[0m")
    return "".join(out)


def _tree_sitter_ansi(file_path):
    proc = subprocess.run(
        ["tree-sitter", "highlight", str(file_path)],
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        err = proc.stderr.strip() or "tree-sitter highlight failed"
        raise RuntimeError(err)
    return proc.stdout


def main():
    if len(sys.argv) < 2:
        print("Usage: mixed_highlight.py <file>", file=sys.stderr)
        return 1

    file_path = pathlib.Path(sys.argv[1]).resolve()
    if not file_path.exists():
        print(f"File not found: {file_path}", file=sys.stderr)
        return 1

    try:
        ts_ansi = _tree_sitter_ansi(file_path)
    except RuntimeError as err:
        print(str(err), file=sys.stderr)
        return 2

    ts_text, ts_styles = _parse_ansi_text(ts_ansi)

    try:
        semantic_text, semantic_spans = semantic_highlight.semantic_spans_for_file(file_path)
    except RuntimeError:
        # Semantic highlighting is optional in mixed mode: preserve tree-sitter output.
        sys.stdout.write(_render_with_styles(ts_text, ts_styles))
        return 0

    if ts_text != semantic_text:
        # If token coordinates do not match exact text, avoid corrupt output.
        sys.stdout.write(_render_with_styles(ts_text, ts_styles))
        return 0

    semantic_styles = [None] * len(semantic_text)
    for start, end, token_type, token_mods in semantic_spans:
        style_escape = semantic_highlight.token_style_for_semantic(token_type, token_mods)
        style = _style_from_escape(style_escape)
        if style is None:
            continue

        s = max(0, min(start, len(semantic_styles)))
        e = max(s, min(end, len(semantic_styles)))
        if e > s:
            semantic_styles[s:e] = [style] * (e - s)

    merged_styles = [
        sem if sem is not None else ts
        for ts, sem in zip(ts_styles, semantic_styles)
    ]

    sys.stdout.write(_render_with_styles(semantic_text, merged_styles))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
