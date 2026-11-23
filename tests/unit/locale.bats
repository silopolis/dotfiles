#!/usr/bin/env bats
# Proves the spec shell-environment, requirement "Working locale", on rc.d/020-env_defaults.sh alone, in zsh and in
# bash, with a stub `locale -a` that lists the locales the test says are generated: no LC_ALL is set, an inherited
# LANG, LC_ALL or LC_* that names a locale which is not generated is dropped (names compared without case and without
# the hyphen), an unset LANG becomes en_US.UTF-8 when that is generated and C.UTF-8 otherwise, LANGUAGE defaults to
# en_US:en, and `locale -a` runs once. The smoke file environment-locale.bats starts real shells.

load ../helpers/bats/load

setup() {
  setup_scratch
  FILE=$(dt_source_file dot_config/shell/rc.d/020-env_defaults.sh)
  STUBS=$BATS_TEST_TMPDIR/stubs
  BARE=$BATS_TEST_TMPDIR/bare
  STUB_LOG=$BATS_TEST_TMPDIR/locale.log
  : > "$STUB_LOG"
  dt_realbin "$STUBS"
  dt_realbin "$BARE"
  cat > "$STUBS/locale" << 'STUB'
#!/bin/sh
printf 'call\n' >> "$STUB_LOG"
[ "$1" = -a ] || exit 0
[ -n "$STUB_LOCALES" ] && printf '%s\n' "$STUB_LOCALES"
exit 0
STUB
  chmod 0755 "$STUBS/locale"
  MISSING=$(dt_missing_locale)
  STATE='printf "%s|%s|%s|%s\n" "${LANG-unset}" "${LC_ALL-unset}" "${LC_CTYPE-unset}" "${LANGUAGE-unset}"'
}

# start SHELL LOCALES [VAR=value ...] -- SNIPPET: source the file under env -i, run the snippet, print what it prints.
# LOCALES is what the stub `locale -a` lists, one per line.
start() {
  local sh=$1 list=$2 vars=() snippet
  shift 2
  while [ "$1" != -- ]; do
    vars+=("$1")
    shift
  done
  shift
  snippet=$1
  # bash prints its own warning, before any file runs, when it is started with a missing LC_ALL: it is not ours
  env -i HOME="$DT_HOME" PATH="${DT_STUB_PATH:-$STUBS}" STUB_LOG="$STUB_LOG" STUB_LOCALES="$list" "${vars[@]}" \
    "$(dt_shell_path "$sh")" -c ". '$FILE'; $snippet" < /dev/null 2>&1 | grep -v 'warning: setlocale' || true
}

# both SHELLS expect: run the same start in zsh and bash and compare with the expected output
both() { # LOCALES EXPECTED [VAR=value ...] -- SNIPPET
  local list=$1 want=$2 sh got
  shift 2
  for sh in zsh bash; do
    got=$(start "$sh" "$list" "$@")
    [ "$got" = "$want" ] || fail "$sh: expected [$want] got [$got]"
  done
}

LIST_FR_EN=$'C\nC.utf8\nPOSIX\nen_US.utf8\nfr_FR.utf8'
LIST_FR=$'C\nC.utf8\nPOSIX\nfr_FR.utf8'

@test "sourcing the file prints nothing" {
  both "$LIST_FR" '' -- 'true'
}

@test "no LC_ALL is set, whatever the locales and the inherited LANG" {
  both "$LIST_FR" 'fr_FR.UTF-8|unset|unset|en_US:en' LANG=fr_FR.UTF-8 -- "$STATE"
  both "$LIST_FR_EN" 'en_US.UTF-8|unset|unset|en_US:en' -- "$STATE"
}

@test "an inherited LANG that is generated is kept, whatever its case and its hyphen" {
  both "$LIST_FR" 'fr_FR.UTF-8|unset|unset|en_US:en' LANG=fr_FR.UTF-8 -- "$STATE"
  both "$LIST_FR" 'fr_FR.utf8|unset|unset|en_US:en' LANG=fr_FR.utf8 -- "$STATE"
  both "$LIST_FR" 'FR_fr.Utf-8|unset|unset|en_US:en' LANG=FR_fr.Utf-8 -- "$STATE"
}

@test "an inherited LANG that is not generated is dropped, and an unset LANG gets the default" {
  both "$LIST_FR_EN" 'en_US.UTF-8|unset|unset|en_US:en' LANG="$MISSING" -- "$STATE"
  both "$LIST_FR" 'C.UTF-8|unset|unset|en_US:en' LANG="$MISSING" -- "$STATE"
}

@test "an unset LANG becomes en_US.UTF-8 when it is generated and C.UTF-8 otherwise" {
  both "$LIST_FR_EN" 'en_US.UTF-8|unset|unset|en_US:en' -- "$STATE"
  both "$LIST_FR" 'C.UTF-8|unset|unset|en_US:en' -- "$STATE"
  both $'C\nPOSIX' 'C.UTF-8|unset|unset|en_US:en' -- "$STATE"
}

@test "an inherited LC_ALL and LC_CTYPE that are not generated are dropped, one that is generated stays" {
  both "$LIST_FR" 'fr_FR.UTF-8|unset|unset|en_US:en' LANG=fr_FR.UTF-8 LC_ALL="$MISSING" LC_CTYPE="$MISSING" -- "$STATE"
  both "$LIST_FR" 'fr_FR.UTF-8|fr_FR.UTF-8|unset|en_US:en' LANG=fr_FR.UTF-8 LC_ALL=fr_FR.UTF-8 LC_CTYPE="$MISSING" -- "$STATE"
  both "$LIST_FR" 'fr_FR.UTF-8|fr_FR.UTF-8' LANG=fr_FR.UTF-8 LC_TIME=fr_FR.UTF-8 -- 'printf "%s|%s\n" "$LANG" "${LC_TIME-unset}"'
}

@test "every LC_ variable that names a missing locale is dropped" {
  local v sh got
  for v in LC_ALL LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE LC_MONETARY LC_MESSAGES LC_PAPER LC_NAME LC_ADDRESS LC_TELEPHONE LC_MEASUREMENT LC_IDENTIFICATION; do
    for sh in zsh bash; do
      got=$(start "$sh" "$LIST_FR" "$v=$MISSING" -- "printf '%s\n' \"\${$v-unset}\"")
      [ "$got" = unset ] || fail "$sh: $v stayed [$got]"
    done
  done
}

@test "the locales C and POSIX are always valid, even when the list does not name them" {
  both "$LIST_FR" 'C|C|unset|en_US:en' LANG=C LC_ALL=C -- "$STATE"
  both "$LIST_FR" 'POSIX|unset|unset|en_US:en' LANG=POSIX -- "$STATE"
}

@test "LANGUAGE defaults to en_US:en and an inherited value stays" {
  both "$LIST_FR" 'fr_FR.UTF-8|unset|unset|en_US:en' LANG=fr_FR.UTF-8 -- "$STATE"
  both "$LIST_FR" 'fr_FR.UTF-8|unset|unset|en_US' LANG=fr_FR.UTF-8 LANGUAGE=en_US -- "$STATE"
}

@test "locale -a runs once, and also when nothing is inherited" {
  local sh
  for sh in zsh bash; do
    : > "$STUB_LOG"
    start "$sh" "$LIST_FR" LANG=fr_FR.UTF-8 LC_ALL="$MISSING" LC_CTYPE="$MISSING" -- true > /dev/null
    assert_equal "$(wc -l < "$STUB_LOG")" 1
    : > "$STUB_LOG"
    start "$sh" "$LIST_FR" -- true > /dev/null
    assert_equal "$(wc -l < "$STUB_LOG")" 1
  done
}

@test "LANG and LANGUAGE are exported" {
  both "$LIST_FR" 'LANG=fr_FR.UTF-8
LANGUAGE=en_US:en' LANG=fr_FR.UTF-8 -- '/usr/bin/env | grep -E "^(LANG|LANGUAGE)=" | sort'
}

@test "without a locale tool nothing inherited is dropped and an unset LANG becomes C.UTF-8" {
  DT_STUB_PATH=$BARE both "$LIST_FR" 'fr_FR.UTF-8|zz|unset|en_US:en' LANG=fr_FR.UTF-8 LC_ALL=zz -- "$STATE"
  DT_STUB_PATH=$BARE both "$LIST_FR" 'C.UTF-8|unset|unset|en_US:en' -- "$STATE"
}

@test "when locale -a lists nothing, nothing inherited is dropped" {
  both '' 'fr_FR.UTF-8|zz|unset|en_US:en' LANG=fr_FR.UTF-8 LC_ALL=zz -- "$STATE"
}

@test "the editor and the pager keep their defaults and an inherited value" {
  both "$LIST_FR" 'vim less' -- 'printf "%s %s\n" "$EDITOR" "$PAGER"'
  both "$LIST_FR" 'nvim more' EDITOR=nvim PAGER=more -- 'printf "%s %s\n" "$EDITOR" "$PAGER"'
}

@test "the file is POSIX: shellcheck -s sh accepts it, and zsh -n and bash -n parse it" {
  require_tool shellcheck
  run "$DT_TOOL_SHELLCHECK" -s sh "$FILE"
  assert_success
  zsh -n "$FILE"
  bash -n "$FILE"
}

@test "the file sets no LC_ALL: no assignment or export of it" {
  assert_equal "$(grep -v '^[[:space:]]*#' "$FILE" | grep -c -E '(export[[:space:]]+)?LC_ALL=' || true)" 0
}
