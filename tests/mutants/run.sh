#!/usr/bin/env bash
# Prove that a suite can fail (`mise run test:mutants`): tests/mutants/run.sh [mutant-id...]
#
# Each row of the table in tests/mutants/README.md names a mutant: the test files to run, the file of the
# source state that it changes, how it changes it, and how many tests must fail. For each one the script
# makes a scratch copy of .chezmoiroot and home/, changes one file of the copy, runs tests/run.sh on the
# named test files with DOTFILES_TEST_SOURCE pointing at the copy, and compares the number of failures.
#   replace <file>   the file of tests/mutants/ replaces the target
#   sed <file>       the sed script of tests/mutants/ is applied to the target
# A mutant that changes nothing is an error: a stale mutant must not pass for a proof.
# The repository is never changed (git status is compared before and after). Exit 0 when every mutant
# makes the expected number of tests fail.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=/dev/null
. "$here/../helpers/common.sh"
cd "$DT_ROOT"

readme=$here/README.md
wanted=("$@")
base=${DOTFILES_TEST_TMPDIR:-${TMPDIR:-/tmp}}
scratch=$(mktemp -d "$base/dotfiles-mutants.XXXXXX")
# shellcheck disable=SC2329  # called by the EXIT trap below
cleanup() {
  case $scratch in
    "$base"/dotfiles-mutants.*) rm -rf -- "$scratch" ;;
  esac
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

trim() {
  local s=$1
  s=${s#"${s%%[![:space:]]*}"}
  s=${s%"${s##*[![:space:]]}"}
  printf '%s' "$s"
}

status_before=$(git status --porcelain 2> /dev/null || true)
problems=0
ran=0

while IFS='|' read -r _ id tests file change expect _; do
  id=$(trim "$id")
  [[ $id =~ ^[a-z0-9][a-z0-9-]*$ ]] || continue
  if [ "${#wanted[@]}" -gt 0 ]; then
    match=0
    for w in "${wanted[@]}"; do [ "$w" = "$id" ] && match=1; done
    [ "$match" -eq 1 ] || continue
  fi
  tests=$(trim "$tests")
  file=$(trim "$file")
  change=$(trim "$change")
  expect=$(trim "$expect")
  ran=$((ran + 1))

  copy=$scratch/$id/source
  mkdir -p -- "$copy"
  cp -a -- "$DT_ROOT/.chezmoiroot" "$DT_ROOT/home" "$copy/"
  target=$copy/$file
  if [ ! -f "$target" ]; then
    printf 'mutant %s: the file %s does not exist: the mutant is stale\n' "$id" "$file"
    problems=$((problems + 1))
    continue
  fi
  before=$(sha256sum < "$target")
  case $change in
    "replace "*) cp -- "$here/${change#replace }" "$target" ;;
    "sed "*) sed -i -f "$here/${change#sed }" "$target" ;;
    *)
      printf 'mutant %s: unknown change "%s"\n' "$id" "$change"
      problems=$((problems + 1))
      continue
      ;;
  esac
  after=$(sha256sum < "$target")
  if [ "$before" = "$after" ]; then
    printf 'mutant %s: the change left %s as it was: the mutant is stale\n' "$id" "$file"
    problems=$((problems + 1))
    continue
  fi

  read -ra test_args <<< "$tests"
  set +e
  out=$(DOTFILES_TEST_SOURCE=$copy DOTFILES_TEST_REPORTS=$scratch/$id/reports "$DT_TESTS_DIR/run.sh" "${test_args[@]}" 2>&1)
  set -e
  fails=$(printf '%s\n' "$out" | sed -n 's/^tests: [0-9]*, failures: \([0-9]*\), skipped: .*/\1/p' | tail -n 1)
  fails=${fails:-none}

  verdict=FAILED
  case $expect in
    "exactly "*) [ "$fails" = "${expect#exactly }" ] && verdict=ok ;;
    "at least "*) [[ $fails =~ ^[0-9]+$ ]] && [ "$fails" -ge "${expect#at least }" ] && verdict=ok ;;
  esac
  printf 'mutant %s: %s failures (expected %s): %s\n' "$id" "$fails" "$expect" "$verdict"
  [ "$verdict" = ok ] || problems=$((problems + 1))
done < "$readme"

if [ "$ran" -eq 0 ]; then
  printf 'test:mutants: no mutant found in %s\n' "$readme" >&2
  exit 2
fi

status_after=$(git status --porcelain 2> /dev/null || true)
if [ "$status_before" != "$status_after" ]; then
  printf 'test:mutants: the repository changed during the run\n'
  problems=$((problems + 1))
else
  printf 'repository untouched\n'
fi
printf 'mutants: %s run, %s problems\n' "$ran" "$problems"
[ "$problems" -eq 0 ]
