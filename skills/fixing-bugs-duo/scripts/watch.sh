#!/usr/bin/env bash
# usage: watch.sh <worktree> <tag> [transcript] [poll_seconds] [heartbeat_minutes] [stall_minutes]
wt="$1"
tag="$2"
transcript="${3:-}"
poll="${4:-15}"
beat_min="${5:-20}"
stall_min="${6:-10}"

head_of() { git --no-optional-locks -C "$wt" rev-parse HEAD 2>/dev/null; }

# Wake only for commits A must look at now: Flow: step / fix, or no Flow trailer.
# wip, docs and anchored-adapt-only commits are picked up on the next wake.
needs_review() {
  local shas sha flows
  shas=$(git --no-optional-locks -C "$wt" rev-list "$1..$2" 2>/dev/null) || return 0
  for sha in $shas; do
    flows=$(git --no-optional-locks -C "$wt" log -1 --format=%B "$sha" 2>/dev/null | sed -n 's/^Flow:[[:space:]]*\([^[:space:]]*\).*/\1/p')
    if [ -z "$flows" ] || printf '%s\n' "$flows" | grep -Eqx 'step|fix'; then
      return 0
    fi
  done
  return 1
}

requests_of() {
  if [ -f "$wt/progress.md" ]; then
    grep -c '^### R-' "$wt/progress.md"
  else
    echo 0
  fi
  return 0
}

transcript_len() {
  if [ -n "$transcript" ] && [ -f "$transcript" ]; then wc -c < "$transcript" | tr -d ' '; else echo -1; fi
}

transcript_idle() {
  tail -n 1 "$transcript" 2>/dev/null | grep -Eq '"type"[[:space:]]*:[[:space:]]*"turn_ended"'
}

head=$(head_of)
requests=$(requests_of)
last=$(date +%s)
tlen=$(transcript_len)
tgrew=$last
stall_reported=0
echo "DUO_READY_${tag} head=${head} requests=${requests} transcript=$([ "$tlen" != -1 ] && echo True || echo False)"

while true; do
  sleep "$poll"
  now=$(date +%s)

  h=$(head_of)
  if [ -n "$h" ] && [ "$h" != "$head" ]; then
    if [ -z "$head" ] || needs_review "$head" "$h"; then
      echo "DUO_WAKE_${tag} commit ${h}"
      last=$now
    fi
    head=$h
  fi

  r=$(requests_of)
  if [ "$r" != "$requests" ]; then
    echo "DUO_WAKE_${tag} request ${r}"
    requests=$r
    last=$now
  fi

  t=$(transcript_len)
  if [ "$t" != -1 ]; then
    if [ "$t" != "$tlen" ]; then
      tlen=$t
      tgrew=$now
      stall_reported=0
    elif [ "$stall_reported" = 0 ] && ! transcript_idle && [ $((now - tgrew)) -ge $((stall_min * 60)) ]; then
      echo "DUO_WAKE_${tag} stall"
      stall_reported=1
      last=$now
    fi
  fi

  if [ $((now - last)) -ge $((beat_min * 60)) ]; then
    echo "DUO_WAKE_${tag} heartbeat"
    last=$now
  fi
done
