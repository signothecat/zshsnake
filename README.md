<img width="400" alt="title" src="https://github.com/user-attachments/assets/2200e15d-870f-4de9-88e9-1a58e4fb63dd" />

# zshsnake

**A retro snake game for your terminal**

<img src="https://github.com/user-attachments/assets/274ec216-55f1-4e37-9ec0-eaf1074db9ad" width="50%">

## Table of Contents
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
  - [Local Install](#local-install)
  - [Global Install](#global-install)
- [FAQ](#faq)
  - [How can I uninstall zshsnake?](#how-can-i-uninstall-zshsnake)
- [Contributing](#contributing)
- [License](#license)

## Features
- Play with ⬅️⬆️⬇️➡️ **arrow keys**, **W/A/S/D**, or **h/j/k/l**
- Runs on macOS and Linux terminals
- Lightweight and dependency-free

## Requirements
- Zsh 5.8+
- `stty` and `tput` (ncurses)  
  *Falls back to ANSI escape sequences if `tput` is not available.*

Notes:
The snake body is rendered using Unicode block characters (`■`). On ASCII-only terminals, the display may be misaligned or garbled. This limitation is currently WIP.  

## Installation

### Local Install

Clone the repository:
```zsh
git clone https://github.com/signothecat/zshsnake.git
cd zshsnake
chmod +x zshsnake.zsh
```

Run the game:
```zsh
./zshsnake.zsh
```

### Global Install

Clone the repository:
```zsh
git clone https://github.com/signothecat/zshsnake.git
cd zshsnake
sudo cp zshsnake.zsh /usr/local/bin/zshsnake
```

Run the game:
```zsh
zshsnake
```

## FAQ

### How can I uninstall zshsnake?

If you cloned the repository locally, simply delete the `zshsnake` folder.

```zsh
rm -rf zshsnake
```

If you installed it globally by copying to `/usr/local/bin`, remove it.

```zsh
sudo rm /usr/local/bin/zshsnake
```

## Contributing

This project is still a work in progress.  
Issues or pull requests are very welcome! 🙏

## License
MIT License © 2025 signothecat
