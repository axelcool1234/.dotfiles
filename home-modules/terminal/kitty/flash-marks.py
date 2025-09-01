from kitty.boss import Boss
import sys
import termios
import tty

# Old implementation, doesn't show terminal content (overlay window is just blank)
# def read_n_chars(n: int) -> str:
#     fd = sys.stdin.fileno()
#     old_settings = termios.tcgetattr(fd)
#     try:
#         tty.setraw(fd)  # put terminal in raw mode
#         chars = []
#         for _ in range(n):
#             ch = sys.stdin.read(1)
#             chars.append(ch)
#         return ''.join(chars)
#     finally:
#         termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)

# def main(args: list[str]) -> str:
#     # print("flash.nvim search: ", end="", flush=True)
#     print("args: ", args)
#     query = read_n_chars(2)  # read 2 characters immediately
#     return query

def read_n_chars_from_terminal(n: int) -> str:
    with open("/dev/tty", "rb") as tty_fd:
        fd = tty_fd.fileno()
        old_settings = termios.tcgetattr(fd)
        try:
            tty.setraw(fd)
            chars = [tty_fd.read(1).decode("utf-8") for _ in range(n)]
            return "".join(chars)
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)

def main(args: list[str]) -> str:
    # Print the content of the terminal to this overlay so it looks somewhat seamless
    terminal_content = sys.stdin.read()
    print(terminal_content, end="", flush=True)

    # now read 2 raw characters from the terminal
    query = read_n_chars_from_terminal(2)
    return query

# This decorator makes it so the stdin of main is the kitty terminal's content (and thus I can display it).
from kittens.tui.handler import result_handler
@result_handler(type_of_input='text')
def handle_result(args: list[str], query: str, target_window_id: int, boss: Boss) -> None:
    boss.call_remote_control(
        boss.window_id_map.get(target_window_id),
        (
            "kitten",
            "hints",
            "--customize-processing",
            "custom-hints.py",
            "--",
            query
        ),
    )