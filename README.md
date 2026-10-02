# SubSource Subtitle Plugin for mpv

Search and download subtitles directly from [subsource.net](https://subsource.net) inside **mpv**.

> [!NOTE]
> **Credits & Origin**: Huge thanks to **[Mark Pashmfouroush (@markpash)](https://github.com/markpash)** for the original idea and plugin concept!

---

## Features

- 🔍 **Smart Title Detection**: Intelligently parses scene filenames into show/movie title, release year, season, and episode number.
- ⚡ **Seamless mpv Integration**: Native **[uosc](https://github.com/tomasklaen/uosc)** menu integration with built-in interactive OSD menu fallback.
- 📦 **Season Pack Handling**: Automatically unzips archives and picks the exact file for the episode you are currently watching.
- 🌍 **Multi-Language**: Supports 100+ languages by SubSource slug or ISO-639 codes (e.g. `english`, `en`, `farsi_persian`, `fa`, `spanish`, `es`, `all`).
- 🚀 **One-Key Auto-Download**: Optional auto-download mode to automatically grab the highest-ranked subtitle match.
- 💾 **Save to Disk or Stream**: Load directly into player memory or optionally save `.srt` files alongside video files.

---

## Requirements

- `mpv` (v0.33+)
- `curl` and `unzip` (standard on modern Linux, macOS, and Windows)
- A free SubSource account and API key from [subsource.net/profile](https://subsource.net/profile)

---

## Installation

### Quick Install (Linux / macOS)

Clone this repository and run the installer script:

```bash
git clone https://github.com/BEST8OY/mpv-plugin-subsource mpv-plugin-subsource
cd mpv-subsource
./scripts/install.sh
```

### Manual Install

1. Copy `subsource.lua` into your mpv scripts directory:
   - **Linux / macOS**: `~/.config/mpv/scripts/subsource.lua`
   - **Windows**: `%APPDATA%/mpv/scripts/subsource.lua`
2. Copy `subsource.conf` into your mpv script options directory:
   - **Linux / macOS**: `~/.config/mpv/script-opts/subsource.conf`
   - **Windows**: `%APPDATA%/mpv/script-opts/subsource.conf`

---

## Configuration

Edit `~/.config/mpv/script-opts/subsource.conf` (or set the `SUBSOURCE_API_KEY` environment variable):

```ini
# SubSource API key (obtain from https://subsource.net/profile)
api_key=your_api_key_here

# Preferred languages (comma-separated). SubSource slugs or ISO-639 codes (e.g. "english", "en,fa", "all")
languages=english

# Subtitle sort order: popular, newest, rating, oldest
sort=popular

# Hearing impaired filter: include, exclude, only
hearing_impaired=include

# Automatically download and apply top match without showing menu
auto_load=no

# Automatically search SubSource when any video file is opened
auto_search=no

# Filter subtitles by episode when watching a TV series
episode_filter=yes

# Save subtitles to disk alongside the video file (e.g. Video.Name.en.srt)
save_to_disk=no

# Optional custom directory to save downloaded subtitles (e.g. ~/subtitles)
sub_dir=

# Menu UI mode: "auto" (detects uosc, falls back to native OSD), "yes" (force uosc), "no" (native OSD)
uosc=auto

# Maximum number of search results to display per query
max_results=50

# Request timeout in seconds
timeout=20

# Enable debug logging in mpv terminal/console
debug=no
```

---

## Keybindings & Usage

| Key / Binding | Action |
| --- | --- |
| `b` | Open SubSource search menu for the currently playing video |
| `script-binding subsource/search` | Open subtitle search menu |
| `script-binding subsource/download-top` | Directly download and select top subtitle match |
| `script-binding subsource/manual-search` | Manual title search prompt (search palette in uosc) |

In your `input.conf`, you can customize keybindings:

```ini
# Custom keybinding examples:
b           script-binding subsource/search
ctrl+alt+s  script-binding subsource/download-top
```

### Menu Navigation (Native OSD Fallback)

If `uosc` is not installed, an interactive OSD menu is displayed:
- `↑` / `k` : Move up
- `↓` / `j` : Move down
- `Enter` : Select item / download
- `←` / `→` : Change page
- `Esc` / `q` : Close menu

---

## Testing

Run the test suite (luac syntax check, pure Lua unit tests, and mpv load test):

```bash
./test/test.sh
```

---

## Acknowledgments

- **[Mark Pashmfouroush (@markpash)](https://github.com/markpash)**: Conceived the original idea and plugin concept.
- **[SubSource](https://subsource.net)**: Subtitle database and API.
- **[uosc](https://github.com/tomasklaen/uosc)**: Beautiful UI menu for mpv.

---

## License

[MIT](LICENSE)
