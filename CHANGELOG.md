# Changelog

All notable changes to Homelab Manager are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Root workspace documentation structure

## [0.2.0] - 2025-01-02

### Changed
- Improved tmux pane display with window replacement (cleaner, less cluttered view)
- Each node now gets its own clear view in live stats

### Fixed
- Tmux multi-pane rendering for better visual organization

## [0.1.0] - 2025-12-30

### Added
- Dual-mode operation: Interactive menu and CLI mode support
- System specifications gathering via neofetch (local and remote)
- Bandwidth testing via speedtest-cli
- Live monitoring with tmux/htop integration
- SSH key management with automatic generation and distribution
- Verbose mode for extended metrics (temperatures, IP addresses, CPU usage)
- Interactive menu system with arrow-key navigation
- Node management (add, remove, list, onboard)
- Comprehensive test suite (test-homelab.sh)
- Export specifications to file with timestamps
- Documentation with README.md and CLAUDE.md

### Fixed
- SSH key distribution and management
- Remote command execution via SSH heredoc
- Neofetch installation handling on remote systems
