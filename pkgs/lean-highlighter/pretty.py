import sys

# Mapping of ASCII sequences → Unicode ligatures
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
    "·":  "•",
    "*": "∗",
}

def replace_ligatures(text: str) -> str:
    for k in sorted(LIGATURES.keys(), key=len, reverse=True):
        text = text.replace(k, LIGATURES[k])
    return text

if __name__ == "__main__":
    content = sys.stdin.read()
    sys.stdout.write(replace_ligatures(content))