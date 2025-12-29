# Homelab Specs Gatherer

A bash-based terminal application for collecting and managing system specifications across multiple homelab nodes.

## Features

- **Interactive Menu System**: Arrow-key navigation for intuitive control
- **Local & Remote Specs**: Gather system information from local machine and remote nodes via SSH
- **Verbose Mode**: Extended metrics including temperatures, IP addresses, and CPU usage
- **Live Stats Monitoring**: Real-time htop monitoring across all nodes using tmux
- **SSH Key Management**: Automatic SSH key generation and distribution for secure node access

## Quick Start

### Prerequisites

- bash
- ssh
- neofetch

### Running the Application

```bash
chmod +x homelab-specs.sh
./homelab-specs.sh
```

### Running Tests

```bash
chmod +x test-homelab-specs.sh
./test-homelab-specs.sh
```

## Usage

1. **Add Nodes**: Use the menu to add homelab nodes (format: `NODE_NAME` and `SSH_USER@SSH_HOST`)
2. **Onboard Nodes**: Generate and distribute SSH keys for passwordless authentication
3. **Gather Specs**: Collect system information from all configured nodes
4. **View Live Stats**: Monitor real-time system metrics across nodes
5. **Toggle Verbose Mode**: Enable extended metrics including temperatures and IP addresses

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
- bash
- ssh
- neofetch

**Auto-installed**:
- tmux (for live stats)
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

[Specify your license here]
