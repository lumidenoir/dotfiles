#!/bin/bash
wpctl status | awk '
/^Audio/ { audio=1 }
/^Video/ { audio=0 }
audio && /Sinks:/ { sinks=1; next }
audio && sinks && /Sources:/ { sinks=0 }
audio && sinks {
  line=$0
  active = ($0 ~ /\*/) ? "true" : "false"
  gsub(/^[^0-9]+/, "", line)
  match(line, /^([0-9]+)\./, a); id = a[1]
  sub(/^[0-9]+\.[[:space:]]*/, "", line)
  sub(/[[:space:]]+\[.*/, "", line)
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
  if (id != "" && line != "") print id "|" active "|" line
}
'
