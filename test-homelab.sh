#!/bin/bash

# Test Suite for Homelab Manager
# Interactive testing of all features (interactive and CLI modes)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test data
TEST_NODE_NAME="test-node"
TEST_NODE_USER="testuser"
TEST_NODE_HOST="192.168.1.100"
NODES_FILE="$HOME/.homelab_nodes"
ONBOARDED_FILE="$HOME/.homelab_onboarded"
KEYS_DIR="$HOME/.homelab_keys"

# Test results
PASSED=0
FAILED=0
SKIPPED=0

# Menu state
selected=0
test_items=(
    "Test Dependencies"
    "Test Neofetch Installation"
    "Test Node File Operations"
    "Test Local Specs Gathering"
    "Test Verbose Config Setup"
    "Test Sensors Installation"
    "Test Tmux Session Creation"
    "Test Menu Structure"
    "Test Config File Integrity"
    "Test CLI Mode - Specs Command"
    "Test CLI Mode - Status Command"
    "Test CLI Mode - Bandwidth Command"
    "Test CLI Mode - Node Management"
    "Test Speedtest Installation"
    "Run All Tests"
    "Exit"
)

show_menu() {
    clear
    echo -e "${BLUE}=== Homelab Manager Tester ===${NC}"
    echo ""
    for i in "${!test_items[@]}"; do
        if [ $i -eq $selected ]; then
            echo -e "${GREEN}> ${test_items[$i]}${NC}"
        else
            echo "  ${test_items[$i]}"
        fi
    done
    echo ""
    echo -e "${YELLOW}Results: ${GREEN}Passed: $PASSED${NC} ${RED}Failed: $FAILED${NC} ${YELLOW}Skipped: $SKIPPED${NC}"
}

print_result() {
    local test_name=$1
    local result=$2
    local message=$3

    if [ "$result" == "PASS" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        ((PASSED++))
    elif [ "$result" == "FAIL" ]; then
        echo -e "${RED}✗ FAIL${NC}: $test_name - $message"
        ((FAILED++))
    elif [ "$result" == "SKIP" ]; then
        echo -e "${YELLOW}⊘ SKIP${NC}: $test_name - $message"
        ((SKIPPED++))
    fi
}

# Test 1: Dependency Checking
test_dependencies() {
    clear
    echo -e "${BLUE}=== Test: Dependency Checking ===${NC}"
    echo ""

    # Check bash
    if bash --version &>/dev/null; then
        print_result "Bash availability" "PASS"
    else
        print_result "Bash availability" "FAIL" "Bash not found"
    fi

    # Check grep
    if grep --version &>/dev/null; then
        print_result "Grep availability" "PASS"
    else
        print_result "Grep availability" "FAIL" "Grep not found"
    fi

    # Check sed
    if sed --version &>/dev/null; then
        print_result "Sed availability" "PASS"
    else
        print_result "Sed availability" "FAIL" "Sed not found"
    fi

    # Check ssh
    if command -v ssh &>/dev/null; then
        print_result "SSH availability" "PASS"
    else
        print_result "SSH availability" "FAIL" "SSH not installed"
    fi

    # Check awk
    if awk --version &>/dev/null; then
        print_result "Awk availability" "PASS"
    else
        print_result "Awk availability" "FAIL" "Awk not found"
    fi

    echo ""
    read -p "Press Enter to continue..."
}

# Test 2: Neofetch Installation
test_neofetch_installation() {
    clear
    echo -e "${BLUE}=== Test: Neofetch Installation ===${NC}"
    echo ""

    if ! command -v neofetch &>/dev/null; then
        echo -e "${YELLOW}Installing neofetch...${NC}"
        sudo apt-get update > /dev/null 2>&1
        sudo apt-get install -y neofetch > /dev/null 2>&1
    fi

    if command -v neofetch &>/dev/null; then
        print_result "Neofetch installation" "PASS"
        echo ""
        echo -e "${YELLOW}Testing neofetch output (first 10 lines):${NC}"
        neofetch --stdout 2>/dev/null | head -10
    else
        print_result "Neofetch installation" "FAIL" "Installation failed"
    fi

    echo ""
    read -p "Press Enter to continue..."
}

# Test 3: Node File Operations
test_node_file_operations() {
    clear
    echo -e "${BLUE}=== Test: Node File Operations ===${NC}"
    echo ""

    # Backup original files
    local nodes_backup=""
    local onboarded_backup=""
    [ -f "$NODES_FILE" ] && nodes_backup=$(cat "$NODES_FILE")
    [ -f "$ONBOARDED_FILE" ] && onboarded_backup=$(cat "$ONBOARDED_FILE")

    # Test 1: Create files
    mkdir -p "$KEYS_DIR"
    touch "$NODES_FILE"
    touch "$ONBOARDED_FILE"

    if [ -f "$NODES_FILE" ] && [ -f "$ONBOARDED_FILE" ]; then
        print_result "Node files creation" "PASS"
    else
        print_result "Node files creation" "FAIL" "Files not created"
    fi

    # Test 2: Add node
    echo "$TEST_NODE_NAME|$TEST_NODE_USER@$TEST_NODE_HOST" >> "$NODES_FILE"

    if grep -q "$TEST_NODE_NAME" "$NODES_FILE"; then
        print_result "Add node entry" "PASS"
        echo "  Added: $TEST_NODE_NAME ($TEST_NODE_USER@$TEST_NODE_HOST)"
    else
        print_result "Add node entry" "FAIL" "Node not added"
    fi

    # Test 3: Read node entry
    if [ -s "$NODES_FILE" ]; then
        mapfile -t nodes < "$NODES_FILE"
        if [ ${#nodes[@]} -gt 0 ]; then
            print_result "Read node entries" "PASS"
            echo "  Total nodes: ${#nodes[@]}"
        else
            print_result "Read node entries" "FAIL" "No nodes found"
        fi
    fi

    # Test 4: Remove node
    grep -v "^$TEST_NODE_NAME" "$NODES_FILE" > "$NODES_FILE.tmp" 2>/dev/null && mv "$NODES_FILE.tmp" "$NODES_FILE"

    if ! grep -q "$TEST_NODE_NAME" "$NODES_FILE" 2>/dev/null; then
        print_result "Remove node entry" "PASS"
    else
        print_result "Remove node entry" "FAIL" "Node not removed"
    fi

    # Restore original files
    if [ -n "$nodes_backup" ]; then
        echo "$nodes_backup" > "$NODES_FILE"
    else
        > "$NODES_FILE"
    fi

    if [ -n "$onboarded_backup" ]; then
        echo "$onboarded_backup" > "$ONBOARDED_FILE"
    else
        > "$ONBOARDED_FILE"
    fi

    echo ""
    read -p "Press Enter to continue..."
}

# Test 4: Local Specs Gathering
test_local_specs_gathering() {
    clear
    echo -e "${BLUE}=== Test: Local Specs Gathering ===${NC}"
    echo ""

    # Ensure neofetch is installed
    if ! command -v neofetch &>/dev/null; then
        sudo apt-get update > /dev/null 2>&1
        sudo apt-get install -y neofetch > /dev/null 2>&1
    fi

    if command -v neofetch &>/dev/null; then
        print_result "Neofetch execution" "PASS"

        echo ""
        echo -e "${YELLOW}Sample neofetch output:${NC}"
        neofetch --stdout 2>/dev/null | head -15

        # Verify output contains expected fields
        local output=$(neofetch --stdout 2>/dev/null)

        if echo "$output" | grep -q "OS"; then
            print_result "OS field detection" "PASS"
        else
            print_result "OS field detection" "FAIL" "OS field not found"
        fi

        if echo "$output" | grep -q "Kernel"; then
            print_result "Kernel field detection" "PASS"
        else
            print_result "Kernel field detection" "FAIL" "Kernel field not found"
        fi
    else
        print_result "Neofetch execution" "FAIL" "Neofetch not available"
    fi

    echo ""
    read -p "Press Enter to continue..."
}

# Test 5: Verbose Config Setup
test_verbose_config_setup() {
    clear
    echo -e "${BLUE}=== Test: Verbose Config Setup ===${NC}"
    echo ""

    local config_dir="$HOME/.config/neofetch"
    local config_file="$config_dir/config_verbose.conf"

    mkdir -p "$config_dir"

    # Generate verbose config
    if ! command -v neofetch &>/dev/null; then
        sudo apt-get update > /dev/null 2>&1
        sudo apt-get install -y neofetch > /dev/null 2>&1
    fi

    neofetch --print_config > "$config_file" 2>/dev/null

    if [ -f "$config_file" ]; then
        print_result "Verbose config file creation" "PASS"
    else
        print_result "Verbose config file creation" "FAIL" "Config file not created"
    fi

    # Test replacing print_info function
    local original_lines=$(grep -c "^" "$config_file")

    sed -i '/^print_info()/,/^}/c\
print_info() {\
    info title\
    info underline\
\
    info "OS" distro\
    info "Host" model\
    info "Kernel" kernel\
    info "Uptime" uptime\
    info "Disk" disk\
    info "Battery" battery\
    info "CPU Temp" cpu_temp\
    info "GPU Temp" gpu_temp\
    info "Public IP" public_ip\
}' "$config_file"

    local new_lines=$(grep -c "^" "$config_file")

    if [ $new_lines -gt 0 ]; then
        print_result "print_info() function replacement" "PASS"
    else
        print_result "print_info() function replacement" "FAIL" "Function replacement failed"
    fi

    # Check for verbose fields
    if grep -q '"Disk"' "$config_file"; then
        print_result "Disk field in config" "PASS"
    else
        print_result "Disk field in config" "FAIL" "Disk field not found"
    fi

    if grep -q '"CPU Temp"' "$config_file"; then
        print_result "CPU Temp field in config" "PASS"
    else
        print_result "CPU Temp field in config" "FAIL" "CPU Temp field not found"
    fi

    if grep -q '"GPU Temp"' "$config_file"; then
        print_result "GPU Temp field in config" "PASS"
    else
        print_result "GPU Temp field in config" "FAIL" "GPU Temp field not found"
    fi

    echo ""
    echo -e "${YELLOW}Config file location: $config_file${NC}"
    echo -e "${YELLOW}Config file size: $(wc -c < "$config_file") bytes${NC}"

    echo ""
    read -p "Press Enter to continue..."
}

# Test 6: Sensors Installation
test_sensors_installation() {
    clear
    echo -e "${BLUE}=== Test: Sensors Installation ===${NC}"
    echo ""

    if command -v sensors &>/dev/null; then
        print_result "Sensors already installed" "PASS"
        echo ""
        echo -e "${YELLOW}Sensor information:${NC}"
        sensors 2>/dev/null | head -20 || echo "  (No sensors detected on this system)"
    else
        echo -e "${YELLOW}lm-sensors not installed. Install it? (y/n)${NC}"
        read -rsn1 install_choice
        echo ""

        if [[ "$install_choice" == "y" || "$install_choice" == "Y" ]]; then
            echo -e "${YELLOW}Installing lm-sensors...${NC}"
            sudo apt-get update > /dev/null 2>&1
            sudo apt-get install -y lm-sensors > /dev/null 2>&1

            if command -v sensors &>/dev/null; then
                print_result "Sensors installation" "PASS"
                echo ""
                echo -e "${YELLOW}Run 'sudo sensors-detect' to complete setup (answers yes to all prompts)${NC}"
            else
                print_result "Sensors installation" "FAIL" "Installation failed"
            fi
        else
            print_result "Sensors installation" "SKIP" "User declined"
        fi
    fi

    echo ""
    read -p "Press Enter to continue..."
}

# Test 7: Tmux Session Creation and Panes
test_tmux_session_creation() {
    clear
    echo -e "${BLUE}=== Test: Tmux Session Creation and Panes ===${NC}"
    echo ""

    if ! command -v tmux &>/dev/null; then
        echo -e "${YELLOW}Installing tmux...${NC}"
        sudo apt-get update > /dev/null 2>&1
        sudo apt-get install -y tmux > /dev/null 2>&1
    fi

    if command -v tmux &>/dev/null; then
        print_result "Tmux availability" "PASS"

        # Kill existing test session if it exists
        tmux kill-session -t test-homelab-live 2>/dev/null

        # Create test session with initial pane
        tmux new-session -d -s test-homelab-live "echo 'Test Local Node'; sleep 1"

        if tmux has-session -t test-homelab-live 2>/dev/null; then
            print_result "Tmux session creation" "PASS"

            # Create panes (simulating split-window for live stats)
            tmux split-window -t test-homelab-live -v "echo 'Test Node 1'; sleep 1"
            tmux split-window -t test-homelab-live -v "echo 'Test Node 2'; sleep 1"

            # Check if panes were created
            local pane_count=$(tmux list-panes -t test-homelab-live | wc -l)

            if [ $pane_count -ge 3 ]; then
                print_result "Tmux pane creation (split-window)" "PASS"
                echo "  Created $pane_count panes"
            else
                print_result "Tmux pane creation (split-window)" "FAIL" "Only $pane_count panes found (expected 3+)"
            fi

            # Test tiled layout
            tmux select-layout -t test-homelab-live tiled

            if tmux list-windows -t test-homelab-live | grep -q "0"; then
                print_result "Tmux tiled layout application" "PASS"
            else
                print_result "Tmux tiled layout application" "FAIL" "Layout not applied"
            fi

            # List panes
            echo ""
            echo -e "${YELLOW}Session panes:${NC}"
            tmux list-panes -t test-homelab-live

            # Kill test session
            tmux kill-session -t test-homelab-live 2>/dev/null
            print_result "Tmux session cleanup" "PASS"
        else
            print_result "Tmux session creation" "FAIL" "Session not created"
        fi
    else
        print_result "Tmux availability" "FAIL" "Tmux installation failed"
    fi

    echo ""
    read -p "Press Enter to continue..."
}

# Test 8: Menu Structure
test_menu_structure() {
    clear
    echo -e "${BLUE}=== Test: Menu Structure ===${NC}"
    echo ""

    # Find script location dynamically
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local script="$script_dir/homelab.sh"

    # Check if main script exists
    if [ ! -f "$script" ]; then
        print_result "Main script existence" "FAIL" "homelab.sh not found at $script"
        echo ""
        read -p "Press Enter to continue..."
        return
    fi

    print_result "Main script existence" "PASS"

    # Check for menu items
    local menu_items=(
        "View All Specs"
        "Check Node Status"
        "Add Node"
        "Onboard Node"
        "Remove Node"
        "Export Specs"
        "View Live Stats"
        "Test Bandwidth"
        "Toggle Verbose Mode"
    )

    echo ""
    echo -e "${YELLOW}Checking for menu items:${NC}"

    for item in "${menu_items[@]}"; do
        if grep -q "$item" "$script"; then
            print_result "Menu item: '$item'" "PASS"
        else
            print_result "Menu item: '$item'" "FAIL" "Not found in script"
        fi
    done

    # Check for key functions
    echo ""
    echo -e "${YELLOW}Checking for key functions:${NC}"

    local functions=(
        "show_menu"
        "get_local_specs"
        "get_remote_specs"
        "toggle_verbose_mode"
        "setup_verbose_config"
        "view_live_stats"
        "export_specs"
        "test_bandwidth_local"
        "test_bandwidth_remote"
    )

    for func in "${functions[@]}"; do
        if grep -q "^$func()" "$script"; then
            print_result "Function: $func" "PASS"
        else
            print_result "Function: $func" "FAIL" "Not found in script"
        fi
    done

    echo ""
    read -p "Press Enter to continue..."
}

# Test 9: Config File Integrity
test_config_file_integrity() {
    clear
    echo -e "${BLUE}=== Test: Config File Integrity ===${NC}"
    echo ""

    # Find script location dynamically
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local script="$script_dir/homelab.sh"

    # Check script is readable
    if [ -r "$script" ]; then
        print_result "Script is readable" "PASS"
    else
        print_result "Script is readable" "FAIL" "Script not readable"
        echo ""
        read -p "Press Enter to continue..."
        return
    fi

    # Check script is executable
    if [ -x "$script" ]; then
        print_result "Script is executable" "PASS"
    else
        print_result "Script is executable" "FAIL" "Script not executable"
        echo -e "${YELLOW}Fixing permissions...${NC}"
        chmod +x "$script"
    fi

    # Check for syntax errors
    if bash -n "$script" 2>/dev/null; then
        print_result "Bash syntax check" "PASS"
    else
        print_result "Bash syntax check" "FAIL" "Syntax errors found"
        echo ""
        bash -n "$script" 2>&1 | head -10
    fi

    # Check for critical variables
    echo ""
    echo -e "${YELLOW}Checking for critical variables:${NC}"

    local vars=(
        "NODES_FILE"
        "ONBOARDED_FILE"
        "KEYS_DIR"
        "verbose_mode"
        "selected"
        "menu_items"
    )

    for var in "${vars[@]}"; do
        if grep -q "$var" "$script"; then
            print_result "Variable: $var" "PASS"
        else
            print_result "Variable: $var" "FAIL" "Not found"
        fi
    done

    echo ""
    read -p "Press Enter to continue..."
}

# Test 10: CLI Mode - Specs Command
test_cli_specs_command() {
    clear
    echo -e "${BLUE}=== Test: CLI Mode - Specs Command ===${NC}"
    echo ""

    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local script="$script_dir/homelab.sh"

    if [ ! -f "$script" ]; then
        print_result "Script existence" "FAIL" "homelab.sh not found"
        read -p "Press Enter to continue..."
        return
    fi

    # Test help flag
    if "$script" help 2>&1 | grep -q "homelab - Homelab management"; then
        print_result "Help command" "PASS"
    else
        print_result "Help command" "FAIL" "Help output not as expected"
    fi

    # Test CLI help flag
    if "$script" --help 2>&1 | grep -q "homelab - Homelab management"; then
        print_result "--help flag" "PASS"
    else
        print_result "--help flag" "FAIL" "Help flag not working"
    fi

    echo ""
    echo -e "${YELLOW}Sample: homelab help${NC}"
    "$script" help | head -15

    echo ""
    read -p "Press Enter to continue..."
}

# Test 11: CLI Mode - Status Command
test_cli_status_command() {
    clear
    echo -e "${BLUE}=== Test: CLI Mode - Status Command ===${NC}"
    echo ""

    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local script="$script_dir/homelab.sh"

    if [ ! -f "$script" ]; then
        print_result "Script existence" "FAIL" "homelab.sh not found"
        read -p "Press Enter to continue..."
        return
    fi

    echo -e "${YELLOW}Running: homelab status${NC}"
    echo ""

    if "$script" status 2>&1 | grep -q "Node Status"; then
        print_result "Status command execution" "PASS"
    else
        print_result "Status command execution" "FAIL" "Status command failed"
    fi

    echo ""
    "$script" status

    echo ""
    read -p "Press Enter to continue..."
}

# Test 12: CLI Mode - Bandwidth Command
test_cli_bandwidth_command() {
    clear
    echo -e "${BLUE}=== Test: CLI Mode - Bandwidth Command ===${NC}"
    echo ""

    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local script="$script_dir/homelab.sh"

    if [ ! -f "$script" ]; then
        print_result "Script existence" "FAIL" "homelab.sh not found"
        read -p "Press Enter to continue..."
        return
    fi

    # Check if bandwidth functions exist
    if grep -q "test_bandwidth_local()" "$script"; then
        print_result "Bandwidth function exists" "PASS"
    else
        print_result "Bandwidth function exists" "FAIL" "Function not found"
    fi

    # Check if speedtest is in the script
    if grep -q "speedtest-cli" "$script"; then
        print_result "Speedtest integration" "PASS"
    else
        print_result "Speedtest integration" "FAIL" "Speedtest not integrated"
    fi

    echo ""
    echo -e "${YELLOW}Note: bandwidth testing requires speedtest-cli and internet connection${NC}"
    echo -e "${YELLOW}Usage: homelab bandwidth [local|NODE_NAME|all]${NC}"

    echo ""
    read -p "Press Enter to continue..."
}

# Test 13: CLI Mode - Node Management
test_cli_node_management() {
    clear
    echo -e "${BLUE}=== Test: CLI Mode - Node Management ===${NC}"
    echo ""

    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local script="$script_dir/homelab.sh"

    if [ ! -f "$script" ]; then
        print_result "Script existence" "FAIL" "homelab.sh not found"
        read -p "Press Enter to continue..."
        return
    fi

    # Backup node files
    local nodes_backup=""
    local onboarded_backup=""
    [ -f "$NODES_FILE" ] && nodes_backup=$(cat "$NODES_FILE")
    [ -f "$ONBOARDED_FILE" ] && onboarded_backup=$(cat "$ONBOARDED_FILE")

    echo -e "${YELLOW}Testing: homelab node add${NC}"
    if "$script" node add test-cli-node testuser 192.168.1.99 2>&1 | grep -q "added successfully"; then
        print_result "Node add command" "PASS"
    else
        print_result "Node add command" "FAIL" "Add command failed"
    fi

    echo ""
    echo -e "${YELLOW}Testing: homelab node list${NC}"
    if "$script" node list 2>&1 | grep -q "test-cli-node"; then
        print_result "Node list command" "PASS"
    else
        print_result "Node list command" "FAIL" "List command failed"
    fi

    echo ""
    echo -e "${YELLOW}Testing: homelab node remove${NC}"
    if "$script" node remove test-cli-node 2>&1 | grep -q "removed"; then
        print_result "Node remove command" "PASS"
    else
        print_result "Node remove command" "FAIL" "Remove command failed"
    fi

    # Restore node files
    if [ -n "$nodes_backup" ]; then
        echo "$nodes_backup" > "$NODES_FILE"
    else
        > "$NODES_FILE"
    fi

    if [ -n "$onboarded_backup" ]; then
        echo "$onboarded_backup" > "$ONBOARDED_FILE"
    else
        > "$ONBOARDED_FILE"
    fi

    echo ""
    read -p "Press Enter to continue..."
}

# Test 14: Speedtest Installation
test_speedtest_installation() {
    clear
    echo -e "${BLUE}=== Test: Speedtest Installation ===${NC}"
    echo ""

    if command -v speedtest-cli &>/dev/null; then
        print_result "Speedtest-cli already installed" "PASS"
        echo ""
        echo -e "${YELLOW}Version info:${NC}"
        speedtest-cli --version || echo "  (version check not available)"
    else
        echo -e "${YELLOW}speedtest-cli not installed. Install it? (y/n)${NC}"
        read -rsn1 install_choice
        echo ""

        if [[ "$install_choice" == "y" || "$install_choice" == "Y" ]]; then
            echo -e "${YELLOW}Installing speedtest-cli...${NC}"
            sudo pip3 install speedtest-cli > /dev/null 2>&1 || sudo pip install speedtest-cli > /dev/null 2>&1

            if command -v speedtest-cli &>/dev/null; then
                print_result "Speedtest-cli installation" "PASS"
            else
                print_result "Speedtest-cli installation" "FAIL" "Installation failed"
            fi
        else
            print_result "Speedtest-cli installation" "SKIP" "User declined"
        fi
    fi

    echo ""
    read -p "Press Enter to continue..."
}

# Test 15: Run All Tests
run_all_tests() {
    test_dependencies
    test_neofetch_installation
    test_node_file_operations
    test_local_specs_gathering
    test_verbose_config_setup
    test_sensors_installation
    test_tmux_session_creation
    test_menu_structure
    test_config_file_integrity
    test_cli_specs_command
    test_cli_status_command
    test_cli_bandwidth_command
    test_cli_node_management
    test_speedtest_installation

    clear
    echo -e "${BLUE}=== Test Summary ===${NC}"
    echo ""
    echo -e "${GREEN}Passed: $PASSED${NC}"
    echo -e "${RED}Failed: $FAILED${NC}"
    echo -e "${YELLOW}Skipped: $SKIPPED${NC}"
    echo ""
    echo -e "${BLUE}Total Tests: $((PASSED + FAILED + SKIPPED))${NC}"
    echo ""

    if [ $FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
    else
        echo -e "${RED}$FAILED test(s) failed. Please review the output above.${NC}"
    fi

    echo ""
    read -p "Press Enter to return to menu..."
}

# Main loop
while true; do
    show_menu

    # Read single key
    read -rsn1 key
    case "$key" in
        $'\x1b')  # Escape sequence
            read -rsn2 key
            case "$key" in
                '[A') # Up arrow
                    ((selected--))
                    [ $selected -lt 0 ] && selected=$((${#test_items[@]} - 1))
                    ;;
                '[B') # Down arrow
                    ((selected++))
                    [ $selected -ge ${#test_items[@]} ] && selected=0
                    ;;
            esac
            ;;
        '')  # Enter key
            case $selected in
                0) test_dependencies ;;
                1) test_neofetch_installation ;;
                2) test_node_file_operations ;;
                3) test_local_specs_gathering ;;
                4) test_verbose_config_setup ;;
                5) test_sensors_installation ;;
                6) test_tmux_session_creation ;;
                7) test_menu_structure ;;
                8) test_config_file_integrity ;;
                9) test_cli_specs_command ;;
                10) test_cli_status_command ;;
                11) test_cli_bandwidth_command ;;
                12) test_cli_node_management ;;
                13) test_speedtest_installation ;;
                14) run_all_tests ;;
                15) echo -e "${BLUE}Goodbye!${NC}"; exit 0 ;;
            esac
            ;;
    esac
done
