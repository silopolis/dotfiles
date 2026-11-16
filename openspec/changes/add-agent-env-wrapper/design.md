## Context

- The private environment file is sourced by `home/dot_config/shell/rc.d/010-env_user.sh` in every interactive shell; `shellrc` then sources every `rc.d/*.sh` in name order, in bash and in zsh.
- herdr starts an agent by typing the bare command (`opencode`) into an interactive shell of the pane; checked on 2026-11-16 with a marker function standing in for the agent: the function ran, so a shell function applies to herdr-started agents.
  The same holds for a command typed by hand.
- Where `opencode` resolves today: mise's own install directory (mise's activation puts it ahead of the shims); a function wins over both, whatever the `PATH` order.
- Inventory of 2026-11-15 (start evidence for the study in the backlog): the environment file holds 10 assignments, all uppercase, all matching the pattern below; nothing in a skill, task, script, config or MCP server reads them inside an agent session; opencode keeps its providers in its own login file (mode 0600).
- Checked on 2026-11-16 with the real binary: with every matching name removed from its environment, `opencode --version` prints its version, `opencode models anthropic` lists models and `opencode auth list` shows its three stored providers; a child of the stripped command holds 0 matching names in `/proc/<pid>/environ`.
- The secrets also sit in the systemd user manager and in the terminal and multiplexer processes (import of the login environment by the display manager's startup): a wrapper does not touch them.

## Goals / Non-Goals

**Goals:**

- Agents started from the user's interactive shells, and their children, hold none of the secret-named variables.
- A variable added to the environment file tomorrow is covered with no edit.
- Nothing the user runs himself in the shell changes.

**Non-Goals:**

- Stopping the export of the secrets in login shells, or cleaning the systemd user manager (backlog study: secrets held by the desktop session).
- Whether an agent may run key-reading command-line clients, and giving them keys by other means (backlog item, depends on the agent-harness decision); until it is studied those clients are not allowed in agent sessions.
- Other agents (`codex`, `pi`, `goose`): the same function can be generalised later; nothing is built for them now.
- A plugin or a guard that redacts output (a safety net that comes in the guard's own repository).

## Decisions

### A shell function, in its own rc.d file

```sh
# 445-tools_opencode.sh: start opencode without the secret-named variables of the shell
opencode() {
  command env $(env | sed -n 's/^\([A-Z_][A-Z0-9_]*\)=.*/\1/p' \
    | grep -E '(TOKEN|SECRET|PASSWORD|PASSWD|API_?KEY|ACCESS_?KEY|PRIVATE_?KEY|CREDENTIAL)' \
    | sed 's/^/-u /') opencode "$@"
}
```

- `command env ... opencode` makes `env` look the binary up on `PATH`, so the function does not call itself.
- The command substitution is split into words by both shells (zsh splits the result of `$(...)`, though not a plain variable), and the names hold only letters, digits and underscores, so no glob or quote can appear.
- Names are read from `env` output at each call: the environment of the call, not a list written in a file.
- Alternatives considered:
  - a wrapper script earlier in `PATH`: mise's activation reorders `PATH` in every shell, so the order is not stable; a function does not depend on it;
  - a hard-coded list of the ten names: it would name secret variables in a public repository, and miss the eleventh;
  - setting the function from a mise task or an alias: an alias cannot hold the loop, a task is not run when herdr types the command.

### Pattern

Uppercase names containing `TOKEN`, `SECRET`, `PASSWORD`, `PASSWD`, `API_KEY` or `APIKEY`, `ACCESS_KEY` or `ACCESSKEY`, `PRIVATE_KEY` or `PRIVATEKEY`, `CREDENTIAL`.
Checked on 2026-11-15 against the environment of an agent's shell and against the 143 names of the systemd user manager: it matches the ten variables of the environment file and the revoked GitHub variable, and nothing else.
`SSH_AUTH_SOCK`, `XAUTHORITY`, `KITTY_PUBLIC_KEY` and `STARSHIP_SESSION_KEY` are not matched, as the scratch test shows (they hold paths, sockets or public values).
Lowercase and mixed-case names are not matched: none exists today, and a lowercase secret would be a different convention to decide (noted as a limit, below).

### Keep-list: none, and no switch

The inventory found no reader inside an agent session.
There is no environment variable or flag that turns the stripping off, because a switch an agent can set from its own shell would defeat it; the explicit bypass is `command opencode`, typed by the user.

### Where the file sits

`rc.d/445-tools_opencode.sh`, in the tools block, after mise's activation (415), because it documents the reason and the tools block is where the shell's tool setup lives.
The order does not matter for correctness: the function runs `opencode` at call time.

### Checks without printing a name or a value

The counts use `tr '\0' '\n' < /proc/<pid>/environ | cut -d= -f1 | grep -Ec <pattern>`, with the pid of the agent process from `herdr pane process-info`, never the names.

## Risks / Trade-offs

- [Risk] The function covers only shells that source the rc.d files. → Documented in the proposal (impact): cron, ssh commands, desktop launchers and scripts that call the binary by path are not covered; the study in the backlog decides what else.
- [Risk] A script or an agent runs `command opencode` or the binary by path and bypasses the function. → The wrapper protects against the default path, not against a hostile agent; the guard and the study are the next layers.
- [Risk] A multi-line value that holds a line shaped like an assignment adds one extra `-u` for a name that is not set. → `env -u` of an unset name is a no-op; seen in the tests and harmless.
- [Risk] The name computation is slow on a huge environment. → Measured on 2026-11-16 with 143 names: about 6 ms, paid once per agent start.
- [Trade-off] When no real `opencode` exists the message comes from `env` (`env: 'opencode': No such file or directory`, status 127) and not from the shell's own `command not found`.
- [Limit] Lowercase and mixed-case secret names are not covered. → None exists on this machine; the check in the tasks fails loudly if one appears (it counts names that match case-insensitively and are not matched by the pattern).
- [Limit] The kitty and herdr processes, and the systemd user manager, keep the variables until a re-login or reboot, and a restart of them from the desktop re-imports them. → Not in this change; the backlog study owns it, and the check after the next reboot is a backlog item.
- [Trade-off] A function in the user's startup files shadows `opencode` for every call in that shell, including `opencode --version`; the cost is one `env` call.

## Open Questions

- Should the same function cover `codex`, `pi` and `goose` once the agent-harness decision is taken? Default: no, one function per agent when it is decided.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
