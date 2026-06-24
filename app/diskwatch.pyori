#!/usr/bin/env python3
"""
DiskWatch - A Veeam-style TUI for disk usage monitoring
"""

import os
import shutil
import subprocess
from pathlib import Path
from typing import Optional

import psutil
from rich.text import Text
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Container, Horizontal, Vertical
from textual.reactive import reactive
from textual.screen import Screen
from textual.widget import Widget
from textual.widgets import (
    DataTable,
    Footer,
    Header,
    Label,
    Static,
)


# ─── Helpers ──────────────────────────────────────────────────────────────────

def bytes_to_human(n: int) -> str:
    """Convert bytes to human-readable Go/To."""
    if n < 0:
        return "N/A"
    for unit in ("o", "Ko", "Mo", "Go", "To"):
        if abs(n) < 1024.0:
            return f"{n:,.1f} {unit}"
        n /= 1024.0
    return f"{n:.1f} Po"


def usage_bar(percent: float, width: int = 20) -> Text:
    """Render a colored ASCII progress bar."""
    filled = int(width * percent / 100)
    bar = "█" * filled + "░" * (width - filled)
    if percent >= 90:
        color = "bold red"
    elif percent >= 70:
        color = "bold yellow"
    else:
        color = "bold green"
    t = Text()
    t.append(f"[{bar}] ", style=color)
    t.append(f"{percent:5.1f}%", style=color)
    return t


def get_physical_disks() -> list[dict]:
    """
    Return one entry per physical disk (e.g. /dev/sda, /dev/nvme0n1).
    We group partitions by their parent disk and aggregate usage.
    """
    # Map partition device → mountpoint for disks that are mounted
    mounted = {}
    for part in psutil.disk_partitions(all=False):
        try:
            usage = psutil.disk_usage(part.mountpoint)
            mounted[part.device] = {
                "mountpoint": part.mountpoint,
                "total": usage.total,
                "used": usage.used,
                "free": usage.free,
                "percent": usage.percent,
            }
        except (PermissionError, OSError):
            pass

    # Use lsblk to get the disk → partition → mountpoint tree
    try:
        result = subprocess.run(
            ["lsblk", "-Jbo", "NAME,TYPE,SIZE,MOUNTPOINT,PKNAME"],
            capture_output=True, text=True, check=True
        )
        import json
        data = json.loads(result.stdout)
        devices = data.get("blockdevices", [])
    except Exception:
        devices = []

    disks = []
    for dev in devices:
        if dev.get("type") != "disk":
            continue

        name = dev["name"]           # e.g. sda
        disk_path = f"/dev/{name}"
        size_bytes = int(dev.get("size", 0))

        # Collect all partitions / children (recursive)
        children = dev.get("children", []) or []
        # Flatten nested children (LVM, etc.)
        def flatten(nodes):
            for n in nodes:
                yield n
                for child in flatten(n.get("children", []) or []):
                    yield child

        partitions = []
        total_used = 0
        total_free = 0
        mountpoints = []

        for child in flatten(children):
            devpath = f"/dev/{child['name']}"
            mount = child.get("mountpoint") or ""
            if mount:
                mountpoints.append(mount)
            # Try to get usage from psutil
            info = mounted.get(devpath)
            if info:
                total_used += info["used"]
                total_free += info["free"]
                partitions.append({
                    "device": devpath,
                    "mountpoint": info["mountpoint"],
                    "total": info["total"],
                    "used": info["used"],
                    "free": info["free"],
                    "percent": info["percent"],
                })

        # Fallback: if no partition info found, use disk size only
        if not partitions:
            total_used = 0
            total_free = size_bytes

        total_used_final = total_used
        total_free_final = total_free
        total_all = total_used_final + total_free_final if (total_used_final + total_free_final) > 0 else size_bytes
        percent = (total_used_final / total_all * 100) if total_all > 0 else 0.0

        disks.append({
            "name": name,
            "device": disk_path,
            "size": size_bytes,
            "total": total_all,
            "used": total_used_final,
            "free": total_free_final,
            "percent": percent,
            "mountpoints": mountpoints,
            "partitions": partitions,
        })

    return disks


def get_folder_sizes(path: str, max_entries: int = 50) -> list[dict]:
    """
    Return top-level folder sizes inside `path` using du.
    Fast, uses the OS tool directly.
    """
    try:
        result = subprocess.run(
            ["du", "-xb", "--max-depth=1", path],
            capture_output=True, text=True, timeout=60
        )
        entries = []
        for line in result.stdout.splitlines():
            parts = line.split("\t", 1)
            if len(parts) != 2:
                continue
            size_bytes = int(parts[0])
            folder = parts[1].strip()
            if folder == path:
                continue
            entries.append({
                "path": folder,
                "name": os.path.basename(folder) or folder,
                "size": size_bytes,
                "is_dir": os.path.isdir(folder),
            })
        entries.sort(key=lambda x: x["size"], reverse=True)
        return entries[:max_entries]
    except Exception as e:
        return [{"path": path, "name": f"Error: {e}", "size": 0, "is_dir": False}]


# ─── Screens ──────────────────────────────────────────────────────────────────

class SummaryBar(Static):
    """Top banner showing selected disk summary."""

    def __init__(self, disk: dict, **kwargs):
        super().__init__(**kwargs)
        self._disk = disk

    def compose(self) -> ComposeResult:
        d = self._disk
        bar = usage_bar(d["percent"], width=30)
        line = Text()
        line.append(f"  {d['device']}  ", style="bold cyan")
        line.append(f"Total: {bytes_to_human(d['total'])}  ", style="white")
        line.append(f"Used: {bytes_to_human(d['used'])}  ", style="yellow")
        line.append(f"Free: {bytes_to_human(d['free'])}  ", style="green")
        line.append("  ")
        line.append_text(bar)
        yield Label(line)


class FolderBrowser(Screen):
    """Drill-down screen showing folder sizes for a given mountpoint."""

    BINDINGS = [
        Binding("q", "app.pop_screen", "Back"),
        Binding("escape", "app.pop_screen", "Back"),
        Binding("enter", "open_folder", "Open"),
        Binding("r", "refresh", "Refresh"),
    ]

    def __init__(self, disk: dict, mountpoint: str, **kwargs):
        super().__init__(**kwargs)
        self._disk = disk
        self._mountpoint = mountpoint
        self._current_path = mountpoint

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        yield SummaryBar(self._disk, id="summary-bar")
        with Container(id="path-container"):
            yield Label(id="current-path")
        yield DataTable(id="folder-table", cursor_type="row")
        yield Footer()

    def on_mount(self) -> None:
        self._setup_table()
        self._load_path(self._current_path)

    def _setup_table(self) -> None:
        table = self.query_one("#folder-table", DataTable)
        table.add_columns("  Type", "Name", "Size", "Bar")

    def _load_path(self, path: str) -> None:
        self.query_one("#current-path", Label).update(
            Text.assemble(("  📁 ", ""), (path, "bold cyan"))
        )
        table = self.query_one("#folder-table", DataTable)
        table.clear()

        entries = get_folder_sizes(path)
        # Add ".." navigation if not at mountpoint root
        if path != self._mountpoint:
            table.add_row("  ⬆", "..", "", "", key="__parent__")

        for entry in entries:
            icon = "  📁" if entry["is_dir"] else "  📄"
            size_str = bytes_to_human(entry["size"])

            # Make a mini bar relative to disk total
            pct = (entry["size"] / self._disk["total"] * 100) if self._disk["total"] > 0 else 0
            bar = usage_bar(min(pct * 5, 100), width=15)  # scale for visibility

            table.add_row(icon, entry["name"], size_str, bar, key=entry["path"])

    def action_open_folder(self) -> None:
        table = self.query_one("#folder-table", DataTable)
        if table.cursor_row < 0:
            return
        row_key = table.get_row_at(table.cursor_row)
        # row_key is a RowKey; get the actual key string via cursor_row
        # We'll track by matching row index to entries
        self._navigate_selected()

    def on_data_table_row_selected(self, event: DataTable.RowSelected) -> None:
        key = str(event.row_key.value)
        if key == "__parent__":
            parent = str(Path(self._current_path).parent)
            if self._current_path == self._mountpoint:
                return
            self._current_path = parent
            self._load_path(parent)
        elif os.path.isdir(key):
            self._current_path = key
            self._load_path(key)

    def _navigate_selected(self) -> None:
        table = self.query_one("#folder-table", DataTable)
        # Trigger via row selection simulation
        pass

    def action_refresh(self) -> None:
        self._load_path(self._current_path)


class PartitionScreen(Screen):
    """Shows partitions of a disk and allows entering a mountpoint."""

    BINDINGS = [
        Binding("q", "app.pop_screen", "Back"),
        Binding("escape", "app.pop_screen", "Back"),
    ]

    def __init__(self, disk: dict, **kwargs):
        super().__init__(**kwargs)
        self._disk = disk

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        yield SummaryBar(self._disk, id="summary-bar")
        with Container(id="info-container"):
            yield Label(
                Text.assemble(
                    ("  Partitions for ", ""),
                    (self._disk["device"], "bold cyan"),
                    ("  — press ", "dim"),
                    ("Enter", "bold white"),
                    (" to browse folders", "dim"),
                )
            )
        yield DataTable(id="partition-table", cursor_type="row")
        yield Footer()

    def on_mount(self) -> None:
        table = self.query_one("#partition-table", DataTable)
        table.add_columns("Partition", "Mountpoint", "Total", "Used", "Free", "Usage")

        for part in self._disk["partitions"]:
            bar = usage_bar(part["percent"], width=20)
            table.add_row(
                part["device"],
                part["mountpoint"],
                bytes_to_human(part["total"]),
                bytes_to_human(part["used"]),
                bytes_to_human(part["free"]),
                bar,
                key=part["mountpoint"],
            )

        if not self._disk["partitions"]:
            table.add_row("—", "No mounted partitions found", "—", "—", "—", "")

    def on_data_table_row_selected(self, event: DataTable.RowSelected) -> None:
        mountpoint = str(event.row_key.value)
        if mountpoint and os.path.isdir(mountpoint):
            self.app.push_screen(FolderBrowser(self._disk, mountpoint))


# ─── Main Screen ──────────────────────────────────────────────────────────────

TITLE_ART = """
  ██████╗ ██╗███████╗██╗  ██╗██╗    ██╗ █████╗ ████████╗ ██████╗██╗  ██╗
  ██╔══██╗██║██╔════╝██║ ██╔╝██║    ██║██╔══██╗╚══██╔══╝██╔════╝██║  ██║
  ██║  ██║██║███████╗█████╔╝ ██║ █╗ ██║███████║   ██║   ██║     ███████║
  ██║  ██║██║╚════██║██╔═██╗ ██║███╗██║██╔══██║   ██║   ██║     ██╔══██║
  ██████╔╝██║███████║██║  ██╗╚███╔███╔╝██║  ██║   ██║   ╚██████╗██║  ██║
  ╚═════╝ ╚═╝╚══════╝╚═╝  ╚═╝ ╚══╝╚══╝ ╚═╝  ╚═╝  ╚═╝    ╚═════╝╚═╝  ╚═╝
""".strip("\n")


class DiskWatchApp(App):
    """Main DiskWatch application."""

    CSS = """
    Screen {
        background: $surface;
    }

    #title-container {
        background: #0d1b2a;
        color: #00d4ff;
        padding: 1 2;
        border-bottom: solid #1e3a5f;
        height: auto;
    }

    #title-art {
        color: #00d4ff;
        text-style: bold;
    }

    #subtitle {
        color: #4a9ebb;
        margin-top: 1;
        padding-left: 2;
    }

    #disk-table {
        margin: 1 2;
        border: solid #1e3a5f;
        height: 1fr;
    }

    #status-bar {
        background: #0d1b2a;
        color: #4a9ebb;
        padding: 0 2;
        height: 1;
        border-top: solid #1e3a5f;
    }

    #summary-bar {
        background: #0d1b2a;
        padding: 0 1;
        height: 3;
        border-bottom: solid #1e3a5f;
    }

    #path-container {
        background: #111827;
        padding: 0 1;
        height: 3;
        border-bottom: solid #1e3a5f;
    }

    #info-container {
        background: #111827;
        padding: 0 1;
        height: 3;
        border-bottom: solid #1e3a5f;
    }

    #folder-table {
        margin: 1 2;
        border: solid #1e3a5f;
        height: 1fr;
    }

    #partition-table {
        margin: 1 2;
        border: solid #1e3a5f;
        height: 1fr;
    }

    DataTable > .datatable--header {
        background: #1e3a5f;
        color: #00d4ff;
        text-style: bold;
    }

    DataTable > .datatable--cursor {
        background: #1e5a8f;
    }

    Header {
        background: #0d1b2a;
        color: #00d4ff;
    }

    Footer {
        background: #0d1b2a;
        color: #4a9ebb;
    }
    """

    BINDINGS = [
        Binding("q", "quit", "Quit"),
        Binding("r", "refresh", "Refresh"),
        Binding("enter", "open_disk", "Open Disk"),
    ]

    TITLE = "DiskWatch"
    SUB_TITLE = "Storage Monitor"

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        with Container(id="title-container"):
            yield Static(TITLE_ART, id="title-art")
            yield Label("  Storage Monitor  •  Press Enter to explore a disk  •  R to refresh", id="subtitle")
        yield DataTable(id="disk-table", cursor_type="row")
        yield Footer()

    def on_mount(self) -> None:
        self._load_disks()

    def _load_disks(self) -> None:
        table = self.query_one("#disk-table", DataTable)
        table.clear(columns=True)
        table.add_columns(
            "  Device",
            "Disk",
            "Total",
            "Used",
            "Free",
            "Usage",
            "Mountpoints",
        )

        self._disks = get_physical_disks()
        for disk in self._disks:
            bar = usage_bar(disk["percent"], width=22)
            mounts = ", ".join(disk["mountpoints"]) if disk["mountpoints"] else "—"

            table.add_row(
                f"  {disk['device']}",
                disk["name"].upper(),
                bytes_to_human(disk["total"]),
                bytes_to_human(disk["used"]),
                bytes_to_human(disk["free"]),
                bar,
                mounts,
                key=disk["device"],
            )

    def action_refresh(self) -> None:
        self._load_disks()

    def action_open_disk(self) -> None:
        table = self.query_one("#disk-table", DataTable)
        if not hasattr(self, "_disks") or not self._disks:
            return
        idx = table.cursor_row
        if idx < 0 or idx >= len(self._disks):
            return
        disk = self._disks[idx]
        self.push_screen(PartitionScreen(disk))

    def on_data_table_row_selected(self, event: DataTable.RowSelected) -> None:
        # Only handle events from the main disk table
        if event.data_table.id == "disk-table":
            self.action_open_disk()


def main():
    app = DiskWatchApp()
    app.run()


if __name__ == "__main__":
    main()
