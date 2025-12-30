# Homelab Manager

A bash-based unified tool for collecting and managing system specifications, monitoring real-time stats, and testing bandwidth across multiple homelab nodes. Works in both interactive and CLI modes.

## Features

- **Interactive Menu System**: Arrow-key navigation for intuitive control
- **CLI Mode**: Run commands directly without interactive menus (perfect for automation, scripts, and headless environments)
- **Local & Remote Specs**: Gather system information from local machine and remote nodes via SSH
- **Bandwidth Testing**: Test upload/download speeds across nodes using speedtest-cli
- **Verbose Mode**: Extended metrics including temperatures, IP addresses, and CPU usage
- **Live Stats Monitoring**: Real-time htop monitoring across all nodes using tmux
- **SSH Key Management**: Automatic SSH key generation and distribution for secure node access

## Quick Start

### Prerequisites

- bash
- ssh
- neofetch
- speedtest-cli (optional, for bandwidth testing)

### Interactive Mode (Default)

```bash
chmod +x homelab.sh
./homelab.sh
```

### CLI Mode Examples

```bash
# View specs for all nodes
./homelab.sh specs all

# Check node status
./homelab.sh status

# Test bandwidth on all nodes
./homelab.sh bandwidth all

# Add a new node
./homelab.sh node add server1 root 192.168.1.10

# Get help
./homelab.sh help
```

### Running Tests

```bash
chmod +x test-homelab.sh
./test-homelab.sh
```

## Usage

### Interactive Mode
1. **Add Nodes**: Use the menu to add homelab nodes (format: `NODE_NAME` and `SSH_USER@SSH_HOST`)
2. **Onboard Nodes**: Generate and distribute SSH keys for passwordless authentication
3. **Gather Specs**: Collect system information from all configured nodes
4. **View Live Stats**: Monitor real-time system metrics across nodes
5. **Test Bandwidth**: Run bandwidth tests on local/remote/all nodes
6. **Toggle Verbose Mode**: Enable extended metrics including temperatures and IP addresses

### CLI Mode

```bash
# Specifications
homelab specs [local|remote|all]           # Gather system specifications

# Node Management
homelab node add NAME USER HOST           # Add a node
homelab node remove NAME                  # Remove a node
homelab node list                         # List configured nodes
homelab node onboard NAME                 # Setup SSH keys

# System Info
homelab status                             # Check node connectivity
homelab export [PATH]                      # Export specs to file

# Bandwidth Testing
homelab bandwidth [local|NODE_NAME|all]   # Test bandwidth
  local  - Test local system only
  NODE_NAME - Test specific node
  all  - Test all nodes (default)

# Utilities
homelab live-stats                         # View live htop stats
homelab verbose [on|off|toggle]           # Control verbose mode
homelab test                               # Run test suite
homelab help                               # Display help
```

## Configuration

The application stores configuration in your home directory:

- `~/.homelab_nodes`: Node entries in format `NODE_NAME|SSH_USER@SSH_HOST`
- `~/.homelab_onboarded`: Tracks onboarded nodes (one per line)
- `~/.homelab_keys/`: SSH key directory (`id_rsa` and `id_rsa.pub`)

## Architecture

### Core Components

- **Menu System**: Interactive navigation with arrow keys
- **Local Specs Gathering**: Executes neofetch locally with optional verbose output
- **Remote Specs Gathering**: SSH-based execution of neofetch on remote nodes
- **Live Stats**: Tmux-based multi-pane htop monitoring
- **SSH Key Management**: Automatic key generation and distribution via `ssh-copy-id`

### Verbose Mode

Enables additional metrics:
- CPU/GPU temperatures (requires `lm-sensors`)
- Public/Private IP addresses
- CPU usage and process information
- User sessions and battery status

### Live Stats Monitoring

Creates a persistent tmux session with:
- Local system htop in main pane
- Separate panes for each remote node
- Tiled layout for optimal viewing
- Support for reattaching to existing sessions

## Dependencies

**Required**:
- bash (core functionality)
- ssh (remote node access)
- neofetch (system information gathering)

**Optional**:
- speedtest-cli (for bandwidth testing - auto-installed if needed)

**Auto-installed**:
- tmux (for live stats view)
- lm-sensors (for temperature readings in verbose mode)

**Standard Utilities**: grep, sed, awk, ping, ssh-keygen, ssh-copy-id

## Output Format

Exported specs are saved with timestamps and organized as:

```
================================
Homelab Specs Report
Generated: [timestamp]
================================

>>> LOCAL NODE <<<
[system information]

>>> NODE_NAME (SSH_ADDR) <<<
[system information]
```

Files are saved as: `homelab_specs_YYYY-MM-DD_HH-MM-SS.txt`

## License

This project is available under several open-source license options:

- **MIT License**: Simple and permissive. Allows commercial and private use with minimal restrictions.
- **Apache 2.0**: Provides explicit grant of patent rights. Good for larger projects.
- **GPL v3**: Copyleft license requiring derivative works to also be open source.
- **BSD 3-Clause**: Similar to MIT but with additional restrictions on trademark use.

If you haven't specified a license preference, we recommend **MIT License** for maximum compatibility and ease of use.

To set a license, create a `LICENSE` file in the project root with the appropriate license text. Choose the one that best fits your project goals and distribution requirements.

For more information on choosing a license, visit [choosealicense.com](https://choosealicense.com).
