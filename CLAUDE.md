# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Homelab Manager is a unified bash-based tool for collecting and managing system specifications, testing bandwidth, and monitoring real-time stats across multiple homelab nodes. The main script (`homelab.sh`) provides both an interactive menu-driven interface and a CLI mode for gathering neofetch data, testing bandwidth, and managing nodes on local and remote systems via SSH.

## Key Commands

### Running the Application

**Interactive Mode (Default)**:
```bash
./homelab.sh
```

**CLI Mode**:
```bash
./homelab.sh help                      # Show help
./homelab.sh specs all                 # Get all specs
./homelab.sh bandwidth all             # Test all bandwidth
./homelab.sh status                    # Check status
./homelab.sh node add NAME USER HOST   # Add node
```

### Running Tests
```bash
./test-homelab.sh
```

### Making Scripts Executable
```bash
chmod +x homelab.sh test-homelab.sh
```

## Architecture

### Core Data Storage

The application stores its configuration in the user's home directory:

- **`~/.homelab_nodes`**: Stores node entries in format `NODE_NAME|SSH_USER@SSH_HOST`
- **`~/.homelab_onboarded`**: Tracks which nodes have SSH keys configured (one node name per line)
- **`~/.homelab_keys/`**: Directory containing SSH keys for node authentication (`id_rsa` and `id_rsa.pub`)

### Main Script Structure (`homelab.sh`)

The script is organized into distinct sections and operates in two modes:

**Mode Selection** (Entry Point):
- Checks if CLI arguments provided: if yes, runs `run_cli_mode()`, if no, enters interactive menu loop

**Interactive Mode**:
1. **Menu System**: Arrow-key navigation with menu state tracking (`show_menu()`)
2. **Verbose Mode**: Toggle between standard and detailed neofetch output using custom config files
3. **Remote Execution**: SSH-based execution of neofetch commands on remote nodes
4. **Live Stats**: Tmux-based multi-pane htop monitoring across all nodes
5. **Bandwidth Testing**: Interactive selection for local/remote/all node bandwidth tests

**CLI Mode** (`run_cli_mode()` function):
- Parses command arguments and dispatches to appropriate handlers
- Supports commands: `specs`, `status`, `bandwidth`, `node`, `export`, `verbose`, `live-stats`, `test`, `help`
- Returns exit codes and formatted output suitable for scripts

### Critical Functions

**System Specs Functions**:
- **`get_local_specs()`**: Executes neofetch locally, conditionally using verbose config
- **`get_remote_specs(node_name, ssh_addr)`**: Executes neofetch on remote nodes via SSH, handles installation and configuration
- **`setup_verbose_config()`**: Creates local neofetch config with extended metrics
- **`setup_verbose_config_remote(ssh_addr)`**: Uses heredoc to inject verbose neofetch config on remote systems via SSH

**Bandwidth Testing Functions**:
- **`ensure_speedtest()`**: Checks and installs speedtest-cli if needed
- **`test_bandwidth_local()`**: Tests local system bandwidth, returns upload/download speeds
- **`test_bandwidth_remote(ssh_addr, node_name)`**: Tests bandwidth on remote node via SSH
- **`view_bandwidth_interactive()`**: Interactive menu for bandwidth testing (available in interactive mode only)

**Node Management Functions**:
- **`onboard_node()`**: Manages SSH key generation and distribution using `ssh-copy-id`
- **`add_node()`**: Adds new node to configuration with connectivity validation
- **`remove_node()`**: Removes node from configuration and onboarded list

**Utility Functions**:
- **`view_live_stats()`**: Creates persistent tmux session with htop panes for each node
- **`run_cli_mode(command, args...)`**: Dispatcher for CLI mode commands
- **`show_help()`**: Displays comprehensive help with all CLI commands and examples

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

## Testing Framework (`test-homelab.sh`)

The test suite provides interactive verification of all components (interactive and CLI modes):

- **Test Structure**: Same arrow-key menu system as main script
- **Test Results Tracking**: Global counters for PASSED/FAILED/SKIPPED tests
- **Test Categories**:
  - **Core Tests**: Dependency checking (bash, grep, sed, ssh, awk)
  - **Neofetch Tests**: Installation and output validation
  - **Node Management Tests**: Node file CRUD operations with backup/restore
  - **Verbose Config Tests**: Configuration generation and field verification
  - **Tmux Tests**: Session/pane creation and layout
  - **Script Integrity Tests**: Syntax validation with `bash -n`
  - **CLI Mode Tests**: Help command, specs command, status command, bandwidth command, node management commands
  - **Bandwidth Tests**: Speedtest installation and integration verification

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

**Optional**:
- speedtest-cli (bandwidth testing - auto-installed if needed)

**Auto-installed**:
- tmux (live stats view)
- lm-sensors (verbose mode temperature readings)

**Standard utilities**: grep, sed, awk, ping, ssh-keygen, ssh-copy-id

## New Features (Bandwidth Testing)

### Bandwidth Testing System

The bandwidth testing feature (`test_bandwidth_*` functions) provides:
- **Local bandwidth testing**: Tests the local system's upload/download speeds
- **Remote bandwidth testing**: Tests bandwidth on each configured node via SSH
- **Automated setup**: Automatically installs `speedtest-cli` if not present
- **CLI and Interactive modes**: Available in both modes
  - Interactive: Menu-driven with options for local/remote/all
  - CLI: Command-line: `homelab bandwidth [local|NODE_NAME|all]`

### Output Format

Bandwidth test results use speedtest-cli's `--simple` format:
```
download_speed
upload_speed
ping_latency
```

All output is prefixed with node information for easy identification.

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
