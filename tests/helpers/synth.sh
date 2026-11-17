#!/usr/bin/env bash
# Synthetic variables and canaries, built at run time from parts: plain bash, no bats.
# Source it (`. tests/helpers/synth.sh`; it loads common.sh), or call one function:
#   tests/helpers/synth.sh <function> [args...]
#
# Provides:
#   dt_syn_names               the nine synthetic variable names that match the secret pattern, one per line
#   dt_keep_names              names that the secret pattern must leave alone (one is lowercase), one per line
#   dt_late_name, dt_fake_name two more synthetic names that match the pattern (a variable exported late, and
#                              a name that sits inside the value of another variable)
#   dt_alpha_name, dt_beta_name the two names of the synthetic private environment file (the first matches the
#                              secret pattern, the second does not)
#   dt_canary N                canary number N (1 to 99), at least 20 characters
#   dt_canary_spaced N         canary number N with a space inside, for a value that holds one
#   dt_all_canaries            every canary of the run, one per line: the list the scans search for
#   dt_syn_value NAME          the canary of a name of dt_syn_names
#   dt_write_syn_file FILE     write `export NAME='value'` lines for the nine names
#   dt_unset_name              the variable that rc.d/010-env_user.sh unsets, read from that file
#
# No committed file holds a secret-looking name or a canary: names are a prefix and an upper-cased
# fragment, a canary is a prefix, a number and a lowercase word. A canary must not look like a key
# to a scanner, because it also lands in scratch files that a scan may read.

# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

DT_CANARY_PAD=rabbitdonkeymeadow
# Fragments of the names, lowercase; each matches one fragment of the secret pattern.
DT_NAME_PART=token
DT_SYN_FRAGMENTS=(api_key "$DT_NAME_PART" db_password apikey accesskey private_key credential passwd secret_sauce)
# Names that look secret-like but are not matched, as lowercase fragments; the last one stays lowercase.
DT_KEEP_FRAGMENTS=(ssh_auth_sock xauthority kitty_public_key starship_session_key demo_lower_token)

dt_syn_names() {
  local f
  for f in "${DT_SYN_FRAGMENTS[@]}"; do
    printf 'DEMO_%s\n' "${f^^}"
  done
}

dt_keep_names() {
  local f n=${#DT_KEEP_FRAGMENTS[@]} i=0
  for f in "${DT_KEEP_FRAGMENTS[@]}"; do
    i=$((i + 1))
    if [ "$i" -eq "$n" ]; then
      printf '%s\n' "$f"
    else
      printf '%s\n' "${f^^}"
    fi
  done
}

dt_late_name() {
  printf 'DEMO_LATER_%s\n' "${DT_NAME_PART^^}"
}

dt_fake_name() {
  printf 'DEMO_FAKE_%s\n' "${DT_NAME_PART^^}"
}

dt_alpha_name() {
  printf 'DEMO_ALPHA_%s\n' "${DT_NAME_PART^^}"
}

dt_beta_name() {
  printf 'DEMO_BETA_SETTING\n'
}

dt_canary() {
  printf 'cnry%04d%s\n' "$1" "$DT_CANARY_PAD"
}

dt_canary_spaced() {
  printf 'cnry%04d %s\n' "$1" "${DT_CANARY_PAD%?}"
}

dt_all_canaries() {
  local i
  for i in $(seq 1 99); do
    dt_canary "$i"
    dt_canary_spaced "$i"
  done
}

# The value of the i-th synthetic name: the third has a space, to prove that values are not word-split.
dt_syn_value() {
  local i=0 n
  while IFS= read -r n; do
    i=$((i + 1))
    if [ "$n" = "$1" ]; then
      if [ "$i" -eq 3 ]; then
        dt_canary_spaced "$i"
      else
        dt_canary "$i"
      fi
      return 0
    fi
  done < <(dt_syn_names)
  printf 'dt_syn_value: unknown name\n' >&2
  return 1
}

dt_write_syn_file() {
  local n
  : > "$1"
  while IFS= read -r n; do
    printf "export %s='%s'\n" "$n" "$(dt_syn_value "$n")" >> "$1"
  done < <(dt_syn_names)
}

# The name is read from the `unset` line of the file at run time: the tests hold DEMO_ names only.
dt_unset_name() {
  local f
  f=$(dt_source_file dot_config/shell/rc.d/010-env_user.sh)
  sed -n 's/^unset \([A-Z_][A-Z0-9_]*\)$/\1/p' "$f" | head -n 1
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  fn=${1:?usage: synth.sh <function> [args...]}
  shift
  "$fn" "$@"
fi
