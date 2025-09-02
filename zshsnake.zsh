#!/usr/bin/env zsh
# Snake (Zsh) - minimal prototype: Start screen + auto-move + direction change
# - Fixed grid 15x15
# - Start screen: 's' to start, 'q' to quit
# - Playing: auto forward, arrow/WASD/hjkl to turn (no reverse), 'q' quits
# - Full redraw each frame (simple + reliable)
# - NO food/score/collisions yet (to be added later)

set -o errexit
set -o nounset
set -o pipefail

# ------------------------ Config ------------------------
GRID_W=15
GRID_H=15
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
  # restore cursor + terminal mode
  printf "%s" "${COLOR_RESET}"
  command -v tput >/dev/null 2>&1 && tput cnorm || true
  stty sane 2>/dev/null || true
}

setup_term() {
  # noncanonical, no-echo, hide cursor
  stty -echo -icanon time 0 min 0 2>/dev/null || true
  command -v tput >/dev/null 2>&1 && tput civis || true
}

on_exit() {
  restore_term
}

trap on_exit EXIT INT TERM

# ------------------------ Utility ------------------------
msleep() {
  # sleep milliseconds (integer)
  local ms=${1:-100}
  # use usleep if available for finer granularity
  if command -v perl >/dev/null 2>&1; then
    perl -e 'select undef, undef, undef, $ARGV[0]/1000' "$ms"
  else
    # fallback (coarse)
    local s=$(printf "%s" "$ms" | awk '{printf "%.3f", $1/1000}')
    sleep "$s"
  fi
}

# Map (x,y) to key string "x,y"
pos_key() { printf "%d,%d" "$1" "$2"; }

# ------------------------ Game state ------------------------
state="START_MENU"  # START_MENU | PLAYING

# Snake represented as array of "x,y" strings, head at index 1
typeset -a snake
snake=()

# Direction vector (dx, dy): up(0,-1), down(0,1), left(-1,0), right(1,0)
dx=1; dy=0  # will be randomized at game start

# Input buffer (single latest intent)
want_dx=1; want_dy=0

rand_dir() {
  # pick one of four directions uniformly
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
  # center-start 3 segments horizontally
  local cx=$((GRID_W/2))
  local cy=$((GRID_H/2))
  snake=( $(pos_key $((cx-1)) $cy) $(pos_key $cx $cy) $(pos_key $((cx+1)) $cy) )
  rand_dir
}

# ------------------------ Input handling ------------------------
# Read any pending key(s); non-blocking. Sets want_dx/want_dy or handles commands
read_input() {
  local k rest
  # read one char non-blocking
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
          state="PLAYING"
          init_snake
        fi
        ;;
      # WASD
      w|W) set_want 0 -1;;
      s|S) set_want 0 1;;
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

# Apply desired direction if not reverse
set_want() {
  local ndx=$1 ndy=$2
  # forbid direct reverse (dx,dy) -> (-dx,-dy)
  if (( ndx == -dx && ndy == -dy )); then
    return
  fi
  want_dx=$ndx; want_dy=$ndy
}

apply_direction() {
  dx=$want_dx; dy=$want_dy
}

# ------------------------ Update & Draw ------------------------
step_snake() {
  # move head by (dx,dy); wrap around edges for prototype
  local head=${snake[-1]}
  local hx=${head%%,*}
  local hy=${head##*,}
  local nx=$(( (hx + dx + GRID_W) % GRID_W ))
  local ny=$(( (hy + dy + GRID_H) % GRID_H ))
  # push new head
  snake+=$(pos_key $nx $ny)
  # remove tail to keep length constant
  snake=(${snake[@]:1})
}

clear_screen() { command -v tput >/dev/null 2>&1 && tput clear || printf "\033[2J\033[H"; }
move_to() { command -v tput >/dev/null 2>&1 && tput cup "$1" "$2" || printf "\033[%d;%dH" "$(( $1 + 1 ))" "$(( $2 + 1 ))"; }

# draw header + grid (■ for all cells; snake colored)
draw_play() {
  clear_screen
  # Header (row 0)
  move_to 0 0; printf "%s↑↓←→ / WASD / hjkl | q:Quit%s\n" "$COLOR_TEXT" "$COLOR_RESET"

  # Precompute occupancy map for O(1) lookup
  typeset -A occ; occ=()
  local p
  for p in ${snake[@]}; do occ[$p]=1; done

  # Grid origin at row 1
  local y x key
  for y in {0..$((GRID_H-1))}; do
    move_to $((1+y)) 0
    for x in {0..$((GRID_W-1))}; do
      key=$(pos_key $x $y)
      if [[ -n ${occ[$key]:-} ]]; then
        printf "%s■%s" "$COLOR_SNAKE" "$COLOR_RESET"
      else
        printf "■"
      fi
    done
    printf "\n"
  done
}

draw_start() {
  clear_screen
  local title="Snake (Zsh)"
  local hint1="s: Start"
  local hint2="q: Quit"
  # simple centered-ish layout
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
        # idle; just poll input
        ;;
      PLAYING)
        apply_direction
        step_snake
        draw_play
        ;;
    esac
    msleep "$TICK_MS"
  done
}

main "$@"
