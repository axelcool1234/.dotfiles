#!/usr/bin/env python3
"""Collect a bounded, read-only health snapshot of the running NixOS system."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import time
from typing import Any, Iterable


DEFAULT_SYSTEM_SERVICES = (
    "greetd.service",
    "bluetooth.service",
    "NetworkManager.service",
)

DEFAULT_USER_SERVICES = (
    "niri.service",
    "noctalia.service",
    "xdg-desktop-portal.service",
    "pipewire.service",
    "wireplumber.service",
)

SIGNAL_SPECS = (
    (
        "greetd.service",
        False,
        (
            "error",
            "failed",
            "fatal",
            "gkr-pam",
            "greeter",
            "output",
            "scale",
            "gpu",
            "drm",
            "egl",
            "session opened",
        ),
    ),
    (
        "niri.service",
        True,
        (
            "error",
            "failed",
            "fatal",
            "warn",
            "output",
            "client communication",
            "wp_presentation",
        ),
    ),
    (
        "noctalia.service",
        True,
        (
            "error",
            "failed",
            "fatal",
            "warn",
            "restart",
            "secret-store",
            "wp_presentation",
            "bluetooth",
            "wayland] output",
            "app] noctalia",
        ),
    ),
)

CRASH_PATTERNS = (
    "out of memory",
    "oom-kill",
    "segfault",
    "general protection fault",
    "kernel panic",
    "watchdog",
    "soft lockup",
    "hard lockup",
    "i/o error",
    "blk_update_request",
    "nvme timeout",
    "nvrm: xid",
    "gpu reset",
    "machine check",
    "mce:",
    "corruption",
    "read-only file system",
)

KERNEL_TAINT_BITS = {
    0: "proprietary-module",
    1: "forced-module-load",
    2: "cpu-out-of-spec",
    3: "forced-module-unload",
    4: "machine-check",
    5: "bad-page",
    6: "user-requested",
    7: "kernel-died",
    8: "acpi-override",
    9: "kernel-warning",
    10: "staging-driver",
    11: "firmware-workaround",
    12: "out-of-tree-module",
    13: "unsigned-module",
    14: "soft-lockup",
    15: "live-patch",
    16: "auxiliary-taint",
    17: "randstruct",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Collect system identity, generations, unit state, boot warnings, "
            "and desktop hardware signals as JSON. The command never mutates state."
        )
    )
    parser.add_argument(
        "--journal-lines",
        type=int,
        default=600,
        help="maximum journal lines to inspect per query (default: 600)",
    )
    parser.add_argument(
        "--system-service",
        action="append",
        default=[],
        metavar="UNIT",
        help="add a system service to inspect (repeatable)",
    )
    parser.add_argument(
        "--user-service",
        action="append",
        default=[],
        metavar="UNIT",
        help="add a user service to inspect (repeatable)",
    )
    parser.add_argument(
        "--no-default-services",
        action="store_true",
        help="inspect only services supplied on the command line",
    )
    parser.add_argument(
        "--compact",
        action="store_true",
        help="emit compact JSON",
    )
    args = parser.parse_args()
    if args.journal_lines < 1:
        parser.error("--journal-lines must be positive")
    return args


def unique(items: Iterable[str]) -> list[str]:
    return list(dict.fromkeys(items))


def command_result(command: list[str], timeout: int = 20) -> dict[str, Any]:
    executable = shutil.which(command[0])
    if executable is None:
        return {
            "command": command,
            "available": False,
            "returncode": None,
            "stdout": "",
            "stderr": f"{command[0]} was not found in PATH",
            "timed_out": False,
        }

    environment = os.environ.copy()
    environment.update(
        {
            "NO_COLOR": "1",
            "SYSTEMD_COLORS": "0",
            "SYSTEMD_PAGER": "cat",
        }
    )

    try:
        completed = subprocess.run(
            [executable, *command[1:]],
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
            env=environment,
        )
        return {
            "command": command,
            "available": True,
            "returncode": completed.returncode,
            "stdout": completed.stdout.rstrip(),
            "stderr": completed.stderr.rstrip(),
            "timed_out": False,
        }
    except subprocess.TimeoutExpired as error:
        stdout = error.stdout.decode() if isinstance(error.stdout, bytes) else error.stdout
        stderr = error.stderr.decode() if isinstance(error.stderr, bytes) else error.stderr
        return {
            "command": command,
            "available": True,
            "returncode": None,
            "stdout": (stdout or "").rstrip(),
            "stderr": (stderr or "").rstrip(),
            "timed_out": True,
        }


def read_text(path: str) -> str | None:
    try:
        return Path(path).read_text(encoding="utf-8").strip()
    except (OSError, UnicodeError):
        return None


def resolved_path(path: str) -> str | None:
    try:
        return str(Path(path).resolve(strict=True))
    except OSError:
        return None


def unit_state(units: list[str], user: bool) -> dict[str, Any]:
    if not units:
        return {
            "command": [],
            "available": True,
            "returncode": 0,
            "stdout": "",
            "stderr": "",
            "timed_out": False,
            "skipped": "no units selected",
        }
    command = ["systemctl"]
    if user:
        command.append("--user")
    command.extend(
        [
            "show",
            *units,
            "--property=Id,LoadState,ActiveState,SubState,NRestarts,ExecMainStatus,MainPID,ActiveEnterTimestamp",
        ]
    )
    return command_result(command)


def parse_property_blocks(output: str) -> list[dict[str, str]]:
    blocks = []
    for raw_block in output.split("\n\n"):
        block = {}
        for line in raw_block.splitlines():
            key, separator, value = line.partition("=")
            if separator:
                block[key] = value
        if block:
            blocks.append(block)
    return blocks


def result_status(result: dict[str, Any]) -> dict[str, Any]:
    summary = dict(result)
    summary.pop("stdout", None)
    summary.pop("command", None)
    return summary


def service_inventory(user: bool) -> dict[str, Any]:
    list_command = ["systemctl"]
    if user:
        list_command.append("--user")
    list_command.extend(
        ["list-units", "--type=service", "--all", "--no-legend", "--plain"]
    )
    listed = command_result(list_command)
    units = unique(
        line.split(maxsplit=1)[0]
        for line in listed["stdout"].splitlines()
        if line.strip() and line.split(maxsplit=1)[0].endswith(".service")
    )

    if not units:
        return {
            "listed_count": 0,
            "anomalies": [],
            "list_query": result_status(listed),
        }

    states = unit_state(units, user=user)
    blocks = parse_property_blocks(states["stdout"])
    anomalies = []
    for block in blocks:
        try:
            restarts = int(block.get("NRestarts", "0"))
        except ValueError:
            restarts = 0
        failed = block.get("ActiveState") == "failed" or block.get("SubState") == "failed"
        # list-units can contain not-found aliases and generated compatibility
        # names. They are not evidence of a fault unless they failed or restarted.
        if failed or restarts > 0:
            anomalies.append(block)

    return {
        "listed_count": len(units),
        "anomalies": anomalies,
        "list_query": result_status(listed),
        "state_query": result_status(states),
    }


def anomaly_journals(
    inventory: dict[str, Any], user: bool, journal_lines: int
) -> dict[str, Any]:
    journals = {}
    for anomaly in inventory.get("anomalies", [])[:20]:
        unit = anomaly.get("Id")
        if not unit:
            continue
        command = ["journalctl"]
        if user:
            command.append("--user")
        command.extend(
            [
                "--boot",
                "--unit",
                unit,
                "--lines",
                str(min(journal_lines, 80)),
                "--no-pager",
                "--output=short-iso-precise",
            ]
        )
        journals[unit] = command_result(command)
    return journals


def journal_signals(
    unit: str,
    user: bool,
    patterns: tuple[str, ...],
    journal_lines: int,
) -> dict[str, Any]:
    command = ["journalctl"]
    if user:
        command.append("--user")
    command.extend(
        [
            "--boot",
            "--unit",
            unit,
            "--lines",
            str(journal_lines),
            "--no-pager",
            "--output=short-iso-precise",
        ]
    )
    result = command_result(command)
    raw_output = result.pop("stdout")
    folded_patterns = tuple(pattern.casefold() for pattern in patterns)
    matches = [
        line
        for line in raw_output.splitlines()
        if any(pattern in line.casefold() for pattern in folded_patterns)
    ]
    result["patterns"] = list(patterns)
    result["match_count"] = len(matches)
    result["matches"] = matches[-200:]
    result["matches_truncated"] = len(matches) > 200
    return result


def boot_signals(patterns: tuple[str, ...], journal_lines: int) -> dict[str, Any]:
    result = command_result(
        [
            "journalctl",
            "--boot",
            "--lines",
            str(journal_lines),
            "--no-pager",
            "--output=short-iso-precise",
        ],
        timeout=30,
    )
    raw_output = result.pop("stdout")
    folded_patterns = tuple(pattern.casefold() for pattern in patterns)
    matches = [
        line
        for line in raw_output.splitlines()
        if any(pattern in line.casefold() for pattern in folded_patterns)
    ]
    result["patterns"] = list(patterns)
    result["match_count"] = len(matches)
    result["matches"] = matches[-200:]
    result["matches_truncated"] = len(matches) > 200
    return result


def kernel_taint() -> dict[str, Any]:
    raw_value = read_text("/proc/sys/kernel/tainted")
    if raw_value is None:
        return {"value": None, "reasons": [], "readable": False}
    try:
        value = int(raw_value)
    except ValueError:
        return {"value": raw_value, "reasons": [], "readable": False}
    reasons = [
        reason for bit, reason in KERNEL_TAINT_BITS.items() if value & (1 << bit)
    ]
    return {"value": value, "reasons": reasons, "readable": True}


def zombie_processes() -> dict[str, Any]:
    result = command_result(["ps", "-eo", "stat=,pid=,ppid=,comm="])
    raw_output = result.pop("stdout")
    zombies = [
        line.strip()
        for line in raw_output.splitlines()
        if line.lstrip().startswith("Z")
    ]
    result["count"] = len(zombies)
    result["processes"] = zombies
    return result


def optional_command(command: list[str], timeout: int = 20) -> dict[str, Any]:
    return command_result(command, timeout=timeout)


def coredumps_since_boot(uptime_seconds: float | None) -> dict[str, Any]:
    command = ["coredumpctl", "--no-pager", "--no-legend"]
    if uptime_seconds is not None:
        # coredumpctl has no portable --boot switch. A boot-time lower bound is
        # close enough for this bounded diagnostic snapshot.
        boot_epoch = max(0, int(time.time() - uptime_seconds) - 2)
        command.append(f"--since=@{boot_epoch}")
    command.extend(["--reverse", "-n", "50", "list"])
    return command_result(command, timeout=30)


def niri_outputs() -> dict[str, Any]:
    result = optional_command(["niri", "msg", "outputs"])
    if result["returncode"] != 0:
        return result

    # Available mode enumerations can dominate the report while adding little
    # diagnostic value. Preserve each output's current mode and layout fields.
    concise_lines = []
    omitting_modes = False
    for line in result["stdout"].splitlines():
        if line.strip() == "Available modes:":
            omitting_modes = True
            continue
        if omitting_modes and line.startswith("Output "):
            omitting_modes = False
        if not omitting_modes:
            concise_lines.append(line)
    result["stdout"] = "\n".join(concise_lines).rstrip()
    result["available_modes_omitted"] = True
    return result


def main() -> int:
    args = parse_args()
    default_system = () if args.no_default_services else DEFAULT_SYSTEM_SERVICES
    default_user = () if args.no_default_services else DEFAULT_USER_SERVICES
    system_services = unique((*default_system, *args.system_service))
    user_services = unique((*default_user, *args.user_service))

    system_failed = command_result(
        ["systemctl", "--failed", "--no-legend", "--plain"]
    )
    user_failed = command_result(
        ["systemctl", "--user", "--failed", "--no-legend", "--plain"]
    )
    system_inventory = service_inventory(user=False)
    user_inventory = service_inventory(user=True)

    boot_warnings = command_result(
        [
            "journalctl",
            "--boot",
            "--priority=0..4",
            "--lines",
            str(args.journal_lines),
            "--no-pager",
            "--output=short-iso-precise",
        ],
        timeout=30,
    )

    uptime = read_text("/proc/uptime")
    uptime_seconds = None
    if uptime:
        try:
            uptime_seconds = float(uptime.split()[0])
        except (IndexError, ValueError):
            pass

    report: dict[str, Any] = {
        "schema_version": 1,
        "collector": {
            "name": "system-health-check",
            "collected_at": dt.datetime.now().astimezone().isoformat(),
            "read_only": True,
            "journal_line_limit": args.journal_lines,
        },
        "identity": {
            "hostname": socket.gethostname(),
            "kernel_release": os.uname().release,
            "nixos_version": command_result(["nixos-version"]),
            "boot_id": read_text("/proc/sys/kernel/random/boot_id"),
            "uptime_seconds": uptime_seconds,
            "session_id": os.environ.get("XDG_SESSION_ID"),
            "session_type": os.environ.get("XDG_SESSION_TYPE"),
            "current_desktop": os.environ.get("XDG_CURRENT_DESKTOP"),
            "wayland_display": os.environ.get("WAYLAND_DISPLAY"),
        },
        "generations": {
            "booted_system": resolved_path("/run/current-system"),
            "profile_system": resolved_path("/nix/var/nix/profiles/system"),
            "match": resolved_path("/run/current-system")
            == resolved_path("/nix/var/nix/profiles/system"),
        },
        "systemd": {
            "system_state": command_result(["systemctl", "is-system-running"]),
            "system_failed_units": system_failed,
            "user_failed_units": user_failed,
            "system_services": unit_state(system_services, user=False),
            "user_services": unit_state(user_services, user=True),
            "system_service_inventory": system_inventory,
            "user_service_inventory": user_inventory,
            "system_anomaly_journals": anomaly_journals(
                system_inventory, user=False, journal_lines=args.journal_lines
            ),
            "user_anomaly_journals": anomaly_journals(
                user_inventory, user=True, journal_lines=args.journal_lines
            ),
        },
        "boot": {
            "priority_0_to_4": boot_warnings,
            "crash_signals": boot_signals(CRASH_PATTERNS, args.journal_lines),
            "coredumps": coredumps_since_boot(uptime_seconds),
            "timing": optional_command(["systemd-analyze", "time"]),
        },
        "resources": {
            "load_average": read_text("/proc/loadavg"),
            "memory": optional_command(["free", "--bytes"]),
            "swap": optional_command(["swapon", "--show", "--bytes"]),
            "persistent_filesystems": optional_command(
                [
                    "df",
                    "--output=source,fstype,size,used,avail,pcent,target",
                    "--block-size=1",
                    "--exclude-type=tmpfs",
                    "--exclude-type=devtmpfs",
                ]
            ),
            "zombie_processes": zombie_processes(),
        },
        "kernel": {
            "command_line": read_text("/proc/cmdline"),
            "taint": kernel_taint(),
        },
        "network": {
            "addresses": optional_command(["ip", "--brief", "address"]),
            "routes": optional_command(["ip", "route"]),
            "time_sync": optional_command(["timedatectl", "status"]),
            "dns": optional_command(["resolvectl", "status"]),
            "resolv_conf": read_text("/etc/resolv.conf"),
        },
        "hardware": {
            "block_devices": optional_command(
                [
                    "lsblk",
                    "--json",
                    "--output",
                    "NAME,SIZE,TYPE,FSTYPE,LABEL,PARTLABEL",
                ]
            ),
            "root_mount": optional_command(["findmnt", "--json", "/"]),
            "rfkill": optional_command(["rfkill", "--json"]),
            "bluetooth_controller": optional_command(["bluetoothctl", "show"]),
        },
        "desktop": {
            "niri_outputs": niri_outputs(),
            "secret_service_login_locked": optional_command(
                [
                    "busctl",
                    "--user",
                    "get-property",
                    "org.freedesktop.secrets",
                    "/org/freedesktop/secrets/collection/login",
                    "org.freedesktop.Secret.Collection",
                    "Locked",
                ]
            ),
            "secret_service_default_locked": optional_command(
                [
                    "busctl",
                    "--user",
                    "get-property",
                    "org.freedesktop.secrets",
                    "/org/freedesktop/secrets/aliases/default",
                    "org.freedesktop.Secret.Collection",
                    "Locked",
                ]
            ),
        },
        "signals": {
            unit: journal_signals(unit, user, patterns, args.journal_lines)
            for unit, user, patterns in SIGNAL_SPECS
        },
    }

    json.dump(
        report,
        fp=os.sys.stdout,
        indent=None if args.compact else 2,
        sort_keys=True,
    )
    os.sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
