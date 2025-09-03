#!/usr/bin/env zsh
# zshsnake.zsh — prototype: Start screen + auto-move + direction change + pause toggle

set -o errexit
set -o nounset
set -o pipefail

# ------------------------ Config ------------------------
GRID_W=26
GRID_H=20
CELL_W=${CELL_W:-2}
FIELD_CH=${FIELD_CH:-$'░'}
SNAKE_CELL="■$(printf "%*s" "$((CELL_W-1))" "")"
GRID_PIX_W=$(( GRID_W * CELL_W ))
# left border width (characters). 2 => render "| " (bar + space)
LEFT_BORDER_W=${LEFT_BORDER_W:-2}
# right border padding (spaces BEFORE the right bar). 1 => render "|", 2 => render " |"
RIGHT_BORDER_W=${RIGHT_BORDER_W:-1}
TICK_MS=${SNAKE_TICK_MS:-70}
SCORE=${SCORE:-0}

if command -v tput >/dev/null 2>&1; then
  COLOR_RESET=$(tput sgr0)
  COLOR_SNAKE=$(tput setaf 2)
  COLOR_TEXT=$(tput setaf 7)
  COLOR_BORDER=$(tput setaf 4)
  COLOR_FIELD=$(tput setaf 7)
else
  COLOR_RESET=""
  COLOR_SNAKE=""
  COLOR_TEXT=""
  COLOR_BORDER=""
  COLOR_FIELD=""
fi

# ensure head color (magenta)
if [[ -z "${COLOR_HEAD:-}" ]]; then
  if command -v tput >/dev/null 2>&1; then
    COLOR_HEAD=$(tput setaf 5)
  else
    COLOR_HEAD=""
  fi
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

on_exit() {
  clear_screen
  restore_term
}
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
FIRST_STEP_DONE=0
typeset -g LAST_TAIL="" LAST_HEAD="" LAST_PREV_HEAD=""
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
  dx=1; dy=0; want_dx=$dx; want_dy=$dy
  LAST_TAIL=""; LAST_HEAD=""
  NEED_REDRAW=1
  BORDERS_DRAWN=0
  FIRST_STEP_DONE=0
}

set_want() {
  local ndx=$1 ndy=$2
  if (( ndx == -dx && ndy == -dy )); then
    return
  fi
  if (( FIRST_STEP_DONE == 1 )); then
    want_dx=$ndx; want_dy=$ndy
  fi
}

read_input() {
  local k rest third
  if read -k 1 -s -t 0.05 k 2>/dev/null; then
    if [[ $state == GAMEOVER ]]; then
      case "$k" in
        r|R)
          state="PLAYING"
          init_snake
          return
          ;;
        b|B)
          state="START_MENU"
          clear_screen
          draw_start
          NEED_REDRAW=0
          BORDERS_DRAWN=0
          FIRST_STEP_DONE=0
          return
          ;;
        q|Q)
          clear_screen
          exit 0
          ;;
        *)
          return
          ;;
      esac
    elif [[ $state == PAUSED ]]; then
      case "$k" in
        q|Q)
          clear_screen
          exit 0
          ;;
        p|P|$' ')
          state="PLAYING"
          clear_paused
          return
          ;;
        b|B)
          state="START_MENU"
          clear_screen
          draw_start
          NEED_REDRAW=0
          BORDERS_DRAWN=0
          FIRST_STEP_DONE=0
          return
          ;;
        r|R)
          state="PLAYING"
          init_snake
          return
          ;;
        $'\e')  # drain ESC sequence = allow
          read -k 1 -s -t 0.02 rest  2>/dev/null || return
          read -k 1 -s -t 0.02 third 2>/dev/null || true
          return
          ;;
        *)  # ignore other keys
          return
          ;;
      esac
    fi
    if [[ $k == $'\e' ]]; then
      if read -k 1 -s -t 0.0001 rest 2>/dev/null && [[ $rest == "[" ]]; then
        if read -k 1 -s -t 0.0001 rest 2>/dev/null; then
          case "$rest" in
            A) [[ $state == PLAYING ]] && set_want 0 -1;;  # UP arrow
            B) [[ $state == PLAYING ]] && set_want 0 1;;   # DOWN arrow
            C) [[ $state == PLAYING ]] && set_want 1 0;;   # RIGHT arrow
            D) [[ $state == PLAYING ]] && set_want -1 0;;  # LEFT arrow
          esac
        fi
      fi
      return
    fi
    case "$k" in
      q|Q)
        clear_screen
        exit 0;;
      p|P|" ")
        if [[ $state == "PLAYING" ]]; then
          state="PAUSED"
          show_paused
        elif [[ $state == "PAUSED" ]]; then
          state="PLAYING"
          clear_paused
        fi
        ;;
      r|R)
        state="PLAYING"
        init_snake
        return
        ;;
      s|S)
        if [[ $state == START_MENU ]]; then
          state="PLAYING"; init_snake; return
        elif [[ $state == PLAYING ]]; then
          set_want 0 1
        fi
        ;;
      w|W) [[ $state == PLAYING ]] && set_want 0 -1;;
      a|A) [[ $state == PLAYING ]] && set_want -1 0;;
      d|D) [[ $state == PLAYING ]] && set_want 1 0;;
      h|H) [[ $state == PLAYING ]] && set_want -1 0;;
      j|J) [[ $state == PLAYING ]] && set_want 0 1;;
      k|K) [[ $state == PLAYING ]] && set_want 0 -1;;
      l|L) [[ $state == PLAYING ]] && set_want 1 0;;
      b|B)
        if [[ $state == "PLAYING" || $state == "PAUSED" ]]; then
          state="START_MENU"
          clear_screen
          draw_start
          NEED_REDRAW=0
          BORDERS_DRAWN=0
          FIRST_STEP_DONE=0
        fi
        ;;
    esac
  fi
}

apply_direction() { dx=$want_dx; dy=$want_dy; }

step_snake() {
  local tail=${snake[1]}
  local head=${snake[-1]}
  local hx=${head%%,*}
  local hy=${head##*,}
  local nx=$((hx + dx))
  local ny=$((hy + dy))
  if (( nx < 0 || nx >= GRID_W || ny < 0 || ny >= GRID_H )); then
    state="GAMEOVER"
    show_gameover
    return
  fi
  snake+=$(pos_key $nx $ny)
  snake=(${snake[@]:1})
  LAST_TAIL=$tail
  LAST_PREV_HEAD=$head
  LAST_HEAD=$(pos_key $nx $ny)
  FIRST_STEP_DONE=1
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

clear_eol() {
  if command -v tput >/dev/null 2>&1; then
    tput el
  else
    printf "[K"
  fi
}


draw_repeat() {
  local ch="$1" n=$2
  local s
  s=$(printf "%*s" "$n" "")
  s=${s// /$ch}
  printf "%s" "$s"
}

# helpers to render borders consistently with widths
render_left_border() { printf "│ "; }
render_right_border() { printf "│"; }

DRAW_TOP_LEN() { echo $(( GRID_PIX_W + LEFT_BORDER_W + RIGHT_BORDER_W - 2 )); }

draw_borders() {
  local title="Zsh Snake"
  # top line: score placeholder
  move_to 0 0; printf "%s%s%s %s| Score: %d%s" \
    "$COLOR_TEXT" "$title" "$COLOR_RESET" \
    "$COLOR_TEXT" "$SCORE" "$COLOR_RESET"
  # top/bottom borders: extend by LEFT_BORDER_W + RIGHT_BORDER_W - 1 to keep right edge aligned
  local top_len=$(DRAW_TOP_LEN)
  move_to 1 0; printf "┌"; draw_repeat "─" "$top_len"; printf "┐"
  move_to $((GRID_H+2)) 0; printf "└"; draw_repeat "─" "$top_len"; printf "┘"
  for (( y=0; y<GRID_H; y++ )); do
  move_to $((2+y)) 0; render_left_border # left border with padding after bar
  move_to $((2+y)) $((LEFT_BORDER_W + GRID_PIX_W)); render_right_border # right border with optional leading spaces
  done
  # bottom line: keybinding help moved here
  move_to $((GRID_H+3)) 0; printf "%s[p/space]Pause, [r]Retry, [b]Back to Menu, [q]Quit%s" "$COLOR_TEXT" "$COLOR_RESET"
  BORDERS_DRAWN=1
}

draw_play() {
  clear_screen
  draw_borders
  typeset -A occ; occ=()
  local p
  for p in ${snake[@]}; do occ[$p]=1; done
  local headk=${snake[-1]}
  local y x key row col
  for (( y=0; y<GRID_H; y++ )); do
    row=$((2+y))
    for (( x=0; x<GRID_W; x++ )); do
      col=$((LEFT_BORDER_W + x*CELL_W))
      key=$(pos_key $x $y)
      move_to $row $col
      if [[ -n ${occ[$key]:-} ]]; then
        if [[ $key == $headk ]]; then
          printf "%s%s%s" "$COLOR_HEAD" "$SNAKE_CELL" "$COLOR_RESET"
        else
          printf "%s%s%s" "$COLOR_SNAKE" "$SNAKE_CELL" "$COLOR_RESET"
        fi
      else
        printf "%s" "$COLOR_FIELD"; draw_repeat "$FIELD_CH" "$CELL_W"; printf "%s" "$COLOR_RESET"
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
  move_to $((2+ty)) $((LEFT_BORDER_W + tx*CELL_W)); printf "%s" "$COLOR_FIELD"; draw_repeat "$FIELD_CH" "$CELL_W"; printf "%s" "$COLOR_RESET"
  # recolor previous head (now body) if it's still on the snake
  if [[ -n ${LAST_PREV_HEAD} && ${LAST_PREV_HEAD} != ${tail} ]]; then
    local px=${LAST_PREV_HEAD%%,*}
    local py=${LAST_PREV_HEAD##*,}
    move_to $((2+py)) $((LEFT_BORDER_W + px*CELL_W)); printf "%s%s%s" "$COLOR_SNAKE" "$SNAKE_CELL" "$COLOR_RESET"
  fi
  local hx=${head%%,*}
  local hy=${head##*,}
  move_to $((2+hy)) $((LEFT_BORDER_W + hx*CELL_W)); printf "%s%s%s" "$COLOR_HEAD" "$SNAKE_CELL" "$COLOR_RESET"
  move_to $((GRID_H+3)) 0
}

draw_start() {
  clear_screen
  local title="Zsh Snake"
  local hint1="s: Start"
  local hint2="q: Quit"
  local row=3
  move_to $row 0;   printf "%s%s%s\n" "$COLOR_TEXT" "$title" "$COLOR_RESET"
  move_to $((row+2)) 0; printf "%s%s    %s%s\n" "$COLOR_TEXT" "$hint1" "$hint2" "$COLOR_RESET"
}

show_paused() {
  move_to $((GRID_H/2)) $((LEFT_BORDER_W + GRID_PIX_W/2 - 3)); printf "%sPAUSED%s" "$COLOR_TEXT" "$COLOR_RESET"
}

clear_paused() {
  move_to $((GRID_H/2)) $((LEFT_BORDER_W + GRID_PIX_W/2 - 3)); printf "░░░░░░"
}

show_gameover() {
  move_to $((GRID_H/2)) $((LEFT_BORDER_W + GRID_PIX_W/2 - 5)); printf "%sGAME OVER%s" "$COLOR_TEXT" "$COLOR_RESET"
  move_to $((GRID_H+3)) 0; clear_eol; printf "%s[r]Retry, [b]Back to Menu, [q]Quit%s" "$COLOR_TEXT" "$COLOR_RESET"
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
          [[ $state == PLAYING ]] && draw_step "$LAST_TAIL" "$LAST_HEAD"
        fi
        ;;
      PAUSED)
        ;;
      GAMEOVER)
        ;;
    esac
    msleep "$TICK_MS"
  done
}

main "$@"
