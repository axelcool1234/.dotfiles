import sys
import re

ANSI_RE = re.compile(r'\x1b\[(.*?)m')

def tokenize(text):
    """Tokenizes into (kind, value) where kind is 'text', 'reset', or 'style'."""
    tokens = []
    last_end = 0
    for m in ANSI_RE.finditer(text):
        if m.start() > last_end:
            tokens.append(("text", text[last_end:m.start()]))
        seq = m.group(1)
        if seq == "0":
            tokens.append(("reset", "\x1b[0m"))
        else:
            tokens.append(("style", seq))
        last_end = m.end()
    if last_end < len(text):
        tokens.append(("text", text[last_end:]))
    return tokens

def compress_styles(tokens):
    """Compress consecutive style codes, simplifying 38;5;X -> X."""
    result = []
    i = 0
    while i < len(tokens):
        kind, val = tokens[i]

        if kind == "style":
            styles = [val]
            j = i + 1
            while j < len(tokens) and tokens[j][0] == "style":
                styles.append(tokens[j][1])
                j += 1

            # Gather parameters
            parts = []
            for s in styles:
                seq_parts = s.split(";")
                # Special case: color like 38;5;X
                if len(seq_parts) == 3 and seq_parts[0] == "38" and seq_parts[1] == "5":
                    parts.append(seq_parts[-1])  # keep just X
                else:
                    parts.extend(seq_parts)

            compressed = f"\x1b[{';'.join(parts)}m"
            result.append(("style", compressed))
            i = j
        else:
            result.append((kind, val))
            i += 1
    return result

def rebuild(tokens):
    """Rebuilds string from tokens."""
    out = []
    for kind, val in tokens:
        if kind == "text":
            out.append(val)
        elif kind == "reset":
            out.append("\x1b[0m")
        elif kind == "style":
            if not val.startswith("\x1b["):
                out.append(f"\x1b[{val}m")
            else:
                out.append(val)
    return "".join(out)


def main():
    # if len(sys.argv) != 2:
    #     print(f"Usage: {sys.argv[0]} <file>")
    #     sys.exit(1)

    # filepath = sys.argv[1]

    # with open(filepath, "r", encoding="utf-8") as f:
    #     content = f.read()

    # tokens = tokenize(content)
    # compressed = compress_styles(tokens)
    # final = rebuild(compressed)

    # with open(filepath, "w", encoding="utf-8") as f:
    #     f.write(final)
    # 
    # 
    content = sys.stdin.read()
    tokens = tokenize(content)
    compressed = compress_styles(tokens)
    final = rebuild(compressed)
    sys.stdout.write(final)

if __name__ == "__main__":
    main()
