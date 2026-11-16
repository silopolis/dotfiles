## opencode without the secret-named variables of the shell

# An agent can print its environment, and what it prints ends up in its transcript.
# The agent does not need the secrets: its providers come from its own login file.
# So `opencode` is a function that runs the real binary through `env -u NAME`
# for every exported variable whose name matches the pattern below.
#
# - The names are read from the environment at each call: no list lives in this file,
#   and a variable added later is covered with no edit.
# - Only the child is affected: the shell keeps its variables.
# - Arguments and exit status pass through unchanged.
# - Explicit bypass, typed by the user: `command opencode` runs the real binary
#   with the full environment. There is no switch an agent could set from its shell.
# - `command env ... opencode` looks the binary up on PATH, so the function
#   does not call itself.
# - The command substitution is split into words by bash and by zsh;
#   the names hold only letters, digits and underscores.
# - Uppercase names only: lowercase and mixed-case names are not matched.
opencode() {
  command env $(env | sed -n 's/^\([A-Z_][A-Z0-9_]*\)=.*/\1/p' \
    | grep -E '(TOKEN|SECRET|PASSWORD|PASSWD|API_?KEY|ACCESS_?KEY|PRIVATE_?KEY|CREDENTIAL)' \
    | sed 's/^/-u /') opencode "$@"
}

# vim: set syntax=sh :
