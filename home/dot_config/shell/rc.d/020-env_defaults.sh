## Configuration and environment defaults

### Locale

# LC_ALL is never set here: it overrides LANG and every LC_* variable, so it would defeat the session's own settings
# (KDE's region settings, /etc/default/locale) and a command's `LANG=C man`.
# The locale of the session is kept. What cannot work is dropped: an inherited LANG, LC_ALL or LC_* that names a locale
# which is not generated on this machine would make bash, perl and others print `setlocale` warnings at every start.
# One `locale -a` and one awk decide it, names compared without case and without the hyphen (`fr_FR.UTF-8` is listed as
# `fr_FR.utf8`); C and POSIX are always valid. Without a list (no `locale` tool) nothing is dropped.
# The awk prints shell statements made of constants only: `unset NAME` for a name in the list below, and whether
# en_US.UTF-8 is generated.
_env_en_us=0
eval "$(locale -a 2> /dev/null | awk '
  { k = tolower($0); gsub("-", "", k); have[k] = 1; n++ }
  END {
    if (n == 0) exit
    print "_env_en_us=" (("en_us.utf8" in have) ? 1 : 0)
    m = split("LANG LC_ALL LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE LC_MONETARY LC_MESSAGES LC_PAPER LC_NAME LC_ADDRESS LC_TELEPHONE LC_MEASUREMENT LC_IDENTIFICATION", names, " ")
    for (i = 1; i <= m; i++) {
      v = ENVIRON[names[i]]
      if (v == "") continue
      k = tolower(v)
      gsub("-", "", k)
      if (k == "c" || k == "posix" || (k in have)) continue
      print "unset " names[i]
    }
  }')"

# An unset LANG: English with UTF-8 when it is generated, the built-in C.UTF-8 otherwise.
if [ -z "${LANG:-}" ]; then
  if [ "$_env_en_us" = 1 ]; then
    LANG=en_US.UTF-8
  else
    LANG=C.UTF-8
  fi
fi
export LANG
unset _env_en_us
# Messages stay in English while formats follow LANG
export LANGUAGE="${LANGUAGE:-en_US:en}"

### Utilities
export EDITOR="${EDITOR:-vim}"
export PAGER="${PAGER:-less}"

# vim: set syntax=sh :
