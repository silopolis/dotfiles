#!/usr/bin/env bats
# Proves the spec shell-environment, requirement "Working locale": real shells, the kinds of the study, started on a
# scratch render under env -i with the session's LANG. A test that needs fr_FR.UTF-8 skips and says so when this machine
# does not generate it. Counts and public values only: no scenario prints a locale variable of the real environment.

load ../helpers/bats/load

setup_file() {
  require_tool chezmoi
  RENDER_DEST=$(dt_render "$BATS_FILE_TMPDIR/render") || return 1
  export RENDER_DEST
}

setup() {
  dt_prepare_home "$BATS_TEST_TMPDIR/home" "$RENDER_DEST"
  require_shell zsh
  require_shell bash
}

need_locale() {
  dt_locale_generated "$1" || skip "the locale $1 is not generated on this machine"
}

@test "no forced LC_ALL: every kind that loads the environment starts without it and keeps the LANG it was started with" {
  need_locale fr_FR.UTF-8
  local kind got
  for kind in $(dt_kinds_env); do
    case $kind in
      *-nolang) continue ;;
    esac
    got=$(dt_kind_run "$kind" 'printf "@@L=%s|%s\n" "${LC_ALL-<unset>}" "${LANG-<unset>}"' | sed -n 's/^@@L=//p' | tail -n 1)
    [ "$got" = '<unset>|fr_FR.UTF-8' ] || fail "$kind: LC_ALL and LANG are [$got]"
  done
}

@test "no forced LC_ALL in the kinds started without LANG either" {
  local kind
  for kind in zsh-i-nolang bash-i-nolang bash-li-nolang; do
    assert_equal "$(dt_kind_value "$kind" LC_ALL)" '<unset>'
  done
}

@test "no locale warning from the user's files in any kind that loads the environment, nor from a child perl" {
  require_tool perl
  local kind
  for kind in $(dt_kinds_env); do
    assert_equal "$(dt_kind_locale_warnings "$kind")" 0
  done
}

@test "no locale warning from the user's files in the kinds that load nothing either" {
  require_tool perl
  assert_equal "$(dt_kind_locale_warnings zsh-c)" 0
  assert_equal "$(dt_kind_locale_warnings bash-c)" 0
}

# the lines that a child perl prints about the locale (bash and /etc/profile print theirs before any user file runs)
perl_warnings() { # KIND VAR=value...
  local kind=$1
  shift
  dt_kind_run "$kind" 'perl -e1' "$@" | grep -c 'locale failed' || true
}

@test "an inherited missing locale is dropped in an interactive zsh and an interactive bash, and a child perl does not warn" {
  require_tool perl
  local kind missing
  missing=$(dt_missing_locale)
  for kind in zsh-i bash-i; do
    assert_equal "$(dt_kind_value "$kind" LC_ALL LC_ALL="$missing" LC_CTYPE="$missing")" '<unset>'
    assert_equal "$(dt_kind_value "$kind" LC_CTYPE LC_ALL="$missing" LC_CTYPE="$missing")" '<unset>'
    assert_equal "$(perl_warnings "$kind" LC_ALL="$missing" LC_CTYPE="$missing")" 0
  done
}

@test "an inherited LANG that is not generated is dropped too, and the default takes its place" {
  local kind missing want=C.UTF-8
  missing=$(dt_missing_locale)
  dt_locale_generated en_US.UTF-8 && want=en_US.UTF-8
  for kind in zsh-i bash-i; do
    assert_equal "$(dt_kind_value "$kind" LANG LANG="$missing")" "$want"
  done
}

@test "an unset LANG becomes en_US.UTF-8 when it is generated and C.UTF-8 otherwise" {
  local kind want=C.UTF-8
  dt_locale_generated en_US.UTF-8 && want=en_US.UTF-8
  for kind in zsh-i-nolang bash-i-nolang bash-li-nolang; do
    assert_equal "$(dt_kind_value "$kind" LANG)" "$want"
  done
}

@test "LANGUAGE defaults to en_US:en in every kind that loads the environment" {
  local kind
  for kind in $(dt_kinds_env); do
    assert_equal "$(dt_kind_value "$kind" LANGUAGE)" 'en_US:en'
  done
}

@test "the man alias takes effect: LANG=C gives an English day name where the session LANG is French" {
  need_locale fr_FR.UTF-8
  local kind
  for kind in zsh-i bash-i; do
    assert_equal "$(dt_kind_run "$kind" 'printf "@@D=%s\n" "$(LANG=C date -d 2026-11-20 +%A)"' | sed -n 's/^@@D=//p' | tail -n 1)" Friday
    assert_equal "$(dt_kind_run "$kind" 'printf "@@D=%s\n" "$(date -d 2026-11-20 +%A)"' | sed -n 's/^@@D=//p' | tail -n 1)" vendredi
  done
}
