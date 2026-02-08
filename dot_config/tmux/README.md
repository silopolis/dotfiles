# Tmux Configuration with Floating Dev Tools


A sleek tmux setup featuring centered popup windows for your favorite terminal tools, vim-style navigation, and the Catppuccin theme.


## ✨ Features

- **Floating popup windows** (90% size, auto-close) for lazygit, lazydocker, nnn, k9s, and btop
- **fzf-powered command launcher** with zsh history completion
- **Interactive tools menu** for quick access
- Vim-style pane navigation (h/j/k/l)
- Beautiful Catppuccin theme integration


## 🚀 Quick Start

**Requirements:**

- tmux 3.2+ (for `display-popup` support)
- TPM (Tmux Plugin Manager)
- [lazygit](https://github.com/jesseduffield/lazygit), [lazydocker](https://github.com/jesseduffield/lazydocker), [nnn](https://github.com/jarun/nnn), [k9s](https://github.com/derailed/k9s), [btop](https://github.com/aristocratos/btop), [fzf](https://github.com/junegunn/fzf)

**Install:**
1. Clone to `~/.config/tmux/`
2. Install TPM: `git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm`
3. Open tmux and press `C-b I` to install plugins
4. Reload: `C-b C-r`

## 🪟 Floating Windows

Launch dev tools in centered popups that preserve your current directory and close automatically when you exit:

```
┌────────────────────────────────────────────┐
│  ┌────────────────────────────────────┐    │
│  │                                    │    │
│  │        Your Tool (90%)             │    │
│  │     (auto-closes on quit)          │    │
│  │                                    │    │
│  └────────────────────────────────────┘    │
└────────────────────────────────────────────┘
```

**Direct Launch:**

| Key     | Tool                                                      | Description                              |
| ------- | --------------------------------------------------------- | ---------------------------------------- |
| `C-b G` | [lazygit](https://github.com/jesseduffield/lazygit)       | Git TUI                                  |
| `C-b D` | [lazydocker](https://github.com/jesseduffield/lazydocker) | Docker management                        |
| `C-b F` | [nnn](https://github.com/jarun/nnn)                       | File browser                             |
| `C-b K` | [k9s](https://github.com/derailed/k9s)                    | Kubernetes clusters                      |
| `C-b S` | [btop](https://github.com/aristocratos/btop)              | System monitor                           |
| `C-b E` | $EDITOR                                                   | Your editor (vim/nvim/etc.)              |
| `C-b P` | [fzf](https://github.com/junegunn/fzf)                    | Command history picker (with dual modes) |
| `C-b T` | menu                                                      | Interactive tool selector                |

**Using the Menu (C-b T):**
Press `C-b T`, then select:

- `D` → lazydocker
- `F` → nnn
- `G` → lazygit
- `K` → k9s
- `S` → btop
- `E` → editor ($EDITOR)
- `P` → custom command with fzf
- `Q` → cancel

**Command Launcher (C-b P) with Dual Modes:**

The `C-b P` launcher provides an interactive fzf interface to browse and execute commands from your zsh history:

1. Press `C-b P` → Opens popup with fzf showing your command history
2. Select a command using arrow keys
3. Choose execution mode:
    - **Enter** → **Tool Mode**: Runs command in the popup, auto-closes when done (perfect for TUI apps like vim, lazygit)
    - **Alt-Enter** → **Command Mode**: Runs command, shows output, waits for any keypress (great for commands like `ls`, `pwd` where you want to see results)

This smart launcher preserves your current working directory and handles both interactive tools and regular commands seamlessly.

**Editor (C-b E):**
Press `C-b E` to open your default editor (set via `$EDITOR` environment variable) in a popup. Perfect for quick file edits without leaving your current tmux layout. The popup closes automatically when you quit the editor.


## ⌨️ Key Bindings

**Navigation:**

- `h/j/k/l` or `Alt+arrows` → move between panes
- `Shift+arrows` → switch windows

**Window Management:**

- `_` / `\|` → split horizontal / vertical
- `z` → zoom pane
- `C-s` → synchronize panes (all panes receive same input)

**System:**

- `C-r` → reload tmux config
- `C-b C-r` → reload config

**Floating Tools:**

- `C-b G/D/F/K/S/E/P/T` → launch tools (see above)


## 🛠️ Customization

**Change popup size:**
Edit `tmux.conf` and modify the `-w` and `-h` flags:

```
bind G display-popup -w 80% -h 80% -E -d "#{pane_current_path}" "lazygit"
```

**Add your own tool:**

```
bind X display-popup -w 90% -h 90% -E -d "#{pane_current_path}" "your-tool"
```


## 🔧 Troubleshooting

- **"command not found"** → Ensure tools are in your PATH
- **C-b E doesn't work** → Set $EDITOR environment variable (e.g., `export EDITOR=vim` in your shell config)
- **Popups don't work** → Upgrade to tmux 3.2+: `tmux -V`
- **fzf shows empty** → Check `~/.zsh_history` exists and is readable
- **Config not loading** → Run `tmux source-file ~/.config/tmux/tmux.conf`


## 📁 Structure

```
~/.config/tmux/
├── tmux.conf           # Main configuration
├── tmuxline.conf       # Status bar theme
├── plugins/            # TPM-managed plugins
└── scripts/
    └── tool-launcher.sh # fzf history launcher
```

Happy coding! 🎉


<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
