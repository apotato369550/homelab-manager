# Homelab Manager - AI Context Guide

## Project Overview

**Homelab Manager** is a unified bash-based tool designed to manage a fleet of Linux nodes. It abstracts the complexity of gathering system specifications, monitoring performance, and testing network bandwidth into a simple interactive menu or CLI interface.

**Key Capabilities:**
- **Hybrid Interface:** Fully functional Interactive Menu (arrow navigation) AND scriptable CLI for automation
- **Agentless Architecture:** Uses SSH and standard utilities (neofetch, htop, speedtest-cli) without installing agents
- **Persistent Configuration:** Stores state in user's home directory (~/.homelab_nodes, ~/.homelab_keys/)
- **Dual-Mode Operations:** Supports both interactive and headless/CLI execution modes
- **Real-Time Monitoring:** Live system stats via tmux multi-pane htop across all nodes
- **Bandwidth Testing:** Network speed testing with speedtest-cli on local and remote systems
- **Verbose Metrics:** Extended diagnostics including temperatures (lm-sensors), IPs, and CPU usage

## Current Implementation Status

### Active Features
- **Interactive Mode**: Arrow-key navigation menu with state tracking
- **CLI Mode**: Command-line argument parsing and execution
- **System Specs**: Neofetch-based specifications gathering (local and remote)
- **SSH Management**: Dedicated key generation and distribution via ssh-copy-id
- **Live Monitoring**: Tmux-based multi-pane htop for real-time viewing
- **Bandwidth Testing**: speedtest-cli integration for upload/download/latency metrics
- **Verbose Mode**: Extended metrics with temperature, IP, and process information
- **Node Management**: Add, remove, list, and onboard operations
- **Test Suite**: Comprehensive interactive testing framework

### Build and Running

This project is pure Bash with no compilation required.

```bash
# Interactive Mode (Default)
./homelab.sh

# CLI Mode Examples
./homelab.sh specs all              # Gather neofetch specs from all nodes
./homelab.sh bandwidth all          # Run speedtests on all nodes
./homelab.sh live-stats             # Open tmux dashboard
./homelab.sh node add <name> <user> <host>
./homelab.sh help                   # Show all CLI commands

# Testing
./test-homelab.sh
```

## Architecture Overview

### File Structure
- `homelab.sh`: Main executable (850+ lines) with dual-mode support
- `homelab-specs.sh`: Legacy specs gathering logic (may be deprecated)
- `test-homelab.sh`: Comprehensive test suite with interactive menu
- `README.md`: User documentation
- `CLAUDE.md`: Detailed AI context
- `CHANGELOG.md`: Version history

### Data Storage
- `~/.homelab_nodes`: Node database (format: `NAME|USER@HOST`)
- `~/.homelab_onboarded`: Tracks which nodes have SSH keys configured
- `~/.homelab_keys/`: Directory containing dedicated SSH key pair (id_rsa, id_rsa.pub)

### Core Functions

**Mode Selection:**
- Checks `$#` (number of arguments) to determine CLI vs interactive mode
- CLI mode: calls `run_cli_mode()` with arguments
- Interactive mode: enters `show_menu()` loop

**System Specs Functions:**
- `get_local_specs()`: Executes neofetch locally with optional verbose config
- `get_remote_specs(node_name, ssh_addr)`: SSH-based neofetch on remote nodes
- `setup_verbose_config()`: Creates local neofetch config with extended metrics
- `setup_verbose_config_remote(ssh_addr)`: Injects verbose config via heredoc SSH

**Bandwidth Testing:**
- `ensure_speedtest()`: Installs speedtest-cli if missing
- `test_bandwidth_local()`: Tests local system bandwidth
- `test_bandwidth_remote(ssh_addr, node_name)`: Tests remote node bandwidth
- `view_bandwidth_interactive()`: Menu-driven bandwidth testing

**Node Management:**
- `onboard_node()`: SSH key generation and distribution
- `add_node()`: Adds new node with connectivity validation
- `remove_node()`: Removes node from configuration
- `list_nodes()`: Displays configured nodes

**Live Monitoring:**
- `view_live_stats()`: Creates persistent tmux session with htop for all nodes
- Handles TTY allocation with ssh -t flag
- Supports session reattachment if already running
- Auto-generates split panes for multi-node viewing

**Utilities:**
- `run_cli_mode(command, args...)`: Dispatcher for CLI commands
- `show_menu()`: Interactive menu with arrow-key navigation
- `show_help()`: Displays comprehensive CLI help

## Verbose Mode Implementation

When enabled, injects additional metrics into neofetch output:
- CPU/GPU temperatures (requires lm-sensors)
- Public/Private IP addresses
- CPU usage and load information
- Active user sessions
- Battery status

**Implementation Details:**
- Local: Uses `awk` to modify neofetch config (line 93-100)
- Remote: Uses `sed -i` within heredoc SSH session (line 117-151)
- Config file location: `~/.config/neofetch/config.conf`

## SSH Key Management Pattern

1. Script generates dedicated key pair in `~/.homelab_keys/` directory
2. Avoids polluting user's main `~/.ssh/` with project-specific keys
3. Uses `ssh-copy-id` to distribute public key to remote nodes
4. All SSH commands specify `-i "$KEYS_DIR/id_rsa"` for key selection
5. Enables passwordless authentication for all remote operations

## Error Handling Patterns

- Extensive stderr redirection (`2>/dev/null`, `> /dev/null 2>&1`)
- Suppresses installation output and missing command errors
- Fallback logic for missing dependencies
- Silent failure patterns for optional features
- Informative stdout messages for user feedback

## Testing Framework

`test-homelab.sh` provides interactive verification:

**Test Categories:**
- Core dependency checks (bash, grep, sed, ssh, awk)
- Neofetch installation and output validation
- Node management CRUD operations
- Verbose config generation and field verification
- Tmux session/pane creation
- Script syntax validation with `bash -n`
- CLI mode command testing
- Bandwidth integration verification

**Test Features:**
- Arrow-key menu navigation matching main script
- Result tracking (PASSED/FAILED/SKIPPED)
- Backup/restore of test data
- Interactive test selection

## Development Conventions

- **Safety:** Suppress installation noise with `2>/dev/null`
- **Dependencies:** Runtime checks with graceful fallback
- **Formatting:** ANSI colors (Green=Success, Red=Error)
- **Remote Execution:** Prefer heredoc over scp for cleanliness
- **Config Modification:** awk (local) vs sed (remote) for compatibility
- **SSH Usage:** Always specify dedicated key with -i flag

## Key Implementation Details

### Heredoc SSH Execution
Multi-line scripts sent to remote systems via SSH without temporary files:
```bash
ssh -i "$KEYS_DIR/id_rsa" "user@host" bash << 'REMOTE_EOF'
  # Multi-line commands here
REMOTE_EOF
```

### Mode Detection Pattern
```bash
if [[ $# -gt 0 ]]; then
  run_cli_mode "$@"
else
  show_menu
fi
```

### Tmux Live Stats Pattern
Creates persistent session with automatic reattachment:
```bash
if tmux list-sessions -F '#S' | grep -q "^$SESSION_NAME$"; then
  tmux attach-session -t "$SESSION_NAME"
else
  # Create new session with split panes
fi
```

## Dependencies

**Required:**
- bash (core functionality)
- ssh (remote node access)
- neofetch (system information)

**Optional:**
- speedtest-cli (bandwidth testing - auto-installed)

**Auto-Installed:**
- tmux (live stats view)
- lm-sensors (verbose mode temperature readings)

**Standard Utilities:** grep, sed, awk, ping, ssh-keygen, ssh-copy-id

## Development Guidelines

1. **Testing:** Run `./test-homelab.sh` before committing changes
2. **SSH:** Understand key distribution patterns and verify before changes
3. **Error Handling:** Be cautious about breaking silent operations
4. **Heredoc Usage:** Test command syntax locally before embedding
5. **Menu Navigation:** Test thoroughly before modifying state machine
