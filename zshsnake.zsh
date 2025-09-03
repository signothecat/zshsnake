#!/usr/bin/env zsh
# zshsnake.zsh — prototype

set -o errexit   # Exit immediately if a command fails
set -o nounset   # Treat unset variables as an error
set -o pipefail  # Fail if any command in a pipeline fails

########################################

# Config / Constants

########################################

GRID_W=24
GRID_H=20
CELL_W=${CELL_W:-2}
FIELD_CH=${FIELD_CH:-$'░'}
SNAKE_CELL="■$(printf "%*s" "$((CELL_W-1))" "")"
GRID_PIX_W=$(( GRID_W * CELL_W ))
# left border width (characters). 2 => render "| " (bar + space)
LEFT_BORDER_W=${LEFT_BORDER_W:-2}
# right border padding (spaces BEFORE the right bar). 1 => render "|", 2 => render " |"
RIGHT_BORDER_W=${RIGHT_BORDER_W:-1}
TICK_MS=${SNAKE_TICK_MS:-110}
SCORE=${SCORE:-0}

if command -v tput >/dev/null 2>&1; then
  COLOR_RESET=$(tput sgr0)
  COLOR_SNAKE=$(tput setaf 4)
  COLOR_TEXT=$(tput setaf 7)
  COLOR_BORDER=$(tput setaf 4)
  COLOR_FIELD=$(tput setaf 7)
  COLOR_FOOD=$(tput setaf 3)
else
  COLOR_RESET=""
  COLOR_SNAKE=""
  COLOR_TEXT=""
  COLOR_BORDER=""
  COLOR_FIELD=""
  COLOR_FOOD=""
fi

# ANSI Color Codes (for reference)
# 0 = Black
# 1 = Red
# 2 = Green
# 3 = Yellow
# 4 = Blue
# 5 = Magenta
# 6 = Cyan
# 7 = White

########################################

#  Snake Head Color Initialization

########################################

# head color
if [[ -z "${COLOR_HEAD:-}" ]]; then
  if command -v tput >/dev/null 2>&1; then
    COLOR_HEAD=$(tput setaf 2)
  else
    COLOR_HEAD=""
  fi
fi

########################################

# Runtime State (mutable globals)
# - Current game mode and per-frame flags
# - Snake body and movement vectors
# - Logic -> Render handoff flags

########################################

state="START_MENU"        # current game state
NEED_REDRAW=0             # request full redraw
BORDERS_DRAWN=0           # borders drawn (lazy init)
FIRST_STEP_DONE=0         # first movement completed

typeset -g LAST_TAIL="" LAST_HEAD="" LAST_PREV_HEAD=""  # incremental draw keys
typeset -g FOOD=""                                      # "x,y" or empty
typeset -g ATE=0 COLLIDED=0 SCORE_DIRTY=0               # logic→render flags

typeset -a snake
snake=()                    # body as ["x,y", ...]
dx=1; dy=0                  # current direction
want_dx=1; want_dy=0        # desired direction (from input)

########################################

# Terminal Controls

########################################

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

# Cleanup handler: ensure screen is cleared and terminal is restored
on_exit() {
  clear_screen
  restore_term
}

# Always run cleanup on exit or interruption
trap on_exit EXIT INT TERM

########################################

# Drawing Logic

########################################

# ----------------- Clear Functions ---------------------

# Clear the entire terminal screen and move cursor to top-left
clear_screen() {
  if command -v tput >/dev/null 2>&1; then
    tput clear
    tput cup 0 0
  else
    printf "\033[2J\033[H"
  fi
}

# Clear from cursor position to the end of the current line
clear_eol() {
  if command -v tput >/dev/null 2>&1; then
    tput el
  else
    printf "\033[K"
  fi
}

# ------------------- Menu Screen ----------------------

# Draw start menu screen (title and available key hints)
draw_start() {
  local title="Zsh Snake"
  local hint1="[s] Start"
  local hint2="[q] Quit"
  local row=3
  move_to $row 0;   printf "%s%s%s\n" "$COLOR_TEXT" "$title" "$COLOR_RESET"
  move_to $((row+2)) 0; printf "|  %s%s  |  %s%s  |\n" "$COLOR_TEXT" "$hint1" "$hint2" "$COLOR_RESET"
  move_to $((GRID_H+3)) 0
}

# ------------------- Game Screen ------------------------

# helpers to render borders consistently with widths
render_left_border() { printf "│ "; }
render_right_border() { printf "│"; }
DRAW_TOP_LEN() { echo $(( GRID_PIX_W + LEFT_BORDER_W + RIGHT_BORDER_W - 2 )); }

# game screen's header: title + score
draw_header() {
  local title="Zsh Snake"
  move_to 0 0; clear_eol; printf "%s%s%s %s| Score: %d%s" \
    "$COLOR_TEXT" "$title" "$COLOR_RESET" \
    "$COLOR_TEXT" "$SCORE" "$COLOR_RESET"
  move_to $((GRID_H+3)) 0
}

# field borders
draw_borders() {
  local title="Zsh Snake"
  # top line: score placeholder
  draw_header
  # top/bottom borders: extend by LEFT_BORDER_W + RIGHT_BORDER_W - 1 to keep right edge aligned
  local top_len=$(DRAW_TOP_LEN)
  move_to 1 0; printf "┌"; draw_repeat "─" "$top_len"; printf "┐"
  move_to $((GRID_H+2)) 0; printf "└"; draw_repeat "─" "$top_len"; printf "┘"
  for (( y=0; y<GRID_H; y++ )); do
  move_to $((2+y)) 0; render_left_border # left border with padding after bar
  move_to $((2+y)) $((LEFT_BORDER_W + GRID_PIX_W)); render_right_border # right border with optional leading spaces
  done
  # bottom line: keybinding help moved here
  draw_food
  move_to $((GRID_H+3)) 0; printf "%s[p/space]Pause, [r]Retry, [b]Back to Menu, [q]Quit%s" "$COLOR_TEXT" "$COLOR_RESET"
  BORDERS_DRAWN=1
}

# play screen
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
      elif [[ $key == $FOOD ]]; then
        printf "%s%s%s" "$COLOR_FOOD" "$SNAKE_CELL" "$COLOR_RESET"
      else
        printf "%s" "$COLOR_FIELD"; draw_repeat "$FIELD_CH" "$CELL_W"; printf "%s" "$COLOR_RESET"
      fi
    done
  done
}

# ------------------- Snake ---------------------

draw_step() {
  # Draw borders once (lazy initialization)
  if (( ! BORDERS_DRAWN )); then
    draw_borders
  fi

  local tail=$1
  local head=$2

  # Erase the tail cell if it moved
  if [[ -n $tail ]]; then
    local tx=${tail%%,*}
    local ty=${tail##*,}
    move_to $((2+ty)) $((LEFT_BORDER_W + tx*CELL_W)); printf "%s" "$COLOR_FIELD"; draw_repeat "$FIELD_CH" "$CELL_W"; printf "%s" "$COLOR_RESET"
  fi

  # Recolor previous head (now part of body) if it wasn't erased
  if [[ -n ${LAST_PREV_HEAD} && ${LAST_PREV_HEAD} != ${tail} ]]; then
    local px=${LAST_PREV_HEAD%%,*}
    local py=${LAST_PREV_HEAD##*,}
    move_to $((2+py)) $((LEFT_BORDER_W + px*CELL_W)); printf "%s%s%s" "$COLOR_SNAKE" "$SNAKE_CELL" "$COLOR_RESET"
  fi

  # Draw the new head in specified color
  local hx=${head%%,*}
  local hy=${head##*,}
  move_to $((2+hy)) $((LEFT_BORDER_W + hx*CELL_W)); printf "%s%s%s" "$COLOR_HEAD" "$SNAKE_CELL" "$COLOR_RESET"

  # Ensure new food is drawn right away
  draw_food

  # Move cursor below field (avoid leaving cursor inside)
  move_to $((GRID_H+3)) 0
}

# ---------------------- Food -------------------------

# random spawning food
draw_food() {
  [[ -z ${FOOD} ]] && return
  local fx=${FOOD%%,*}
  local fy=${FOOD##*,}
  move_to $((2+fy)) $((LEFT_BORDER_W + fx*CELL_W)); printf "%s%s%s" "$COLOR_FOOD" "$SNAKE_CELL" "$COLOR_RESET"
}

########################################

# Game State Logic

########################################

init_snake() {
  local cx=$((GRID_W/2))
  local cy=$((GRID_H/2))
  snake=( $(pos_key $((cx-1)) $cy) $(pos_key $cx $cy) $(pos_key $((cx+1)) $cy) )
  dx=1; dy=0; want_dx=$dx; want_dy=$dy
  LAST_TAIL=""; LAST_HEAD=""; SCORE=0
  NEED_REDRAW=1
  BORDERS_DRAWN=0
  FIRST_STEP_DONE=0
  # reset logic→render flags
  ATE=0; COLLIDED=0; SCORE_DIRTY=0
  # (re)spawn food after snake is placed so it never overlaps
  FOOD=""
  spawn_food
}

spawn_food() {
  typeset -A occ; occ=()
  local s
  for s in ${snake[@]}; do occ[$s]=1; done
  local free=$(( GRID_W*GRID_H - ${#snake[@]} ))
  if (( free <= 0 )); then
    FOOD=""
    return
  fi
  local x y k
  while true; do
    x=$((RANDOM % GRID_W))
    y=$((RANDOM % GRID_H))
    k=$(pos_key $x $y)
    if [[ -z ${occ[$k]:-} ]]; then
      FOOD=$k
      break
    fi
  done
}

update_snake() {
  # reset per-tick flags
  ATE=0; COLLIDED=0
  local tail=${snake[1]}
  local head=${snake[-1]}
  local hx=${head%%,*}
  local hy=${head##*,}
  local nx=$((hx + dx))
  local ny=$((hy + dy))
  if (( nx < 0 || nx >= GRID_W || ny < 0 || ny >= GRID_H )); then
    COLLIDED=1
    return
  fi
  local new=$(pos_key $nx $ny)
  if [[ -n $FOOD && $new == $FOOD ]]; then
    ATE=1
  fi
  snake+=$new
  if (( ATE )); then
    LAST_TAIL=""
    SCORE=$((SCORE+1))
    SCORE_DIRTY=1
  else
    snake=(${snake[@]:1})
    LAST_TAIL=$tail
  fi
  LAST_PREV_HEAD=$head
  LAST_HEAD=$new
  FIRST_STEP_DONE=1
  if (( ATE )); then
    spawn_food
  fi
}

# Apply the desired direction (want_dx, want_dy) to the current movement (dx, dy)
apply_direction() { dx=$want_dx; dy=$want_dy; }

########################################

# Utility Helpers

########################################

# Helper functions for positions, movement, and timing

# Current time in milliseconds (robust across environments)
now_ms() {
  # Prefer zsh/datetime's EPOCHREALTIME if available
  if zmodload -e zsh/datetime 2>/dev/null || zmodload zsh/datetime 2>/dev/null; then
    printf '%.0f' "$(( EPOCHREALTIME * 1000 ))"
    return
  fi
  # Fallback: Perl High-Resolution timer
  if command -v perl >/dev/null 2>&1; then
    perl -MTime::HiRes -e 'printf("%d", int(Time::HiRes::time()*1000))'
    return
  fi
  # Fallback: zsh printf epoch seconds (no ms precision)
  if printf '%(%s)T' -1 >/dev/null 2>&1; then
    printf '%s000' "$(printf '%(%s)T' -1)"
    return
  fi
  # Last resort
  date +%s 2>/dev/null | awk '{printf "%s000", $1}'
}

draw_repeat() {
  local ch="$1" n=$2
  local s
  s=$(printf "%*s" "$n" "")
  s=${s// /$ch}
  printf "%s" "$s"
}

# Convert (x, y) grid coordinates into a "x,y" string key
pos_key() { printf "%d,%d" "$1" "$2"; }

# Move the terminal cursor to the given (row, col) position
move_to() {
  if command -v tput >/dev/null 2>&1; then
    tput cup "$1" "$2"
  else
    printf "\033[%d;%dH" "$(( $1 + 1 ))" "$(( $2 + 1 ))"
  fi
}

# Sleep for a given number of milliseconds (uses Perl if available, otherwise awk + sleep)
msleep() {
  local ms=${1:-100}  # Get the first argument as milliseconds (default: 100)
  if command -v perl >/dev/null 2>&1; then  # If 'perl' command is available
    perl -e 'select undef, undef, undef, $ARGV[0]/1000' "$ms"  # Use Perl to sleep for ms/1000 seconds
  else
    local s
    s=$(printf "%s" "$ms" | awk '{printf "%.3f", $1/1000}')  # Convert ms to seconds with 3 decimals using awk (just divides ms by 1000)
    sleep "$s"  # Sleep using 'sleep' command (seconds)
  fi
}

########################################

# Input Handler

########################################

read_input() {
  local k rest third
  if read -k 1 -s -t 0 k 2>/dev/null; then
        if [[ $state == START_MENU ]]; then
      case "$k" in
        s|S)
          state="PLAYING"
          init_snake
          return
          ;;
        q|Q)
          clear_screen
          exit 0
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
    elif [[ $state == GAMEOVER ]]; then
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
        $'\e')  # drain ESC sequence = allow
          read -k 1 -s -t 0.02 rest  2>/dev/null || return
          read -k 1 -s -t 0.02 third 2>/dev/null || true
          return
          ;;
        *)  # ignore other keys
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

set_want() {
  local ndx=$1 ndy=$2
  if (( ndx == -dx && ndy == -dy )); then
    return
  fi
  if (( FIRST_STEP_DONE == 1 )); then
    want_dx=$ndx; want_dy=$ndy
  fi
}

########################################

# State Overlays (Paused / Game Over)

########################################

show_paused() {
  move_to $((GRID_H/2)) $((LEFT_BORDER_W + GRID_PIX_W/2 - 3)); printf "%sPAUSED%s" "$COLOR_TEXT" "$COLOR_RESET"
  move_to $((GRID_H+3)) 0
}

clear_paused() {
  move_to $((GRID_H/2)) $((LEFT_BORDER_W + GRID_PIX_W/2 - 3)); printf "░░░░░░"
  move_to $((GRID_H+3)) 0
}

show_gameover() {
  move_to $((GRID_H/2)) $((LEFT_BORDER_W + GRID_PIX_W/2 - 5)); printf "%sGAME OVER%s" "$COLOR_TEXT" "$COLOR_RESET"
  move_to $((GRID_H+3)) 0; clear_eol; printf "%s[r]Retry, [b]Back to Menu, [q]Quit%s" "$COLOR_TEXT" "$COLOR_RESET"
  move_to $((GRID_H+3)) 0
}

########################################

# Main Loop

########################################

main() {
  setup_term
  clear_screen
  draw_start
  while true; do
    local frame_start_ms=$(now_ms)
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
          update_snake
          if (( COLLIDED )); then
            state="GAMEOVER"
            show_gameover
          else
            draw_step "$LAST_TAIL" "$LAST_HEAD"
            (( SCORE_DIRTY )) && { draw_header; SCORE_DIRTY=0; }
          fi
        fi
        ;;
      PAUSED)
        ;;
      GAMEOVER)
        ;;
    esac    # frame pacing: sleep only the remaining time of TICK_MS after work this tick
    {
      local frame_end_ms=$(now_ms)
      local elapsed=$(( frame_end_ms - frame_start_ms ))
      local remain=$(( TICK_MS - elapsed ))
      (( remain > 0 )) && msleep "$remain"
    }
  done
}

# ---- Entry point: start the game by calling main() ------
main "$@"
