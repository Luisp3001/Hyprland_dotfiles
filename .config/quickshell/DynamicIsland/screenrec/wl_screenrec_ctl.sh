#!/usr/bin/env bash
# Bridge between Quickshell Dynamic Island and wl-screenrec.
# State: $XDG_RUNTIME_DIR/quickshell-wl-screenrec.env
#
# Usage:
#   wl_screenrec_ctl.sh start -- [args...]    # passes args to wl-screenrec
#   wl_screenrec_ctl.sh status                # one-line JSON on stdout
#   wl_screenrec_ctl.sh pause|resume|stop
#
# Pause uses SIGSTOP/SIGCONT on the wl-screenrec process (best-effort; audio sync may drift).

set -euo pipefail

_state_base="${XDG_RUNTIME_DIR:-}"
if [[ -n "$_state_base" ]] && [[ -w "$_state_base" ]]; then
  export QS_SCREENREC_STATE="$_state_base/quickshell-wl-screenrec.env"
else
  export QS_SCREENREC_STATE="${TMPDIR:-/tmp}/quickshell-wl-screenrec.env"
fi
unset _state_base
mkdir -p "$(dirname "$QS_SCREENREC_STATE")"

die() {
  echo "$*" >&2
  exit 1
}

# Use bash 4.2+ built-in for current epoch seconds
get_now() {
  printf '%(%s)T' -1
}

cmd_status() {
  if [[ ! -f "$QS_SCREENREC_STATE" ]]; then
    echo '{"state": "idle"}'
    return 0
  fi

  # Read state safely
  # shellcheck disable=SC1090
  source "$QS_SCREENREC_STATE"

  if [[ -z "${PID:-}" ]] || ! kill -0 "$PID" 2>/dev/null; then
    rm -f "$QS_SCREENREC_STATE"
    echo '{"state": "idle"}'
    return 0
  fi

  if [[ "${STATE:-}" == "paused" ]]; then
    echo "{\"state\": \"paused\", \"pid\": $PID, \"elapsed_sec\": ${FROZEN_ELAPSED_SEC:-0}}"
  elif [[ "${STATE:-}" == "recording" ]]; then
    local now
    now=$(get_now)
    local started=${STARTED_AT:-$now}
    local accum=${PAUSED_ACCUM:-0}
    local elapsed=$(( now - started - accum ))
    (( elapsed < 0 )) && elapsed=0
    echo "{\"state\": \"recording\", \"pid\": $PID, \"elapsed_sec\": $elapsed}"
  else
    echo '{"state": "idle"}'
  fi
}

cmd_start() {
  shift
  if [[ "${1:-}" != "--" ]]; then
    die "usage: wl_screenrec_ctl.sh start -- [wl-screenrec arguments...]"
  fi
  shift

  if ! command -v wl-screenrec >/dev/null 2>&1; then
    die "wl-screenrec not found in PATH"
  fi

  if [[ -f "$QS_SCREENREC_STATE" ]]; then
    # shellcheck disable=SC1090
    source "$QS_SCREENREC_STATE"
    if [[ -n "${PID:-}" ]] && kill -0 "$PID" 2>/dev/null; then
      die "wl_screenrec_ctl: already recording (pid $PID)"
    fi
  fi

  # Auto-generate filename if not provided
  local args=("$@")
  local has_filename=false
  for arg in "${args[@]}"; do
    if [[ "$arg" == "-f" ]] || [[ "$arg" == "--filename" ]] || [[ "$arg" == --filename=* ]]; then
      has_filename=true
      break
    fi
  done

  if ! $has_filename; then
    local videos_dir="$HOME/Videos"
    if command -v xdg-user-dir >/dev/null 2>&1; then
      local xdg_dir
      xdg_dir="$(xdg-user-dir VIDEOS)"
      # Use -ef to check if it's the same directory as HOME, which is more robust than string comparison.
      if [[ -n "$xdg_dir" && -d "$xdg_dir" && ! "$xdg_dir" -ef "$HOME" ]]; then
        videos_dir="$xdg_dir"
      fi
    fi
    mkdir -p "$videos_dir"
    local timestamp
    timestamp=$(date +%Y-%m-%d_%H-%M-%S)
    # Prepend to args to ensure it's prioritized
    args=("-f" "$videos_dir/Screenrecord_$timestamp.mp4" "${args[@]}")
  fi

  wl-screenrec "${args[@]}" &
  local rec_pid=$!

  sleep 0.25
  if ! kill -0 "$rec_pid" 2>/dev/null; then
    die "wl-screenrec exited immediately (check arguments / Wayland / encoder)"
  fi

  local now
  now=$(get_now)
  cat > "$QS_SCREENREC_STATE" <<EOF
STATE="recording"
PID=$rec_pid
STARTED_AT=$now
PAUSED_ACCUM=0
EOF
}

cmd_pause() {
  if [[ ! -f "$QS_SCREENREC_STATE" ]]; then
    die "wl_screenrec_ctl: not recording"
  fi

  # shellcheck disable=SC1090
  source "$QS_SCREENREC_STATE"

  if [[ "${STATE:-}" != "recording" ]]; then
    die "wl_screenrec_ctl: pause only valid while recording"
  fi

  local now
  now=$(get_now)
  local started=${STARTED_AT:-$now}
  local accum=${PAUSED_ACCUM:-0}
  local frozen=$(( now - started - accum ))
  (( frozen < 0 )) && frozen=0

  if ! kill -STOP "$PID" 2>/dev/null; then
    rm -f "$QS_SCREENREC_STATE"
    die "wl_screenrec_ctl: process already gone"
  fi

  cat > "$QS_SCREENREC_STATE" <<EOF
STATE="paused"
PID=$PID
STARTED_AT=$started
PAUSED_ACCUM=$accum
FROZEN_ELAPSED_SEC=$frozen
PAUSED_AT=$now
EOF
}

cmd_resume() {
  if [[ ! -f "$QS_SCREENREC_STATE" ]]; then
    die "wl_screenrec_ctl: not recording"
  fi

  # shellcheck disable=SC1090
  source "$QS_SCREENREC_STATE"

  if [[ "${STATE:-}" != "paused" ]]; then
    die "wl_screenrec_ctl: resume only valid while paused"
  fi

  local now
  now=$(get_now)
  local paused_at=${PAUSED_AT:-$now}
  local extra=$(( now - paused_at ))
  (( extra < 0 )) && extra=0
  local new_accum=$(( ${PAUSED_ACCUM:-0} + extra ))

  if ! kill -CONT "$PID" 2>/dev/null; then
    rm -f "$QS_SCREENREC_STATE"
    die "wl_screenrec_ctl: process already gone"
  fi

  cat > "$QS_SCREENREC_STATE" <<EOF
STATE="recording"
PID=$PID
STARTED_AT=${STARTED_AT:-$now}
PAUSED_ACCUM=$new_accum
EOF
}

cmd_stop() {
  if [[ ! -f "$QS_SCREENREC_STATE" ]]; then
    exit 0
  fi

  # shellcheck disable=SC1090
  source "$QS_SCREENREC_STATE"

  if [[ -z "${PID:-}" ]]; then
    rm -f "$QS_SCREENREC_STATE"
    exit 0
  fi

  if [[ "${STATE:-}" == "paused" ]]; then
    kill -CONT "$PID" 2>/dev/null || true
    sleep 0.05
  fi

  kill -INT "$PID" 2>/dev/null || true

  # Wait briefly for graceful shutdown
  local i
  for i in {1..40}; do
    if ! kill -0 "$PID" 2>/dev/null; then
      break
    fi
    sleep 0.05
  done

  kill -TERM "$PID" 2>/dev/null || true
  rm -f "$QS_SCREENREC_STATE"
}

case "${1:-}" in
  status) cmd_status ;;
  start) cmd_start "$@" ;;
  pause) cmd_pause ;;
  resume) cmd_resume ;;
  stop) cmd_stop ;;
  *)
    die "usage: wl_screenrec_ctl.sh {status|start -- ...|pause|resume|stop}"
    ;;
esac
