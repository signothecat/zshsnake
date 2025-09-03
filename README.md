# zshsnake 🐍

A retro snake game for your terminal, written in pure Zsh with no external dependencies.

![demo](https://github.com/user-attachments/assets/c0b8123e-16c4-4088-8211-c6b67b20367d)

## Requirements
- Zsh 5.8+
- `stty` and `tput` (ncurses)  
  *Falls back to ANSI escape sequences if `tput` is not available.*

## Features
- Play with ⬅️⬆️⬇️➡️ **arrow keys**, **W/A/S/D**, or **h/j/k/l**
- Runs on macOS and Linux terminals
- Lightweight and dependency-free

### Notes
The snake body is rendered using Unicode block characters (`■`).  
On ASCII-only terminals, the display may be misaligned or garbled.  
This limitation is currently WIP.  

## Installation

Clone this repository and make the script executable:

```zsh
git clone https://github.com/signothecat/zshsnake.git
cd zshsnake
chmod +x zshsnake.zsh
```

Run directly:

```zsh
./zshsnake.zsh
```

Optionally install globally:

```zsh
cp zshsnake.zsh /usr/local/bin/zshsnake
```

Now you can just run:

```zsh
zshsnake
```

## How to Play

- **s**: Start game (on start screen)  
- **q**: Quit  
- **↑ ↓ ← → / WASD / hjkl**: Move the snake  
- Snake moves automatically — you just steer it!

## FAQ

### How can I uninstall zshsnake?

If you cloned the repository locally, simply delete the `zshsnake` folder with:

```zsh
rm -rf zshsnake
```

If you installed it globally by copying to `/usr/local/bin`, remove it with:

```zsh
sudo rm /usr/local/bin/zshsnake
```

## Contributing

This project is still a work in progress.  
If you'd like to help improve compatibility, refine gameplay, or add new features, contributions are very welcome! 🙏

## License
MIT License © 2025 signothecat
