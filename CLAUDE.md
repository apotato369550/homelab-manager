# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Homelab Specs Gatherer is a bash-based terminal application for collecting and managing system specifications across multiple homelab nodes. The main script (`homelab-specs.sh`) provides an interactive menu-driven interface for gathering neofetch data from local and remote systems via SSH.

## Key Commands

### Running the Application
```bash
./homelab-specs.sh
```

### Running Tests
```bash
./test-homelab-specs.sh
```

### Making Scripts Executable
```bash
chmod +x homelab-specs.sh test-homelab-specs.sh
```

## Architecture

### Core Data Storage

The application stores its configuration in the user's home directory:

- **`~/.homelab_nodes`**: Stores node entries in format `NODE_NAME|SSH_USER@SSH_HOST`
- **`~/.homelab_onboarded`**: Tracks which nodes have SSH keys configured (one node name per line)
- **`~/.homelab_keys/`**: Directory containing SSH keys for node authentication (`id_rsa` and `id_rsa.pub`)

### Main Script Structure (`homelab-specs.sh`)

The script is organized around these key components:

1. **Menu System**: Arrow-key navigation (`show_menu()` at line 27-43) with menu state tracking
2. **Verbose Mode**: Toggle between standard and detailed neofetch output using custom config files
3. **Remote Execution**: SSH-based execution of neofetch commands on remote nodes
4. **Live Stats**: Tmux-based multi-pane htop monitoring across all nodes

### Critical Functions

- **`get_local_specs()`** (line 190): Executes neofetch locally, conditionally using verbose config
- **`get_remote_specs()`** (line 304): Executes neofetch on remote nodes via SSH, handles installation and configuration
- **`setup_verbose_config()`** (line 82): Creates local neofetch config with extended metrics
- **`setup_verbose_config_remote()`** (line 103): Uses heredoc to inject verbose neofetch config on remote systems via SSH
- **`view_live_stats()`** (line 453): Creates persistent tmux session with htop panes for each node
- **`onboard_node()`** (line 247): Manages SSH key generation and distribution using `ssh-copy-id`

### Verbose Mode Implementation

Verbose mode modifies the neofetch `print_info()` function to include additional metrics:
- CPU/GPU temperatures (requires `lm-sensors`)
- Public/Private IP addresses
- CPU usage, processes, users
- Battery status

The implementation uses two approaches:
- **Local**: `awk` to find and replace the `print_info()` function in config file (line 93-100)
- **Remote**: `sed` in-place editing within a heredoc SSH session (line 117-151)

### Tmux Live Stats Architecture

The `view_live_stats()` function creates a persistent session:
1. Creates new detached session with local htop
2. Splits window vertically for each remote node (line 478-480)
3. Uses `ssh -t` flag for proper TTY allocation (required for interactive htop)
4. Applies tiled layout for optimal viewing (line 483)
5. Reattaches to existing session if already running (line 461-464)

## Testing Framework (`test-homelab-specs.sh`)

The test suite provides interactive verification of all components:

- **Test Structure**: Same arrow-key menu system as main script
- **Test Results Tracking**: Global counters for PASSED/FAILED/SKIPPED tests (line 22-24)
- **Test Categories**:
  - Dependency checking (bash, grep, sed, ssh, awk)
  - Neofetch installation and output validation
  - Node file CRUD operations with backup/restore
  - Verbose config generation and field verification
  - Tmux session/pane creation and layout
  - Script syntax validation with `bash -n`

## Important Patterns

### SSH Key Management
The script generates a dedicated SSH key pair specifically for homelab management (stored in `~/.homelab_keys/`). When onboarding nodes, it uses `ssh-copy-id` to distribute the public key. All subsequent SSH commands use `-i "$KEYS_DIR/id_rsa"` to specify this key.

### Config File Manipulation
Two different approaches for modifying neofetch configs:
- **Local systems**: Use `awk` for cross-platform compatibility
- **Remote systems**: Use `sed -i` within heredoc to avoid file transfer overhead

### Error Handling
The script uses extensive stderr redirection (`2>/dev/null` and `> /dev/null 2>&1`) to suppress dependency installation output and missing command errors. Most commands include fallback logic (e.g., line 192-195 for neofetch installation).

### Heredoc Usage
Remote configuration is performed using bash heredocs (line 113-151) to execute multi-line scripts on remote systems without temporary files.

## Dependencies

**Required**:
- bash (core functionality)
- ssh (remote node access)
- neofetch (system information gathering)

**Auto-installed**:
- tmux (live stats view)
- lm-sensors (verbose mode temperature readings)

**Standard utilities**: grep, sed, awk, ping, ssh-keygen, ssh-copy-id

## Output Format

Exported specs files use this structure:
```
================================
Homelab Specs Report
Generated: [timestamp]
================================

>>> LOCAL NODE <<<
[neofetch output]

>>> NODE_NAME (SSH_ADDR) <<<
[neofetch output]
```

Files are saved with timestamp: `homelab_specs_YYYY-MM-DD_HH-MM-SS.txt`
