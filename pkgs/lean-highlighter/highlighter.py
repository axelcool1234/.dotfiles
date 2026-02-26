import argparse
import json
import os
import pathlib
import re
import select
import shutil
import subprocess
import sys
import tempfile
import time


ANSI_RE = re.compile(r"\x1b\[([0-9;]*)m")


# ANSI formats (Discord subset)
FMT_NORMAL = "0"
FMT_BOLD = "1"
FMT_UNDERLINE = "4"
FMT_NOT_BOLD = "22"
FMT_NOT_UNDERLINE = "24"

# ANSI foreground colors (Discord subset)
FG_GRAY = "30"
FG_RED = "31"
FG_GREEN = "32"
FG_YELLOW = "33"
FG_BLUE = "34"
FG_PINK = "35"
FG_CYAN = "36"
FG_WHITE = "37"
FG_DEFAULT = "39"

# ANSI background colors (Discord subset)
BG_FIREFLY_DARK_BLUE = "40"
BG_ORANGE = "41"
BG_MARBLE_BLUE = "42"
BG_GREYISH_TURQUOISE = "43"
BG_GRAY = "44"
BG_INDIGO = "45"
BG_LIGHT_GRAY = "46"
BG_WHITE = "47"
BG_DEFAULT = "49"

FMT_NORMAL_CODE = int(FMT_NORMAL)
FMT_BOLD_CODE = int(FMT_BOLD)
FMT_UNDERLINE_CODE = int(FMT_UNDERLINE)
FMT_NOT_BOLD_CODE = int(FMT_NOT_BOLD)
FMT_NOT_UNDERLINE_CODE = int(FMT_NOT_UNDERLINE)

FG_MIN_CODE = int(FG_GRAY)
FG_MAX_CODE = int(FG_WHITE)
FG_DEFAULT_CODE = int(FG_DEFAULT)

BG_MIN_CODE = int(BG_FIREFLY_DARK_BLUE)
BG_MAX_CODE = int(BG_WHITE)
BG_DEFAULT_CODE = int(BG_DEFAULT)

EXT_COLOR_PREFIX_CODE = 38
EXT_BG_PREFIX_CODE = 48
EXT_256_SELECTOR_CODE = 5


# (bold, underline, fg, bg)
# fg/bg use Discord's ANSI subset: fg 30-37, bg 40-47.
ROLE_STYLES = {
    "comment": (False, False, FG_GRAY, None),
    "keyword": (False, False, FG_PINK, None),
    "function": (False, False, FG_BLUE, None),
    "type": (False, False, FG_CYAN, None),
    "string": (False, False, FG_GREEN, None),
    "number": (False, False, FG_YELLOW, None),
    "number_strong": (True, False, FG_YELLOW, None),
    "variable": None,
    "parameter": (False, False, FG_CYAN, None),
    "property": (False, False, FG_YELLOW, None),
    "operator": None,
    "namespace": (False, False, FG_CYAN, None),
    "warning": (True, True, FG_RED, BG_FIREFLY_DARK_BLUE),
}


LIGATURES = {
    "=>": "⇒",
    "->": "→",
    "<-": "←",
    ">=": "≥",
    "<=": "≤",
    "::": "∷",
    ":=": "≔",
    "!=": "≠",
    "<<": "≪",
    ">>": "≫",
    "!!": "‼",
    "??": "⁇",
    "?!": "⁈",
    "!?": "⁉",
    "·": "•",
    "*": "∗",
}


TREE_SITTER_CAPTURE_ROLES = {
    "attribute": "comment",
    "comment": "comment",
    "constant": "number",
    "constant.builtin": "number_strong",
    "constructor": "type",
    "embedded": None,
    "function": "function",
    "function.builtin": "function",
    "keyword": "keyword",
    "keyword.control": "keyword",
    "module": "namespace",
    "number": "number_strong",
    "operator": "operator",
    "property": "property",
    "property.builtin": "property",
    "punctuation": "operator",
    "punctuation.bracket": "operator",
    "punctuation.delimiter": "operator",
    "punctuation.special": "operator",
    "string": "string",
    "string.special": "string",
    "tag": "keyword",
    "type": "type",
    "type.builtin": "type",
    "variable": "variable",
    "variable.builtin": "variable",
    "variable.parameter": "parameter",
}


SEMANTIC_TYPE_ROLES = {
    "comment": "comment",
    "keyword": "keyword",
    "string": "string",
    "number": "number",
    "regexp": "string",
    "operator": "operator",
    "namespace": "namespace",
    "type": "type",
    "struct": "type",
    "class": "type",
    "interface": "type",
    "enum": "type",
    "typeParameter": "type",
    "function": "function",
    "method": "function",
    "macro": "function",
    "modifier": "keyword",
    "decorator": "keyword",
    "property": "property",
    "parameter": "parameter",
    "variable": "variable",
    "enumMember": "property",
}


def _normalize_style(style):
    if style is None:
        return None
    bold, underline, fg, bg = style
    # Discord default text is effectively white; avoid redundant explicit white.
    if fg == FG_WHITE:
        fg = None
    if not bold and not underline and fg is None and bg is None:
        return None
    return (bold, underline, fg, bg)


def _style_to_theme_value(style):
    style = _normalize_style(style)
    if style is None:
        return None

    bold, underline, fg, _bg = style
    value = {}
    if fg is not None:
        value["color"] = int(fg)
    if bold:
        value["bold"] = True
    if underline:
        value["underline"] = True

    if set(value.keys()) == {"color"}:
        return value["color"]
    return value


def build_tree_sitter_config(parser_dir):
    theme = {}
    for capture, role in TREE_SITTER_CAPTURE_ROLES.items():
        style = ROLE_STYLES.get(role) if role is not None else None
        theme[capture] = _style_to_theme_value(style)

    return {
        "parser-directories": [str(parser_dir)],
        "theme": theme,
    }


def _replace_ligatures(text):
    for key in sorted(LIGATURES.keys(), key=len, reverse=True):
        text = text.replace(key, LIGATURES[key])
    return text


def _apply_codes(style, code_text):
    bold, underline, fg, bg = style
    raw_parts = code_text.split(";") if code_text else ["0"]

    parts = []
    for raw in raw_parts:
        if raw == "":
            raw = "0"
        if raw.isdigit():
            parts.append(int(raw))

    i = 0
    while i < len(parts):
        code = parts[i]
        if code == FMT_NORMAL_CODE:
            bold = False
            underline = False
            fg = None
            bg = None
            i += 1
        elif code == FMT_BOLD_CODE:
            bold = True
            i += 1
        elif code == FMT_UNDERLINE_CODE:
            underline = True
            i += 1
        elif code == FMT_NOT_BOLD_CODE:
            bold = False
            i += 1
        elif code == FMT_NOT_UNDERLINE_CODE:
            underline = False
            i += 1
        elif FG_MIN_CODE <= code <= FG_MAX_CODE:
            fg = str(code)
            i += 1
        elif code == FG_DEFAULT_CODE:
            fg = None
            i += 1
        elif BG_MIN_CODE <= code <= BG_MAX_CODE:
            bg = str(code)
            i += 1
        elif code == BG_DEFAULT_CODE:
            bg = None
            i += 1
        elif code == EXT_COLOR_PREFIX_CODE and i + 2 < len(parts) and parts[i + 1] == EXT_256_SELECTOR_CODE:
            ext = parts[i + 2]
            if FG_MIN_CODE <= ext <= FG_MAX_CODE:
                fg = str(ext)
            i += 3
        elif code == EXT_BG_PREFIX_CODE and i + 2 < len(parts) and parts[i + 1] == EXT_256_SELECTOR_CODE:
            ext = parts[i + 2]
            if BG_MIN_CODE <= ext <= BG_MAX_CODE:
                bg = str(ext)
            i += 3
        else:
            i += 1

    return _normalize_style((bold, underline, fg, bg))


def _parse_ansi_text(ansi_text):
    plain_parts = []
    styles = []
    current = None
    last = 0

    for match in ANSI_RE.finditer(ansi_text):
        segment = ansi_text[last : match.start()]
        if segment:
            plain_parts.append(segment)
            styles.extend([current] * len(segment))

        current = _apply_codes(current or (False, False, None, None), match.group(1))
        last = match.end()

    tail = ansi_text[last:]
    if tail:
        plain_parts.append(tail)
        styles.extend([current] * len(tail))

    return "".join(plain_parts), styles


def _transition_sgr(prev, nxt):
    if prev == nxt:
        return ""

    if nxt is None:
        return f"\x1b[{FMT_NORMAL}m"

    pb, pu, pfg, pbg = prev or (False, False, None, None)
    nb, nu, nfg, nbg = nxt

    codes = []
    if pb and not nb:
        codes.append(FMT_NOT_BOLD)
    if pu and not nu:
        codes.append(FMT_NOT_UNDERLINE)

    if pfg != nfg:
        codes.append(nfg if nfg is not None else FG_DEFAULT)
    if pbg != nbg:
        codes.append(nbg if nbg is not None else BG_DEFAULT)

    if not pb and nb:
        codes.append(FMT_BOLD)
    if not pu and nu:
        codes.append(FMT_UNDERLINE)

    delta_seq = ""
    if codes:
        delta_seq = f"\x1b[{';'.join(codes)}m"

    # Optional shorter route: reset-to-default (white), then re-apply needed attrs.
    # This is mainly useful when moving from a colored span to default text.
    use_reset_candidate = pfg is not None and nfg is None
    if use_reset_candidate:
        reset_codes = [FMT_NORMAL]
        if nb:
            reset_codes.append(FMT_BOLD)
        if nu:
            reset_codes.append(FMT_UNDERLINE)
        if nbg is not None:
            reset_codes.append(nbg)
        reset_seq = f"\x1b[{';'.join(reset_codes)}m"

        if not delta_seq or len(reset_seq) <= len(delta_seq):
            return reset_seq

    return delta_seq


def _render_with_styles(text, styles):
    out = []
    prev = None
    for ch, style in zip(text, styles):
        style = _normalize_style(style)
        if style != prev:
            seq = _transition_sgr(prev, style)
            if seq:
                out.append(seq)
            prev = style
        out.append(ch)

    if prev is not None:
        out.append(f"\x1b[{FMT_NORMAL}m")
    return "".join(out)


def _bridge_unstyled_whitespace(text, styles):
    """
    Extend style across unstyled whitespace-only gaps to reduce reset/reapply
    churn. If both sides are styled, prefer the left style so color-to-color
    transitions happen directly at the next token.
    """
    bridged = list(styles)
    n = len(bridged)
    i = 0

    while i < n:
        if bridged[i] is not None:
            i += 1
            continue

        j = i
        while j < n and bridged[j] is None:
            j += 1

        if j > i and text[i:j].isspace():
            left = bridged[i - 1] if i > 0 else None
            right = bridged[j] if j < n else None

            # Bridge only when there is a styled token on the left and another
            # styled token on the right; this keeps resets for real returns to
            # default text while minimizing style ping-pong between tokens.
            if left is not None and right is not None:
                for k in range(i, j):
                    bridged[k] = left

        i = j

    return bridged


def _package_root():
    return pathlib.Path(__file__).resolve().parent.parent


def _tree_sitter_parser_dir():
    return _package_root() / "share" / "tree-sitter"


def _run_tree_sitter(file_path):
    if shutil.which("tree-sitter") is None:
        raise RuntimeError("`tree-sitter` is not available in PATH")

    parser_dir = _tree_sitter_parser_dir()
    config = build_tree_sitter_config(parser_dir)

    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as tmp:
        json.dump(config, tmp)
        config_path = tmp.name

    try:
        proc = subprocess.run(
            ["tree-sitter", "highlight", "--config-path", config_path, str(file_path)],
            capture_output=True,
            text=True,
            check=False,
        )
    finally:
        try:
            os.unlink(config_path)
        except OSError:
            pass

    if proc.returncode != 0:
        err = proc.stderr.strip() or "tree-sitter highlight failed"
        raise RuntimeError(err)

    return _parse_ansi_text(proc.stdout)


def _jsonrpc_send(stdin, payload):
    body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
    header = f"Content-Length: {len(body)}\r\n\r\n".encode("ascii")
    stdin.write(header)
    stdin.write(body)
    stdin.flush()


def _read_from_fd(fd, num_bytes, deadline):
    data = bytearray()
    while len(data) < num_bytes:
        timeout = deadline - time.monotonic()
        if timeout <= 0:
            raise TimeoutError

        readable, _, _ = select.select([fd], [], [], timeout)
        if not readable:
            raise TimeoutError

        chunk = os.read(fd, num_bytes - len(data))
        if not chunk:
            return None
        data.extend(chunk)
    return bytes(data)


def _jsonrpc_read(stdout, deadline):
    fd = stdout.fileno()
    header = bytearray()
    while b"\r\n\r\n" not in header:
        chunk = _read_from_fd(fd, 1, deadline)
        if chunk is None:
            return None
        header.extend(chunk)

    header_text = header.decode("ascii", errors="replace")
    content_length = None
    for line in header_text.split("\r\n"):
        if line.lower().startswith("content-length:"):
            content_length = int(line.split(":", 1)[1].strip())
            break
    if content_length is None:
        raise RuntimeError("Malformed JSON-RPC header: missing Content-Length")

    body = _read_from_fd(fd, content_length, deadline)
    if body is None:
        return None
    return json.loads(body.decode("utf-8"))


def _wait_for_response(stdout, req_id, timeout_s):
    deadline = time.monotonic() + timeout_s
    while True:
        if time.monotonic() >= deadline:
            return None
        try:
            msg = _jsonrpc_read(stdout, deadline)
        except TimeoutError:
            return None
        if msg is None:
            return None
        if msg.get("id") == req_id:
            return msg


def _find_lake_root(start_dir):
    current = pathlib.Path(start_dir).resolve()
    while True:
        if (current / "lakefile.lean").exists() or (current / "lakefile.toml").exists():
            return current
        if current.parent == current:
            return None
        current = current.parent


def _pick_server(file_path):
    file_dir = pathlib.Path(file_path).resolve().parent
    lake_root = _find_lake_root(file_dir)

    if lake_root is not None and shutil.which("lake"):
        return (["lake", "env", "lean", "--server"], str(lake_root))
    if shutil.which("lean"):
        return (["lean", "--server"], str(file_dir))

    raise RuntimeError(
        "Neither `lake` nor `lean` is available in PATH. "
        "Semantic mode requires Lean's language server."
    )


def _utf16_col_to_py_idx(line_text, col_utf16):
    units = 0
    for i, ch in enumerate(line_text):
        if units >= col_utf16:
            return i
        units += 2 if ord(ch) >= 0x10000 else 1
    return len(line_text)


def _decode_modifiers(mod_bits, modifier_names):
    mods = set()
    bit = 0
    value = mod_bits
    while value:
        if value & 1 and bit < len(modifier_names):
            mods.add(modifier_names[bit])
        value >>= 1
        bit += 1
    return mods


def _token_spans(text, data, token_types, token_modifiers):
    lines = text.splitlines(keepends=True)
    if not lines:
        return []

    line_starts = []
    acc = 0
    for ln in lines:
        line_starts.append(acc)
        acc += len(ln)

    spans = []
    line = 0
    col = 0

    for i in range(0, len(data), 5):
        token = data[i : i + 5]
        if len(token) < 5:
            break
        d_line, d_col, length, type_idx, mod_bits = token

        line += d_line
        if line >= len(lines):
            break
        if d_line > 0:
            col = 0
        col += d_col

        line_text = lines[line]
        start_in_line = _utf16_col_to_py_idx(line_text, col)
        end_in_line = _utf16_col_to_py_idx(line_text, col + length)
        start_abs = line_starts[line] + start_in_line
        end_abs = line_starts[line] + end_in_line

        if end_abs > start_abs:
            tok_type = token_types[type_idx] if type_idx < len(token_types) else ""
            tok_mods = _decode_modifiers(mod_bits, token_modifiers)
            spans.append((start_abs, end_abs, tok_type, tok_mods))

    return spans


def _semantic_style(token_type, token_mods):
    if token_type == "leanSorryLike":
        return ROLE_STYLES["warning"]

    role = SEMANTIC_TYPE_ROLES.get(token_type)
    style = ROLE_STYLES.get(role)
    if style is None and not token_mods:
        return None

    bold, underline, fg, bg = style or (False, False, None, None)

    if "declaration" in token_mods or "definition" in token_mods:
        bold = True
    if "readonly" in token_mods or "deprecated" in token_mods:
        underline = True

    if "deprecated" in token_mods:
        fg = FG_RED
    elif "defaultLibrary" in token_mods and fg in (None, FG_WHITE):
        fg = FG_CYAN
    elif "documentation" in token_mods and fg is None:
        fg = FG_GRAY
    elif "modification" in token_mods and fg in (None, FG_WHITE):
        fg = FG_YELLOW

    return _normalize_style((bold, underline, fg, bg))


def _semantic_spans_for_file(file_path):
    file_path = pathlib.Path(file_path).resolve()
    if not file_path.exists():
        raise FileNotFoundError(f"File not found: {file_path}")

    text = file_path.read_text(encoding="utf-8")
    cmd, cwd = _pick_server(file_path)

    proc = subprocess.Popen(
        cmd,
        cwd=cwd,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )

    try:
        _jsonrpc_send(
            proc.stdin,
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {
                    "processId": os.getpid(),
                    "rootUri": pathlib.Path(cwd).resolve().as_uri(),
                    "capabilities": {},
                },
            },
        )
        init_resp = _wait_for_response(proc.stdout, 1, timeout_s=10)
        init_result = init_resp.get("result") if init_resp else None
        if not isinstance(init_result, dict):
            raise RuntimeError("Lean LSP initialize failed")

        server_caps = init_result.get("capabilities", {})
        if not isinstance(server_caps, dict):
            server_caps = {}
        sem_provider = server_caps.get("semanticTokensProvider", {})
        if not isinstance(sem_provider, dict):
            sem_provider = {}
        legend = sem_provider.get("legend", {})
        if not isinstance(legend, dict):
            legend = {}
        token_types = legend.get("tokenTypes", [])
        if not isinstance(token_types, list):
            token_types = []
        token_modifiers = legend.get("tokenModifiers", [])
        if not isinstance(token_modifiers, list):
            token_modifiers = []

        _jsonrpc_send(
            proc.stdin,
            {
                "jsonrpc": "2.0",
                "method": "initialized",
                "params": {},
            },
        )

        uri = file_path.as_uri()
        _jsonrpc_send(
            proc.stdin,
            {
                "jsonrpc": "2.0",
                "method": "textDocument/didOpen",
                "params": {
                    "textDocument": {
                        "uri": uri,
                        "languageId": "lean",
                        "version": 1,
                        "text": text,
                    }
                },
            },
        )

        _jsonrpc_send(
            proc.stdin,
            {
                "jsonrpc": "2.0",
                "id": 2,
                "method": "textDocument/semanticTokens/full",
                "params": {"textDocument": {"uri": uri}},
            },
        )

        tok_resp = _wait_for_response(proc.stdout, 2, timeout_s=30)
        if not tok_resp or "result" not in tok_resp:
            raise RuntimeError("Lean LSP semantic token request failed")

        tok_result = tok_resp.get("result")
        if tok_result is None:
            data = []
        elif isinstance(tok_result, dict):
            data = tok_result.get("data")
            if not isinstance(data, list):
                data = []
        else:
            raise RuntimeError("Lean LSP semantic token response is malformed")

        spans = _token_spans(text, data, token_types, token_modifiers)
        return text, spans
    finally:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=1)
            except subprocess.TimeoutExpired:
                proc.kill()


def _styles_from_semantic(text, spans):
    styles = [None] * len(text)
    for start, end, token_type, token_mods in spans:
        style = _semantic_style(token_type, token_mods)
        if style is None:
            continue
        s = max(0, min(start, len(styles)))
        e = max(s, min(end, len(styles)))
        if e > s:
            styles[s:e] = [style] * (e - s)
    return styles


def highlight(file_path, mode):
    if mode == "auto":
        try:
            sem_text, spans = _semantic_spans_for_file(file_path)
            sem_styles = _styles_from_semantic(sem_text, spans)
            sem_styles = _bridge_unstyled_whitespace(sem_text, sem_styles)
            return _render_with_styles(sem_text, sem_styles)
        except Exception:
            # Preserve legacy --auto behavior: semantic first, then pure tree-sitter fallback.
            mode = "treesitter"

    if mode == "semantic":
        sem_text, spans = _semantic_spans_for_file(file_path)
        sem_styles = _styles_from_semantic(sem_text, spans)
        sem_styles = _bridge_unstyled_whitespace(sem_text, sem_styles)
        return _render_with_styles(sem_text, sem_styles)

    if mode not in {"treesitter", "mixed"}:
        raise RuntimeError(f"Unknown mode: {mode}")

    ts_text, ts_styles = _run_tree_sitter(file_path)
    ts_styles = _bridge_unstyled_whitespace(ts_text, ts_styles)

    if mode == "treesitter":
        return _render_with_styles(ts_text, ts_styles)

    try:
        sem_text, spans = _semantic_spans_for_file(file_path)
    except Exception:
        return _render_with_styles(ts_text, ts_styles)

    if sem_text != ts_text:
        return _render_with_styles(ts_text, ts_styles)

    sem_styles = _styles_from_semantic(sem_text, spans)
    merged = [
        sem if sem is not None else ts
        for ts, sem in zip(ts_styles, sem_styles)
    ]
    merged = _bridge_unstyled_whitespace(ts_text, merged)
    return _render_with_styles(ts_text, merged)


def main():
    default_mode = os.environ.get("LEAN_HIGHLIGHT_MODE", "mixed").strip().lower()
    if default_mode not in {"mixed", "semantic", "treesitter", "auto"}:
        default_mode = "mixed"

    parser = argparse.ArgumentParser(add_help=True)
    parser.add_argument(
        "--print-tree-sitter-config",
        metavar="PARSER_DIR",
        help="print config.json for tree-sitter and exit",
    )
    parser.add_argument(
        "--mode",
        choices=["mixed", "semantic", "treesitter", "auto"],
        default=default_mode,
        help="highlighting mode",
    )
    mode_group = parser.add_mutually_exclusive_group()
    mode_group.add_argument("--mixed", action="store_true", help="same as --mode mixed")
    mode_group.add_argument("--semantic", action="store_true", help="same as --mode semantic")
    mode_group.add_argument("--treesitter", action="store_true", help="same as --mode treesitter")
    mode_group.add_argument("--auto", action="store_true", help="semantic first; fallback to treesitter")
    parser.add_argument("--pretty", action="store_true", help="apply pretty ligature pass")
    parser.add_argument("file", nargs="?")
    args = parser.parse_args()

    if args.print_tree_sitter_config is not None:
        config = build_tree_sitter_config(args.print_tree_sitter_config)
        json.dump(config, sys.stdout, indent=2)
        sys.stdout.write("\n")
        return 0

    if args.file is None:
        parser.error("missing file path")

    path = pathlib.Path(args.file).resolve()
    if not path.exists():
        print(f"File not found: {path}", file=sys.stderr)
        return 1

    mode = args.mode
    if args.mixed:
        mode = "mixed"
    elif args.auto:
        mode = "auto"
    elif args.semantic:
        mode = "semantic"
    elif args.treesitter:
        mode = "treesitter"

    try:
        result = highlight(path, mode)
    except RuntimeError as err:
        print(str(err), file=sys.stderr)
        return 2

    if args.pretty:
        result = _replace_ligatures(result)

    sys.stdout.write(result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
