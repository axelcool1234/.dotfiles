import re

def mark(text, args, Mark, extra_cli_args, *a):
    query = extra_cli_args[0]
    escaped_query = re.escape(query)
    query_pattern = re.compile(escaped_query, re.IGNORECASE)

    offset = 0
    idx = 0
    for line in text.splitlines(keepends=True):
        if line.startswith("  "):
            for m in query_pattern.finditer(line):
                start, end = m.span()
                if start < 7: continue
                yield Mark(idx, offset + start, offset + end, line[start:end], {"index": idx})
                idx += 1
        offset += len(line)


def handle_result(args, data, target_window_id, boss, extra_cli_args, *a):
    matches, groupdicts = [], []
    for m, g in zip(data['match'], data['groupdicts']):
        if m:
            matches.append(m), groupdicts.append(g)

    w = boss.window_id_map.get(target_window_id)
    count = len(matches)
    for word, match_data in zip(matches, groupdicts):
        word = re.escape(word)
        text = f"gt8k46xs{word}\r{')' * match_data['index']},zz"
        boss.call_remote_control(self_window=w, args=("send-text", str(text)))
