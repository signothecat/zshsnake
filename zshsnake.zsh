#!/usr/bin/env zsh
# zshsnake.zsh — prototype: Start screen + auto-move + direction change + pause toggle

set -o errexit
set -o nounset
set -o pipefail

# ------------------------ Config ------------------------
GRID_W=30
GRID_H=15
CELL_W=${CELL_W:-2}
EMPTY_CELL="$(printf "%*s" "$CELL_W" "")"
SNAKE_CELL="■$(printf "%*s" "$((CELL_W-1))" "")"
GRID_PIX_W=$(( GRID_W * CELL_W ))
TICK_MS=${SNAKE_TICK_MS:-100}

if command -v tput >/dev/null 2>&1; then
  COLOR_RESET=$(tput sgr0)
  COLOR_SNAKE=$(tput setaf 2)
  COLOR_TEXT=$(tput setaf 7)
  COLOR_BORDER=$(tput setaf 4)
else
  COLOR_RESET=""
  COLOR_SNAKE=""
  COLOR_TEXT=""
  COLOR_BORDER=""
fi

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

msleep() {
  local ms=${1:-100}
  if command -v perl >/dev/null 2>&1; then
    perl -e 'select undef, undef, undef, $ARGV[0]/1000' "$ms"
  else
    local s
    s=$(printf "%s" "$ms" | awk '{printf "%.3f", $1/1000}')
    sleep "$s"
  fi
}

pos_key() { printf "%d,%d" "$1" "$2"; }

state="START_MENU"
NEED_REDRAW=0
BORDERS_DRAWN=0
typeset -g LAST_TAIL="" LAST_HEAD=""
typeset -a snake
snake=()
dx=1; dy=0
want_dx=1; want_dy=0

rand_dir() {
  local r=$((RANDOM%4))
  case $r in
    0) dx=1; dy=0;;
    1) dx=-1; dy=0;;
    2) dx=0; dy=1;;
    3) dx=0; dy=-1;;
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
  BORDERS_DRAWN=0
}

set_want() {
  local ndx=$1 ndy=$2
  if (( ndx == -dx && ndy == -dy )); then
    return
  fi
  want_dx=$ndx; want_dy=$ndy
}

read_input() {
  local k rest
  if read -k 1 -s -t 0.001 k 2>/dev/null; then
    if [[ $k == $'\e' ]]; then
      if read -k 1 -s -t 0.0001 rest 2>/dev/null && [[ $rest == "[" ]]; then
        if read -k 1 -s -t 0.0001 rest 2>/dev/null; then
          case "$rest" in
            A) set_want 0 -1;;
            B) set_want 0 1;;
            C) set_want 1 0;;
            D) set_want -1 0;;
          esac
        fi
      fi
      return
    fi
    case "$k" in
      q|Q) exit 0;;
      p|P)
        if [[ $state == "PLAYING" ]]; then
          state="PAUSED"
          show_paused
        elif [[ $state == "PAUSED" ]]; then
          state="PLAYING"
          clear_paused
        fi
        ;;
      s|S)
        if [[ $state == START_MENU ]]; then
          state="PLAYING"; init_snake; return
        else
          set_want 0 1
        fi
        ;;
      w|W) set_want 0 -1;;
      a|A) set_want -1 0;;
      d|D) set_want 1 0;;
      h|H) set_want -1 0;;
      j|J) set_want 0 1;;
      k|K) set_want 0 -1;;
      l|L) set_want 1 0;;
    esac
  fi
}

apply_direction() { dx=$want_dx; dy=$want_dy; }

step_snake() {
  local tail=${snake[1]}
  local head=${snake[-1]}
  local hx=${head%%,*}
  local hy=${head##*,}
  local nx=$(((hx + dx + GRID_W) % GRID_W))
  local ny=$(((hy + dy + GRID_H) % GRID_H))
  snake+=$(pos_key $nx $ny)
  snake=(${snake[@]:1})
  LAST_TAIL=$tail
  LAST_HEAD=$(pos_key $nx $ny)
}

clear_screen() {
  if command -v tput >/dev/null 2>&1; then
    tput clear
    tput cup 0 0
  else
    printf "\033[2J\033[H"
  fi
}

move_to() {
  if command -v tput >/dev/null 2>&1; then
    tput cup "$1" "$2"
  else
    printf "[%d;%dH" "$(( $1 + 1 ))" "$(( $2 + 1 ))"
  fi
}

draw_repeat() {
  local ch="$1" n=$2
  local s
  s=$(printf "%*s" "$n" "")
  s=${s// /$ch}
  printf "%s" "$s"
}

draw_borders() {
  move_to 0 0; printf "%s↑↓←→ / WASD / hjkl | q:Quit | p:Pause%s" "$COLOR_TEXT" "$COLOR_RESET"
  move_to 1 0; printf "┌"; draw_repeat "─" "$GRID_PIX_W"; printf "┐"
  move_to $((GRID_H+2)) 0; printf "└"; draw_repeat "─" "$GRID_PIX_W"; printf "┘"
  for (( y=0; y<GRID_H; y++ )); do
    move_to $((2+y)) 0; printf "│"
    move_to $((2+y)) $((1 + GRID_PIX_W)); printf "│"
  done
  BORDERS_DRAWN=1
}

draw_play() {
  clear_screen
  draw_borders
  typeset -A occ; occ=()
  local p
  for p in ${snake[@]}; do occ[$p]=1; done
  local y x key row col
  for (( y=0; y<GRID_H; y++ )); do
    row=$((2+y))
    for (( x=0; x<GRID_W; x++ )); do
      col=$((1 + x*CELL_W))
      key=$(pos_key $x $y)
      move_to $row $col
      if [[ -n ${occ[$key]:-} ]]; then
        printf "%s%s%s" "$COLOR_SNAKE" "$SNAKE_CELL" "$COLOR_RESET"
      else
        printf "%s" "$EMPTY_CELL"
      fi
    done
  done
  move_to $((GRID_H+3)) 0
}

draw_step() {
  if (( ! BORDERS_DRAWN )); then
    draw_borders
  fi
  local tail=$1
  local head=$2
  local tx=${tail%%,*}
  local ty=${tail##*,}
  move_to $((2+ty)) $((1 + tx*CELL_W)); printf "%s" "$EMPTY_CELL"
  local hx=${head%%,*}
  local hy=${head##*,}
  move_to $((2+hy)) $((1 + hx*CELL_W)); printf "%s%s%s" "$COLOR_SNAKE" "$SNAKE_CELL" "$COLOR_RESET"
  move_to $((GRID_H+3)) 0
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

show_paused() {
  move_to $((GRID_H/2)) $((GRID_PIX_W/2 - 3)); printf "%sPAUSED%s" "$COLOR_TEXT" "$COLOR_RESET"
}

clear_paused() {
  move_to $((GRID_H/2)) $((GRID_PIX_W/2 - 3)); printf "      "
}

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
          draw_play
          NEED_REDRAW=0
        else
          apply_direction
          step_snake
          draw_step "$LAST_TAIL" "$LAST_HEAD"
        fi
        ;;
      PAUSED)
        ;;
    esac
    msleep "$TICK_MS"
  done
}

main "$@"
