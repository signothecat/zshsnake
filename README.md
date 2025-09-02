# zshsnake 🐍

**Classic snake game in your terminal, written in pure Zsh.**

This is a tiny experiment to bring the nostalgic snake game into your terminal using only Zsh.

## Features
- Runs entirely in **pure Zsh**
- 15x15 fixed grid
- Start screen, auto-moving snake
- Control with **arrow keys**, **WASD**, or **hjkl**
- Minimal dependencies: works on macOS/Linux terminal with `tput` and `stty`

## Installation

Clone this repository and make the script executable:

```bash
git clone https://github.com/signothecat/zshsnake.git
cd zshsnake
chmod +x zshsnake.zsh
```

Run directly:

```bash
./zshsnake.zsh
```

Optionally install globally:

```bash
cp zshsnake.zsh /usr/local/bin/zshsnake
```

Now you can just run:

```bash
zshsnake
```

## How to Play

- **s**: Start game (on start screen)  
- **q**: Quit  
- **↑ ↓ ← → / WASD / hjkl**: Move the snake  
- Snake moves automatically — you just steer it!  

> *Note*: At this stage, the game is still a prototype (no food, no score, no game over yet).  

## Roadmap
- [ ] Add food and score counter  
- [ ] Implement self-collision detection  
- [ ] Game over screen with restart option  
- [ ] Random wall-turning behavior  
- [ ] Pause and restart keys (`p`, `r`)  

## License
MIT License © 2025 signothecat
