#!/usr/bin/env bash
# Pull experiment output without touching the device UI.
#
#   tools/capture.sh sim-stream start|stop  live unified log (probe + SDK debug events) → /tmp/observe-capture.ndjson
#   tools/capture.sh sim-stream show        print the streamed capture as one line per message
#   tools/capture.sh sim [--last 15m]      persisted unified log (probe lines only — SDK debug lines are not persisted)
#   tools/capture.sh sim-file              the app's Documents/probe.jsonl (simulator)
#   tools/capture.sh device-file [udid]    the app's Documents/probe.jsonl (USB device, devicectl)
#   tools/capture.sh device-log [--last 15m]   unified log via `log collect --device` (USB device)
#
# Both streams are one JSON object per line. Probe lines: {"ts","screen","event",...}.
# SDK lines (subsystem com.corbado.observe): "Track: <event_name> <event json>".
set -euo pipefail
BUNDLE=com.corbado.observe-example
PREDICATE='subsystem == "com.corbado.observe-example" OR subsystem == "com.corbado.observe"'
mode=${1:-sim}; shift || true

STREAM_FILE=/tmp/observe-capture.ndjson
STREAM_PID="${STREAM_FILE%.ndjson}.pid"
normalize() {
  python3 -c '
import sys, json
for line in sys.stdin:
    try: o = json.loads(line)
    except ValueError: continue
    if "eventMessage" not in o: continue
    print(json.dumps({"ts": o.get("timestamp"), "source": o.get("subsystem","").split(".")[-1], "msg": o["eventMessage"]}))'
}

case "$mode" in
  sim-stream)
    case "${1:-show}" in
      start)
        [ -f "$STREAM_PID" ] && { kill "$(cat "$STREAM_PID")" 2>/dev/null || true; rm -f "$STREAM_PID"; }
        : > "$STREAM_FILE"
        nohup xcrun simctl spawn booted log stream --level debug --style ndjson --predicate "$PREDICATE" \
          > "$STREAM_FILE" 2>/dev/null &
        echo $! > "$STREAM_PID"
        echo "streaming to $STREAM_FILE"
        ;;
      stop) [ -f "$STREAM_PID" ] && { kill "$(cat "$STREAM_PID")" 2>/dev/null || true; rm -f "$STREAM_PID"; } ;;
      show) normalize < "$STREAM_FILE" ;;
    esac
    ;;
  sim)
    xcrun simctl spawn booted log show --predicate "$PREDICATE" --style ndjson --info --debug "$@" | normalize
    ;;
  sim-file)
    cat "$(xcrun simctl get_app_container booted "$BUNDLE" data)/Documents/probe.jsonl"
    ;;
  device-file)
    out=$(mktemp -d)
    xcrun devicectl device copy from --device "${1:-$(xcrun devicectl list devices --hide-headers --columns Identifier | head -1)}" \
      --domain-type appDataContainer --domain-identifier "$BUNDLE" \
      --source Documents/probe.jsonl --destination "$out/probe.jsonl" >/dev/null
    cat "$out/probe.jsonl"
    ;;
  device-log)
    archive=$(mktemp -d)/capture.logarchive
    log collect --device --output "$archive" "$@" >/dev/null
    log show --archive "$archive" --predicate "$PREDICATE" --style ndjson --info --debug
    ;;
  *) echo "unknown mode: $mode" >&2; exit 2 ;;
esac
