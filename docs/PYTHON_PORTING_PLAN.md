# Python Porting Plan: Homelab Manager

## Executive Summary

Port the homelab-manager from bash (~3,300 lines across 4 scripts) to Python 3.9+. This modernization improves maintainability, testability, and cross-platform compatibility while preserving all existing functionality.

## Scope

**In Scope (Priority Order)**:
1. `homelab.sh` (1,282 lines) → `homelab/cli.py` + `homelab/core.py`
2. `homelab-specs.sh` (587 lines) → `homelab/specs.py`
3. `test-homelab.sh` (855 lines) → `tests/test_homelab.py`
4. `test-homelab-specs.sh` (638 lines) → `tests/test_specs.py`

**Out of Scope**:
- CLAUDE.md, GEMINI.md, README.md, CHANGELOG.md (documentation, reviewed after implementation)

## Architecture

```
homelab-manager/
├── homelab/
│   ├── __init__.py                 # Package init, version
│   ├── cli.py                      # Entry point, argparse, interactive mode
│   ├── core.py                     # Node management, SSH, config storage
│   ├── specs.py                    # Neofetch, verbose config, system info
│   ├── bandwidth.py                # Speedtest, bandwidth testing
│   ├── stats.py                    # Tmux integration, live monitoring
│   ├── power.py                    # Power management (suspend)
│   ├── config.py                   # Home dir paths, config file ops
│   └── ssh.py                      # SSH key management, remote execution
├── tests/
│   ├── __init__.py
│   ├── test_homelab.py             # Integration tests
│   ├── test_specs.py               # Specs & verbose config tests
│   ├── test_core.py                # Node management, config storage
│   ├── test_ssh.py                 # SSH mocking, key management
│   └── conftest.py                 # Pytest fixtures
├── scripts/
│   └── homelab                     # Wrapper script (shebang + python)
├── pyproject.toml                  # Project config (setuptools, pytest, etc)
├── setup.py                        # Package installation
├── requirements.txt                # Runtime dependencies
├── requirements-dev.txt            # Dev dependencies (pytest, black, etc)
└── docs/
    ├── PYTHON_PORTING_PLAN.md      # This file
    ├── ARCHITECTURE.md             # Python architecture overview
    └── API.md                       # Module-level API reference
```

## Module Breakdown

### 1. `homelab/config.py`
**Responsibility**: Configuration and file path management
**Maps From**: Lines 6-13 of `homelab.sh`

```python
class HomelabConfig:
    NODES_FILE: Path          # ~/.homelab_nodes
    ONBOARDED_FILE: Path      # ~/.homelab_onboarded
    KEYS_DIR: Path            # ~/.homelab_keys
    PRIVATE_KEY_PATH: Path    # ~/.homelab_keys/id_rsa
    PUBLIC_KEY_PATH: Path     # ~/.homelab_keys/id_rsa.pub
```

**Functions**:
- `initialize_home_dirs()` - mkdir + touch equivalents
- `read_nodes_file()` - Parse ~/.homelab_nodes → Dict[str, str]
- `write_nodes_file()` - Dict[str, str] → ~/.homelab_nodes
- `read_onboarded_file()` - Parse ~/.homelab_onboarded → Set[str]
- `write_onboarded_file()` - Set[str] → ~/.homelab_onboarded

### 2. `homelab/ssh.py`
**Responsibility**: SSH key management and remote execution
**Maps From**: `onboard_node()`, ssh-keygen/ssh-copy-id calls, SSH remote execution

```python
class SSHManager:
    def generate_key_pair(force: bool = False) -> Tuple[str, str]
    def distribute_key(node_name: str, user: str, host: str, password: Optional[str] = None) -> bool
    def execute_remote(user: str, host: str, cmd: str, key_path: Optional[Path] = None) -> Tuple[int, str, str]
    def test_connection(user: str, host: str) -> bool
```

**Dependencies**:
- `paramiko` library for SSH (superior to subprocess + ssh binary)
- Fallback to `subprocess + ssh` if paramiko unavailable

### 3. `homelab/core.py`
**Responsibility**: Node management and configuration
**Maps From**: `add_node()`, `remove_node()`, node file operations

```python
class Node:
    name: str
    user: str
    host: str
    is_onboarded: bool

class NodeManager:
    def add_node(name: str, user: str, host: str) -> Node
    def remove_node(name: str) -> bool
    def get_node(name: str) -> Optional[Node]
    def list_nodes() -> List[Node]
    def is_onboarded(name: str) -> bool
    def mark_onboarded(name: str) -> None
```

### 4. `homelab/specs.py`
**Responsibility**: System specs collection, neofetch integration, verbose config
**Maps From**: `get_local_specs()`, `get_remote_specs()`, `setup_verbose_config()`

```python
class NeofetchManager:
    def get_local_specs(verbose: bool = False) -> str
    def get_remote_specs(node: Node, verbose: bool = False) -> str
    def setup_verbose_config_local() -> str  # Returns config path
    def setup_verbose_config_remote(user: str, host: str) -> str  # Returns remote config path

class SpecsExporter:
    def export_to_file(specs: Dict[str, str], output_path: Optional[Path] = None) -> Path
    def format_specs_report(specs: Dict[str, str]) -> str
```

### 5. `homelab/bandwidth.py`
**Responsibility**: Bandwidth testing via speedtest-cli
**Maps From**: `test_bandwidth_local()`, `test_bandwidth_remote()`, `ensure_speedtest()`

```python
class BandwidthTester:
    def ensure_speedtest_installed() -> bool
    def test_local() -> BandwidthResult
    def test_remote(node: Node) -> BandwidthResult
    def test_all_nodes(nodes: List[Node]) -> Dict[str, BandwidthResult]

class BandwidthResult:
    download_mbps: float
    upload_mbps: float
    ping_ms: float
    node_name: str
```

### 6. `homelab/stats.py`
**Responsibility**: Live monitoring via tmux
**Maps From**: `view_live_stats()`

```python
class LiveStatsManager:
    def create_session() -> bool
    def attach_to_session() -> None
    def is_session_running() -> bool
```

### 7. `homelab/power.py`
**Responsibility**: Power management (suspend)
**Maps From**: Suspend functions in `homelab.sh`

```python
class PowerManager:
    def suspend_node(node: Node) -> bool
    def suspend_all(nodes: List[Node]) -> Dict[str, bool]
```

### 8. `homelab/cli.py`
**Responsibility**: CLI entry point, argparse, interactive mode
**Maps From**: `run_cli_mode()`, `show_menu()`, interactive loop

```python
class InteractiveMode:
    def run() -> None
    def show_menu() -> None
    def handle_selection(choice: int) -> None

class CLIMode:
    def run(args: argparse.Namespace) -> int

def main():
    parser = argparse.ArgumentParser(...)
    subparsers = parser.add_subparsers(...)
    # specs, status, node, bandwidth, suspend, export, live-stats, verbose, test, help
```

## Implementation Phases

### Phase 1: Foundation (Week 1)
- [ ] Create project structure (pyproject.toml, setup.py)
- [ ] Implement `config.py` (home dir management)
- [ ] Implement `core.py` (node management)
- [ ] Add unit tests for config & core
- **Output**: `homelab/` package installable via pip

### Phase 2: Core Features (Week 2)
- [ ] Implement `ssh.py` (key management, remote execution)
- [ ] Implement `specs.py` (neofetch, verbose config)
- [ ] Implement `bandwidth.py` (speedtest integration)
- [ ] Add integration tests
- **Output**: All system inspection features working

### Phase 3: CLI & Interactive (Week 3)
- [ ] Implement `cli.py` argparse structure
- [ ] Implement interactive mode with curses or blessed
- [ ] Add `stats.py` (tmux integration)
- [ ] Add `power.py` (suspend)
- **Output**: Full CLI + interactive modes functional

### Phase 4: Testing & Polish (Week 4)
- [ ] Port test-homelab.sh → tests/test_homelab.py
- [ ] Port test-homelab-specs.sh → tests/test_specs.py
- [ ] Achieve 80%+ code coverage
- [ ] Add type hints throughout
- **Output**: Comprehensive test suite, production-ready

### Phase 5: Backward Compatibility (Week 5)
- [ ] Create wrapper `scripts/homelab` (bash shebang → python)
- [ ] Verify all existing CLI commands work
- [ ] Document migration path for bash scripts
- [ ] Update README with Python setup
- **Output**: Drop-in replacement for bash version

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Use `pathlib.Path` | Cross-platform, safer than string paths |
| Use `paramiko` for SSH | Better control than subprocess + ssh binary; fallback to subprocess |
| Use `argparse` over Click | Standard library, simpler for this scope |
| Use `curses` for interactive UI | Built-in, matches bash menu UX |
| Single-threaded for v1 | Simpler; can add async in Phase 6+ |
| Poetry for deps | Modern, but setuptools/pip acceptable too |

## Dependencies

**Runtime**:
- Python 3.9+
- paramiko (SSH) - fallback to subprocess
- neofetch (external binary, already required)
- speedtest-cli (already auto-installed by bash version)
- tmux (already required for live-stats)

**Development**:
- pytest (testing)
- pytest-cov (coverage)
- black (formatting)
- mypy (type checking)
- ruff (linting)

## Testing Strategy

**Unit Tests**:
- `test_config.py`: File I/O, path management
- `test_core.py`: Node CRUD, parsing
- `test_ssh.py`: Key generation (mock subprocess), parsing output

**Integration Tests**:
- `test_specs.py`: Neofetch output parsing, config injection
- `test_bandwidth.py`: Speedtest output parsing
- `test_cli.py`: CLI parsing, mode dispatch

**E2E Tests**:
- Filesystem fixtures for `.homelab_nodes` setup
- Mock SSH for safe remote testing
- Full workflow: add node → onboard → get specs → bandwidth

## Backward Compatibility

**Before Deprecation**:
1. Ship Python version alongside bash scripts
2. `scripts/homelab` wrapper routes to either (detectable via shebang)
3. Preserve all CLI flags, output formats, exit codes
4. Keep `homelab-specs.sh` available for legacy users

**Migration Path**:
```bash
# Current (bash)
./homelab.sh specs all

# Transition (Python wrapper)
./homelab specs all  # Auto-detected

# Eventual (bash removed)
homelab specs all    # Installed via pip
```

## Success Criteria

- [ ] All ~3,300 SLOC of bash ported to Python
- [ ] 100% CLI compatibility with original bash version
- [ ] 80%+ test coverage
- [ ] Drop-in replacement: `pip install homelab-manager`
- [ ] ~1,500-2,000 lines of Python (more readable than bash)
- [ ] Type hints on all public APIs
- [ ] Single entry point: `homelab` command

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Paramiko SSH adds complexity | Start with subprocess fallback; add paramiko in Phase 2 |
| Interactive curses UI hard to test | Use blessed library (wraps curses); mock in tests |
| Missing dependencies break workflow | All deps documented; setup.py declares them |
| SSH key security issues | Use standard paramiko + openssh key formats; no inline passwords |

## Timeline

- **Target**: 4-5 weeks
- **MVP (Phase 1-2)**: 2 weeks (no interactive mode, CLI only)
- **Full Release (Phase 1-5)**: 5 weeks

## Files to Create

1. `/docs/PYTHON_PORTING_PLAN.md` ← This file
2. `/docs/ARCHITECTURE.md` - Python module overview
3. `/homelab/__init__.py`, `/homelab/*.py` - 8 modules
4. `/tests/` - Pytest suite
5. `/pyproject.toml`, `/setup.py`, `/requirements*.txt`
6. `/scripts/homelab` - Wrapper script

## Files to Preserve

- Original `homelab.sh`, `homelab-specs.sh`, test scripts (kept for reference/fallback)
- CLAUDE.md, README.md (updated to mention Python version)

---

**Status**: Planning Phase ✓ Ready for Implementation Review
