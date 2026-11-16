## Why

Every agent started from the user's shells inherits every secret-named variable of the private environment file, and an agent can print its environment: in November 2026 one did, and what it printed was stored in its transcript and sent to the model provider.
opencode, its tools and its plugins do not need those variables: its providers come from its own login file (mode 0600), and `gh`, `git` and `mise` use the keyring login of `gh`.
The agents of the fleet's own runs already start without them; the agents the user starts by hand, and the ones herdr starts in his shells, do not.
Source: request of the orchestrator of a fleet repository, 2026-11-15, decided by the user on 2026-11-16 as the first part of the launcher change (the second part, no export in login shells, is a backlog study); credential handling is audit section 2.1 and F10, F11, F12.

## What Changes

- **A shell function `opencode`** in the shared shell startup (`home/dot_config/shell/rc.d/445-tools_opencode.sh`), defined for bash and zsh interactive shells, that runs the real `opencode` with `env -u NAME` for every exported variable whose name matches an uppercase pattern: `TOKEN`, `SECRET`, `PASSWORD`, `PASSWD`, `API_KEY` (with or without the underscore), `ACCESS_KEY`, `PRIVATE_KEY` and `CREDENTIAL`.
  - The names are computed from the environment at each call, so a variable added later is covered with no edit; the keep-list is empty, because the inventory found no reader inside an agent session.
  - Arguments and the exit status pass through unchanged (`opencode -s <id>`, `run`, `serve`, `attach`).
  - Sockets and paths such as the ssh agent socket, the display authority file and the terminal's public key are not matched.
  - The parent shell keeps its variables, so the clients the user runs himself keep working.
- **A bypass that is explicit**: `command opencode` runs the real binary with the full environment, and is documented as such.
- **Tests** in a scratch directory with synthetic variables, in zsh and in bash, and a live check on a herdr-started agent (count of matching names in the agent process, never the names or values).
- **`AGENTS.md`** gets one line in the Commands section: agents started from a shell run through this function.
- **A signal for adoption**: the design section "Signal darse and the fleet" says what darse and the other fleet repositories can port (the function, the choices, the pattern to recheck, the test contract) and what does not travel; row 27 of the audit's change map records the pointer, and nothing is written to another repository.

## Capabilities

### New Capabilities

- `agent-environment`: which variables an agent started from the user's shells may inherit, how the wrapper decides, what it leaves alone, and how that is checked without printing a name or a value.

### Modified Capabilities

None.

## Impact

- New file `home/dot_config/shell/rc.d/445-tools_opencode.sh`, sourced by `shellrc` like every file of that directory; no data, no template, no script.
- Shell startup gains one function definition and no command: it is not run at startup, only when `opencode` is called.
- Not covered, on purpose: processes that do not go through an interactive shell of the user (a launcher of the desktop, cron, an ssh command, a script that calls the binary by path), other agents (`codex`, `pi`, `goose`), and the processes of the desktop session that already hold the variables.
  Those are the backlog study of secrets held by the desktop session, and the question of agents running key-reading clients, which depends on the agent-harness decision and is out of this change.
- Applying it is a single-target deployment (`chezmoi apply --exclude=scripts ~/.config/shell/rc.d/445-tools_opencode.sh`) and takes effect in new shells only.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
