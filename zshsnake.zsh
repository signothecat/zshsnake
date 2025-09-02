#!/usr/bin/env zsh
# zshsnake.zsh — prototype: Start screen + auto-move + direction change (no food yet)

set -o errexit
set -o nounset
set -o pipefail

# ------------------------ Config ------------------------
GRID_W=15
GRID_H=15
# horizontal cell width (characters). Increase to compensate tall line height
CELL_W=${CELL_W:-2}
# cell strings (empty and snake). SNAKE_CELL is a full cell with padding to CELL_W
EMPTY_CELL="$(printf "%*s" "$CELL_W" "")"
SNAKE_CELL="■$(printf "%*s" "$((CELL_W-1))" "")"
TICK_MS=${SNAKE_TICK_MS:-100}   # frame time in ms

# Colors via tput (fallback to no color)
if command -v tput >/dev/null 2>&1; then
  COLOR_RESET=$(tput sgr0)
  COLOR_SNAKE=$(tput setaf 2)   # green
  COLOR_TEXT=$(tput setaf 7)    # white/gray
else
  COLOR_RESET=""
  COLOR_SNAKE=""
  COLOR_TEXT=""
fi

# ------------------------ Terminal control ------------------------
restore_term() {
  printf "%s" "${COLOR_RESET}"
  if command -v tput >/dev/null 2>&1; then
    tput cnorm
  fi
  stty sane 2>/dev/null || true
}

setup_term() {
  stty -echo -icanon time 0 min 0 2>/dev/null || true
  if command -v tput >/dev/null 2>&1; then
    tput civis
  fi
}

on_exit() { restore_term; }
trap on_exit EXIT INT TERM

# ------------------------ Utility ------------------------
msleep() {
  # sleep milliseconds (integer)
  local ms=${1:-100}
  if command -v perl >/dev/null 2>&1; then
    perl -e 'select undef, undef, undef, $ARGV[0]/1000' "$ms"
  else
    local s
    s=$(printf "%s" "$ms" | awk '{printf "%.3f", $1/1000}')
    sleep "$s"
  fi
}

# Map (x,y) to key string "x,y"
pos_key() { printf "%d,%d" "$1" "$2"; }

# ------------------------ Game state ------------------------
state="START_MENU"  # START_MENU | PLAYING
NEED_REDRAW=0
typeset -g LAST_TAIL="" LAST_HEAD=""

# Snake represented as array of "x,y" strings, head is the last element
typeset -a snake
snake=()

# Direction vector (dx, dy)
dx=1; dy=0
want_dx=1; want_dy=0

rand_dir() {
  local r=$((RANDOM%4))
  case $r in
    0) dx=1; dy=0;;   # right
    1) dx=-1; dy=0;;  # left
    2) dx=0; dy=1;;   # down
    3) dx=0; dy=-1;;  # up
  esac
  want_dx=$dx; want_dy=$dy
}

init_snake() {
  local cx=$((GRID_W/2))
  local cy=$((GRID_H/2))
  snake=( $(pos_key $((cx-1)) $cy) $(pos_key $cx $cy) $(pos_key $((cx+1)) $cy) )
  rand_dir
  LAST_TAIL=""; LAST_HEAD=""
  NEED_REDRAW=1
}

# ------------------------ Input handling ------------------------
set_want() {
  local ndx=$1 ndy=$2
  # forbid direct reverse
  if (( ndx == -dx && ndy == -dy )); then
    return
  fi
  want_dx=$ndx; want_dy=$ndy
}

# Read any pending key(s); non-blocking.
read_input() {
  local k rest
  if read -k 1 -s -t 0.001 k 2>/dev/null; then
    # Arrow keys: ESC [ A/B/C/D
    if [[ $k == $'\e' ]]; then
      if read -k 1 -s -t 0.0001 rest 2>/dev/null && [[ $rest == "[" ]]; then
        if read -k 1 -s -t 0.0001 rest 2>/dev/null; then
          case "$rest" in
            A) set_want 0 -1;; # up
            B) set_want 0 1;;  # down
            C) set_want 1 0;;  # right
            D) set_want -1 0;; # left
          esac
        fi
      fi
      return
    fi

    case "$k" in
      q|Q)
        exit 0;;
      s|S)
        if [[ $state == START_MENU ]]; then
          state="PLAYING"; init_snake; return
        else
          set_want 0 1
        fi
        ;;
      # WASD (except s above handled)
      w|W) set_want 0 -1;;
      a|A) set_want -1 0;;
      d|D) set_want 1 0;;
      # hjkl
      h|H) set_want -1 0;;
      j|J) set_want 0 1;;
      k|K) set_want 0 -1;;
      l|L) set_want 1 0;;
    esac
  fi
}

apply_direction() { dx=$want_dx; dy=$want_dy; }

# ------------------------ Update & Draw ------------------------
step_snake() {
  local tail=${snake[1]}
  local head=${snake[-1]}
  local hx=${head%%,*}
  local hy=${head##*,}
  local nx=$(( (hx + dx + GRID_W) % GRID_W ))
  local ny=$(( (hy + dy + GRID_H) % GRID_H ))
  snake+=$(pos_key $nx $ny)
  snake=(${snake[@]:1})
  LAST_TAIL=$tail
  LAST_HEAD=$(pos_key $nx $ny)
}

clear_screen() {
  if command -v tput >/dev/null 2>&1; then
    tput clear
    tput cup 0 0    # be explicit about homing
  else
    printf "\033[2J\033[H"
  fi
}

move_to() {
  if command -v tput >/dev/null 2>&1; then
    tput cup "$1" "$2"
  else
    printf "\033[%d;%dH" "$(( $1 + 1 ))" "$(( $2 + 1 ))"
  fi
}

# draw header + grid (■ for all cells; snake colored)
draw_play() {
  clear_screen
  # Header (row 0) — no trailing newline (avoid scroll)
  move_to 0 0; printf "%s↑↓←→ / WASD / hjkl | q:Quit%s" "$COLOR_TEXT" "$COLOR_RESET"

  # Occupancy map
  typeset -A occ; occ=()
  local p
  for p in ${snake[@]}; do occ[$p]=1; done

  # Grid origin at row 1
  local y x key row
  for (( y=0; y<GRID_H; y++ )); do
    row=$((1+y))
    move_to $row 0
    for (( x=0; x<GRID_W; x++ )); do
      key=$(pos_key $x $y)
      if [[ -n ${occ[$key]:-} ]]; then
        move_to $row $((x*CELL_W))
        printf "%s%s%s" "$COLOR_SNAKE" "$SNAKE_CELL" "$COLOR_RESET"
      else
        move_to $row $((x*CELL_W))
        printf "%s" "$EMPTY_CELL"
      fi
    done
  done

  # Park cursor outside the grid (some terminals scroll on last-column writes)
  move_to $((GRID_H+1)) 0
}

# diff draw: erase old tail, draw new head only
draw_step() {
  local tail=$1
  local head=$2
  # erase tail (default cell)
  local tx=${tail%%,*}
  local ty=${tail##*,}
  move_to $((ty+1)) $((tx*CELL_W)); printf "%s" "$EMPTY_CELL"
  # draw head (snake color)
  local hx=${head%%,*}
  local hy=${head##*,}
  move_to $((hy+1)) $((hx*CELL_W)); printf "%s%s%s" "$COLOR_SNAKE" "$SNAKE_CELL" "$COLOR_RESET"
  move_to $((GRID_H+1)) 0
}

draw_start() {
  clear_screen
  local title="Snake (Zsh)"
  local hint1="s: Start"
  local hint2="q: Quit"
  local row=3
  move_to $row 0;   printf "%s%s%s\n" "$COLOR_TEXT" "$title" "$COLOR_RESET"
  move_to $((row+2)) 0; printf "%s%s    %s%s\n" "$COLOR_TEXT" "$hint1" "$hint2" "$COLOR_RESET"
}

# ------------------------ Main loop ------------------------
main() {
  setup_term
  draw_start

  while true; do
    read_input
    case $state in
      START_MENU)
        ;;
      PLAYING)
        if (( NEED_REDRAW )); then
          draw_play       # 最初の1回だけ全面描画
          NEED_REDRAW=0
        else
          apply_direction
          step_snake
          draw_step "$LAST_TAIL" "$LAST_HEAD"   # 差分だけ更新
        fi
        ;;
    esac
    msleep "$TICK_MS"
  done
}

main "$@"
