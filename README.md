# DiskWatch 🖥️

A TUI disk monitor for your Ubuntu server.  
Navigate physical disks → partitions → folders, all in the terminal.

```
  ██████╗ ██╗███████╗██╗  ██╗██╗    ██╗ █████╗ ████████╗ ██████╗██╗  ██╗
  ██╔══██╗██║██╔════╝██║ ██╔╝██║    ██║██╔══██╗╚══██╔══╝██╔════╝██║  ██║
  ██║  ██║██║███████╗█████╔╝ ██║ █╗ ██║███████║   ██║   ██║     ███████║
  ██║  ██║██║╚════██║██╔═██╗ ██║███╗██║██╔══██║   ██║   ██║     ██╔══██║
  ██████╔╝██║███████║██║  ██╗╚███╔███╔╝██║  ██║   ██║   ╚██████╗██║  ██║
  ╚═════╝ ╚═╝╚══════╝╚═╝  ╚═╝ ╚══╝╚══╝ ╚═╝  ╚═╝  ╚═╝    ╚═════╝╚═╝  ╚═╝
```

---

## Navigation

| Key | Action |
|-----|--------|
| `↑` / `↓` | Move between rows |
| `Enter` | Open disk → partition → folder |
| `Esc` / `q` | Go back / Quit |
| `r` | Refresh data |

## Screens

```

<img width="922" height="326" alt="image" src="https://github.com/user-attachments/assets/3351e0a0-7e0b-484b-a7e5-b406d7e8e662" />

Main screen (physical disks)
 └─ Partition screen (partitions of the selected disk)
      └─ Folder browser (du-based folder tree)
           └─ Sub-folder browser (navigate deeper)
```

---

## Dev Environment (Docker)

### Prerequisites
- Docker + Docker Compose installed on your server

### Setup

### **Installing on any server**

- apt install pipx
- pipx install diskwatch
- diskwatch
- source ~/.bashrc


```bash
# 1. Clone / copy the project
cd /opt
git clone ... diskwatch   # or scp from your machine
cd diskwatch

# 2. Make the launcher executable
chmod +x dev.sh

# 3. Build the image (~1 minute)
./dev.sh build

# 4. Enter the dev shell
./dev.sh run
# You are now inside the container ↓

# 5. Run DiskWatch
python diskwatch.py
```

### Live editing
The `./app/` folder is mounted into the container at `/app`.  
Edit `diskwatch.py` on your host with any editor, and re-run `python diskwatch.py` inside the container — no rebuild needed.

### Run without entering the shell
```bash
./dev.sh watch
```

---

## Install directly on the server (no Docker)

```bash
# Python 3.10+ required
pip install textual psutil rich

# Run
python /path/to/diskwatch.py
```

To make it available as a command:

```bash
sudo cp app/diskwatch.py /usr/local/bin/diskwatch
sudo chmod +x /usr/local/bin/diskwatch

# Then just type:
diskwatch
```

---

## Project structure

```
diskwatch/
├── app/
│   ├── diskwatch.py       ← The entire TUI app
│   └── requirements.txt   ← Python dependencies
├── Dockerfile             ← Dev container definition
├── docker-compose.yml     ← Docker Compose config
├── dev.sh                 ← Helper launcher script
└── README.md
```

---

## Color legend

| Color | Meaning |
|-------|---------|
| 🟢 Green | Usage below 70% — all good |
| 🟡 Yellow | Usage 70–90% — getting full |
| 🔴 Red | Usage above 90% — critical |
