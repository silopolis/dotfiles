## ADDED Requirements

### Requirement: The Incus setup task is deployed and listed

The repository SHALL deploy the global file task `sys:virt:incus:setup`, executable, with the alias `sys:setup:virt:incus`, so that the host setup for virtualization is found under the object-first name and under the action-first name.

#### Scenario: Task is listed

- **WHEN** `mise tasks ls --global` runs from a directory with no project config
- **THEN** it lists `sys:virt:incus:setup`

#### Scenario: Alias resolves

- **WHEN** `mise run -n sys:setup:virt:incus` runs
- **THEN** it prints `[sys:virt:incus:setup]` as the task it would run

#### Scenario: Action-first pattern finds it

- **WHEN** `mise run -n 'sys:setup:*'` runs
- **THEN** it prints `[sys:virt:incus:setup]` among the tasks it would run

#### Scenario: Target matches the source

- **WHEN** `chezmoi diff --exclude=externals,scripts ~/.config/mise/tasks/sys` runs and then `stat -c '%a' ~/.config/mise/tasks/sys/virt/incus/setup`
- **THEN** the diff prints nothing and the mode is executable

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
