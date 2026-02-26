import json
import os
import pathlib
import select
import shutil
import subprocess
import sys
import time


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


def _token_style(token_type, token_mods):
    # Lean's semantic token types follow LSP-style categories.
    # Palette intentionally sticks to Discord's ANSI subset.
    color_by_type = {
        "comment": "30",
        "keyword": "35",
        "string": "32",
        "number": "33",
        "regexp": "32",
        "operator": "37",
        "namespace": "36",
        "type": "36",
        "struct": "36",
        "class": "36",
        "interface": "36",
        "enum": "36",
        "typeParameter": "36",
        "function": "34",
        "method": "34",
        "macro": "34",
        "modifier": "35",
        "decorator": "35",
        "property": "33",
        "parameter": "36",
        "variable": "37",
        "enumMember": "33",
    }

    def ansi(format_codes, fg=None, bg=None):
        codes = []
        for code in format_codes:
            if code not in codes:
                codes.append(code)
        if fg is not None:
            codes.append(fg)
        if bg is not None:
            codes.append(bg)
        if not codes:
            return None
        return f"\x1b[{';'.join(codes)}m"

    if token_type == "leanSorryLike":
        # Make sorry/admit-like tokens unmistakable.
        return ansi(["1", "4"], fg="31", bg="40")

    color = color_by_type.get(token_type)
    if color is None and not token_mods:
        return None

    formats = []

    if "declaration" in token_mods or "definition" in token_mods:
        formats.append("1")

    if "readonly" in token_mods or "deprecated" in token_mods:
        formats.append("4")

    # Modifier-aware color nudges (like @lsp.typemod groups in nvim).
    if "deprecated" in token_mods:
        color = "31"
    elif "defaultLibrary" in token_mods and color in (None, "37"):
        color = "36"
    elif "documentation" in token_mods and color is None:
        color = "30"
    elif "modification" in token_mods and color in (None, "37"):
        color = "33"

    if color is None:
        color = "37"

    return ansi(formats, fg=color)


def _render_ansi(text, spans):
    if not spans:
        return text

    spans.sort(key=lambda s: (s[0], s[1]))
    out = []
    pos = 0
    for start, end, token_type, token_mods in spans:
        if start < pos:
            continue

        if start > pos:
            out.append(text[pos:start])

        style = _token_style(token_type, token_mods)
        segment = text[start:end]
        if style is None:
            out.append(segment)
        else:
            out.append(style)
            out.append(segment)
            out.append("\x1b[0m")
        pos = end

    if pos < len(text):
        out.append(text[pos:])
    return "".join(out)


def semantic_spans_for_file(path):
    path = pathlib.Path(path).resolve()
    if not path.exists():
        raise FileNotFoundError(f"File not found: {path}")

    text = path.read_text(encoding="utf-8")

    try:
        cmd, cwd = _pick_server(path)
    except RuntimeError as err:
        raise RuntimeError(str(err)) from err

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

        uri = path.as_uri()
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


def token_style_for_semantic(token_type, token_mods):
    return _token_style(token_type, token_mods)


def main():
    if len(sys.argv) < 2:
        print("Usage: semantic_highlight.py <file>", file=sys.stderr)
        return 1

    try:
        text, spans = semantic_spans_for_file(sys.argv[1])
        sys.stdout.write(_render_ansi(text, spans))
        return 0
    except FileNotFoundError as err:
        print(str(err), file=sys.stderr)
        return 1
    except RuntimeError as err:
        print(str(err), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
