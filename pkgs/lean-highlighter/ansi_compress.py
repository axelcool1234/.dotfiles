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

def triplets(tokens):
    merged = []
    i = 0
    while i < len(tokens):
        k0, v0 = tokens[i]
        if k0 == "text":
            merged.append((None, v0, None))
            i += 1
            continue
        k1, v1 = tokens[i + 1]
        k2, v2 = tokens[i + 2]
        if k0 == "style" and k1 == "text" and k2 == "reset":
            merged.append((v0, v1, v2))
            i += 3
    return merged

def merge_adjacent_triplets(triplets):
    if not triplets:
        return []

    merged = [triplets[0]]

    for style, text, reset in triplets[1:]:
        last_style, last_text, last_reset = merged[-1]

        if style == last_style or style is None or last_style is None:
            # Pick the non-None style to preserve actual styling
            new_style = style if style is not None else last_style
            # Merge text
            merged[-1] = (new_style, last_text + text, last_reset)
        else:
            merged.append((style, text, reset))

    return merged

def rebuild(triplets):
    out = []
    for style, text, reset in triplets:
        if style:
            out.append(style)
        out.append(text)
        if reset:
            out.append(reset)
    return "".join(out)

def main():
    content = sys.stdin.read()
    tokens = tokenize(content)
    compressed = compress_styles(tokens)
    triples = triplets(compressed)
    merged_triples = merge_adjacent_triplets(triples)
    final = rebuild(merged_triples)
    sys.stdout.write(final)

if __name__ == "__main__":
    main()
