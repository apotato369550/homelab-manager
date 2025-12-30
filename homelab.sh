#!/bin/bash

# Homelab Manager - Interactive & CLI Tool
# Unified bash script for gathering system specs and testing bandwidth across homelab nodes

NODES_FILE="$HOME/.homelab_nodes"
ONBOARDED_FILE="$HOME/.homelab_onboarded"
KEYS_DIR="$HOME/.homelab_keys"

# Initialize directories
mkdir -p "$KEYS_DIR"
touch "$NODES_FILE"
touch "$ONBOARDED_FILE"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Menu state
selected=0
verbose_mode=0
menu_items=("View All Specs" "Check Node Status" "Add Node" "Onboard Node" "Remove Node" "Export Specs" "View Live Stats" "Test Bandwidth" "Toggle Verbose Mode" "Run Tests" "Exit")

# ===== CLI MODE FUNCTIONS =====

show_help() {
    cat << 'EOF'
homelab - Homelab management and monitoring tool

USAGE:
  homelab [COMMAND] [OPTIONS]

COMMANDS:
  Interactive Mode (default):
    homelab                           Start interactive menu interface

  Specs Commands:
    homelab specs [local|remote|all]  Gather system specifications
                                      local  - Local system only
                                      remote - Remote nodes only
                                      all    - Local + all remote nodes (default)

  Status Commands:
    homelab status                    Check status of all nodes

  Node Management:
    homelab node add NAME USER HOST   Add a new node
    homelab node remove NAME          Remove a node
    homelab node onboard NAME         Onboard node (setup SSH keys)
    homelab node list                 List all configured nodes

  Bandwidth Testing:
    homelab bandwidth [local|NODE|all]
                                      Test bandwidth
                                      local    - Test local system only
                                      NODE     - Test specific remote node
                                      all      - Test all nodes (default)

  Other:
    homelab export [PATH]             Export specs to file
    homelab live-stats                View live htop stats across nodes
    homelab verbose [on|off]          Toggle verbose mode
    homelab test                      Run test suite
    homelab help                      Show this help message

EXAMPLES:
  homelab                             # Start interactive menu
  homelab specs all                   # Get specs for all nodes
  homelab bandwidth all               # Test bandwidth on all nodes
  homelab bandwidth node1             # Test bandwidth on specific node
  homelab status                      # Check node connectivity
  homelab node add server1 root 192.168.1.10

EOF
}

print_error() {
    echo -e "${RED}Error: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}$1${NC}"
}

print_info() {
    echo -e "${BLUE}$1${NC}"
}

# ===== BANDWIDTH TESTING FUNCTIONS =====

ensure_speedtest() {
    if ! command -v speedtest-cli &> /dev/null; then
        print_warning "Installing speedtest-cli..."
        sudo pip3 install speedtest-cli > /dev/null 2>&1 || sudo pip install speedtest-cli > /dev/null 2>&1

        if ! command -v speedtest-cli &> /dev/null; then
            print_error "Failed to install speedtest-cli. Please install manually: pip install speedtest-cli"
            return 1
        fi
    fi
    return 0
}

test_bandwidth_local() {
    print_info "Testing bandwidth on LOCAL NODE..."
    echo ""

    if ! ensure_speedtest; then
        return 1
    fi

    speedtest-cli --simple
}

test_bandwidth_remote() {
    local ssh_addr=$1
    local node_name=$2

    print_info "Testing bandwidth on $node_name ($ssh_addr)..."
    echo ""

    # Check if speedtest-cli is installed on remote
    ssh -o ConnectTimeout=10 -i "$KEYS_DIR/id_rsa" "$ssh_addr" "command -v speedtest-cli &>/dev/null" 2>/dev/null

    if [ $? -ne 0 ]; then
        print_warning "Installing speedtest-cli on $node_name..."
        ssh -o ConnectTimeout=10 -i "$KEYS_DIR/id_rsa" "$ssh_addr" "sudo pip3 install speedtest-cli > /dev/null 2>&1 || sudo pip install speedtest-cli > /dev/null 2>&1" 2>/dev/null
    fi

    # Run speedtest
    ssh -o ConnectTimeout=10 -i "$KEYS_DIR/id_rsa" "$ssh_addr" "speedtest-cli --simple" 2>/dev/null
}

view_bandwidth_interactive() {
    clear
    echo -e "${BLUE}=== Bandwidth Testing ===${NC}"
    echo ""

    echo "1. Test Local Node"
    echo "2. Test Specific Remote Node"
    echo "3. Test All Nodes"
    echo "4. Cancel"
    echo ""

    read -p "Select option: " bw_choice

    case $bw_choice in
        1)
            clear
            print_info "=== Testing Bandwidth - Local Node ==="
            echo ""
            test_bandwidth_local
            echo ""
            read -p "Press Enter to continue..."
            ;;
        2)
            if [ ! -s "$NODES_FILE" ]; then
                print_error "No remote nodes configured."
                read -p "Press Enter to continue..."
                return
            fi

            clear
            print_info "=== Testing Bandwidth - Select Node ==="
            echo ""

            mapfile -t nodes < "$NODES_FILE"
            for i in "${!nodes[@]}"; do
                echo "$((i+1)). ${nodes[$i]%|*}"
            done

            read -p "Select node number: " node_num
            node_num=$((node_num - 1))

            if [ $node_num -ge 0 ] && [ $node_num -lt ${#nodes[@]} ]; then
                node_info="${nodes[$node_num]}"
                node_name="${node_info%|*}"
                ssh_addr="${node_info#*|}"

                clear
                test_bandwidth_remote "$ssh_addr" "$node_name"
                echo ""
                read -p "Press Enter to continue..."
            fi
            ;;
        3)
            clear
            print_info "=== Testing Bandwidth - All Nodes ==="
            echo ""

            test_bandwidth_local
            echo ""
            echo "---"
            echo ""

            if [ -s "$NODES_FILE" ]; then
                mapfile -t nodes < "$NODES_FILE"
                for node_line in "${nodes[@]}"; do
                    node_name="${node_line%|*}"
                    ssh_addr="${node_line#*|}"

                    test_bandwidth_remote "$ssh_addr" "$node_name"
                    echo ""
                    echo "---"
                    echo ""
                done
            fi

            read -p "Press Enter to continue..."
            ;;
        4)
            return
            ;;
        *)
            print_error "Invalid option"
            read -p "Press Enter to continue..."
            ;;
    esac
}

# ===== ORIGINAL FUNCTIONS (adapted from interactive script) =====

show_menu() {
    clear
    echo -e "${BLUE}=== Homelab Manager ===${NC}"
    if [ $verbose_mode -eq 1 ]; then
        echo -e "${GREEN}[Verbose Mode: ON]${NC}"
    else
        echo -e "${YELLOW}[Verbose Mode: OFF]${NC}"
    fi
    echo ""
    for i in "${!menu_items[@]}"; do
        if [ $i -eq $selected ]; then
            echo -e "${GREEN}> ${menu_items[$i]}${NC}"
        else
            echo "  ${menu_items[$i]}"
        fi
    done
}

setup_verbose_config() {
    local config_dir="$HOME/.config/neofetch"
    local config_file="$config_dir/config_verbose.conf"

    mkdir -p "$config_dir"

    # Generate base config
    neofetch --print_config > "$config_file" 2>/dev/null

    # Replace print_info function with verbose version using sed
    sed -i '/^print_info()/,/^}$/c\
print_info() {\
    info title\
    info underline\
\
    info "OS" distro\
    info "Host" model\
    info "Kernel" kernel\
    info "Uptime" uptime\
    info "Packages" packages\
    info "Shell" shell\
    info "Resolution" resolution\
    info "DE" de\
    info "WM" wm\
    info "WM Theme" wm_theme\
    info "Theme" theme\
    info "Icons" icons\
    info "Terminal" term\
    info "Terminal Font" term_font\
    info "CPU" cpu\
    info "GPU" gpu\
    info "Memory" memory\
    info "Disk" disk\
    info "Battery" battery\
    info "Locale" locale\
    info "CPU Usage" cpu_usage\
    info "CPU Temp" cpu_temp\
    info "GPU Temp" gpu_temp\
    info "Public IP" public_ip\
    info "Local IP" local_ip\
    info "Users" users\
    info "Processes" processes\
}' "$config_file"
}

setup_verbose_config_remote() {
    local ssh_addr=$1

    # Create config directory on remote
    ssh -o ConnectTimeout=10 -i "$KEYS_DIR/id_rsa" "$ssh_addr" "mkdir -p ~/.config/neofetch" 2>/dev/null

    # Generate base config on remote
    ssh -o ConnectTimeout=10 -i "$KEYS_DIR/id_rsa" "$ssh_addr" "neofetch --print_config > ~/.config/neofetch/config_verbose.conf 2>/dev/null" 2>/dev/null

    # Send the verbose print_info function and replace it on remote
    ssh -o ConnectTimeout=10 -i "$KEYS_DIR/id_rsa" "$ssh_addr" bash << 'REMOTE_EOF'
config_file="$HOME/.config/neofetch/config_verbose.conf"
if [ -f "$config_file" ]; then
    # Use sed to replace the print_info function
    sed -i '/^print_info()/,/^}$/c\
print_info() {\
    info title\
    info underline\
\
    info "OS" distro\
    info "Host" model\
    info "Kernel" kernel\
    info "Uptime" uptime\
    info "Packages" packages\
    info "Shell" shell\
    info "Resolution" resolution\
    info "DE" de\
    info "WM" wm\
    info "WM Theme" wm_theme\
    info "Theme" theme\
    info "Icons" icons\
    info "Terminal" term\
    info "Terminal Font" term_font\
    info "CPU" cpu\
    info "GPU" gpu\
    info "Memory" memory\
    info "Disk" disk\
    info "Battery" battery\
    info "Locale" locale\
    info "CPU Usage" cpu_usage\
    info "CPU Temp" cpu_temp\
    info "GPU Temp" gpu_temp\
    info "Public IP" public_ip\
    info "Local IP" local_ip\
    info "Users" users\
    info "Processes" processes\
}' "$config_file"
fi
REMOTE_EOF
}

install_sensors() {
    if ! command -v sensors &> /dev/null; then
        echo -e "${YELLOW}Installing lm-sensors...${NC}"
        sudo apt-get update && sudo apt-get install -y lm-sensors > /dev/null 2>&1

        echo -e "${YELLOW}Running sensors-detect (auto-answering yes)...${NC}"
        echo "yes" | sudo sensors-detect > /dev/null 2>&1

        echo -e "${GREEN}lm-sensors installed and configured!${NC}"
    fi
}

toggle_verbose_mode() {
    clear
    echo -e "${BLUE}=== Toggle Verbose Mode ===${NC}"
    echo ""

    if [ $verbose_mode -eq 0 ]; then
        echo -e "${YELLOW}Enabling verbose mode...${NC}"
        echo -e "${YELLOW}This will install additional tools for detailed system metrics.${NC}"
        echo ""

        install_sensors
        setup_verbose_config

        verbose_mode=1
        echo -e "${GREEN}Verbose mode ENABLED${NC}"
    else
        verbose_mode=0
        echo -e "${GREEN}Verbose mode DISABLED${NC}"
    fi

    echo ""
    read -p "Press Enter to continue..."
}

get_local_specs() {
    echo -e "${YELLOW}Gathering specs from localhost...${NC}"
    if ! command -v neofetch &> /dev/null; then
        echo -e "${YELLOW}Installing neofetch...${NC}"
        sudo apt-get update && sudo apt-get install -y neofetch > /dev/null 2>&1
    fi

    if [ $verbose_mode -eq 1 ]; then
        neofetch --config "$HOME/.config/neofetch/config_verbose.conf" --stdout 2>/dev/null || echo "Error running neofetch with verbose config"
    else
        neofetch --stdout 2>/dev/null || echo "Error running neofetch"
    fi
}

check_node_status() {
    clear
    echo -e "${BLUE}=== Node Status ===${NC}"
    echo ""

    # Local node
    echo -e "${GREEN}✓ LOCAL NODE${NC} (online)"
    echo ""

    # Remote nodes
    if [ -s "$NODES_FILE" ]; then
        mapfile -t nodes < "$NODES_FILE"
        for node_line in "${nodes[@]}"; do
            node_name="${node_line%|*}"
            ssh_addr="${node_line#*|}"
            host_only="${ssh_addr#*@}"

            if ping -c 1 -W 2 "$host_only" &> /dev/null; then
                echo -e "${GREEN}✓ $node_name${NC} (online)"
            else
                echo -e "${RED}✗ $node_name${NC} (offline)"
            fi
        done
    else
        echo -e "${YELLOW}No remote nodes configured.${NC}"
    fi

    echo ""
    read -p "Press Enter to continue..."
}

add_node() {
    clear
    echo -e "${BLUE}=== Add Node ===${NC}"
    read -p "Enter node name: " node_name
    read -p "Enter SSH user: " ssh_user
    read -p "Enter SSH host/IP: " ssh_host

    # Sanitize inputs - remove pipe characters and leading/trailing whitespace
    node_name=$(echo "$node_name" | tr -d '|' | xargs)
    ssh_user=$(echo "$ssh_user" | tr -d '|@' | xargs)
    ssh_host=$(echo "$ssh_host" | tr -d '|' | xargs)

    # Basic validation
    if [ -z "$node_name" ] || [ -z "$ssh_user" ] || [ -z "$ssh_host" ]; then
        echo -e "${RED}Error: All fields are required!${NC}"
        read -p "Press Enter to continue..."
        return
    fi

    # Check if node already exists
    if grep -q "^$node_name|" "$NODES_FILE" 2>/dev/null; then
        echo -e "${RED}Error: Node '$node_name' already exists!${NC}"
        read -p "Press Enter to continue..."
        return
    fi

    # Test connectivity before adding
    echo -e "${YELLOW}Testing connection to $ssh_host...${NC}"
    if ping -c 1 -W 2 "$ssh_host" &> /dev/null; then
        echo -e "${GREEN}Connection test successful!${NC}"
        echo "$node_name|$ssh_user@$ssh_host" >> "$NODES_FILE"
        echo -e "${GREEN}Node '$node_name' added!${NC}"
    else
        echo -e "${YELLOW}Warning: Could not reach $ssh_host${NC}"
        read -p "Add anyway? (y/n): " add_anyway
        if [[ "$add_anyway" == "y" || "$add_anyway" == "Y" ]]; then
            echo "$node_name|$ssh_user@$ssh_host" >> "$NODES_FILE"
            echo -e "${GREEN}Node '$node_name' added!${NC}"
        else
            echo -e "${YELLOW}Node not added.${NC}"
        fi
    fi

    read -p "Press Enter to continue..."
}

onboard_node() {
    clear
    echo -e "${BLUE}=== Onboard Node ===${NC}"

    if [ ! -s "$NODES_FILE" ]; then
        echo -e "${RED}No nodes configured yet.${NC}"
        read -p "Press Enter to continue..."
        return
    fi

    # Filter out already onboarded nodes
    mapfile -t nodes < "$NODES_FILE"
    mapfile -t onboarded < "$ONBOARDED_FILE" 2>/dev/null || true

    available_nodes=()
    node_indices=()

    for i in "${!nodes[@]}"; do
        node_name="${nodes[$i]%|*}"
        if ! printf '%s\n' "${onboarded[@]}" | grep -q "^$node_name$"; then
            available_nodes+=("${nodes[$i]}")
            node_indices+=("$i")
        fi
    done

    if [ ${#available_nodes[@]} -eq 0 ]; then
        echo -e "${YELLOW}All nodes have been onboarded!${NC}"
        read -p "Press Enter to continue..."
        return
    fi

    # Show available nodes
    for i in "${!available_nodes[@]}"; do
        echo "$((i+1)). ${available_nodes[$i]%|*}"
    done

    read -p "Select node number: " node_num
    node_num=$((node_num - 1))

    if [ $node_num -ge 0 ] && [ $node_num -lt ${#available_nodes[@]} ]; then
        node_info="${available_nodes[$node_num]}"
        node_name="${node_info%|*}"
        ssh_addr="${node_info#*|}"

        echo -e "${YELLOW}Adding SSH key for $node_name...${NC}"
        ssh-copy-id -i "$KEYS_DIR/id_rsa.pub" "$ssh_addr" 2>/dev/null || {
            echo -e "${YELLOW}Generating SSH key first...${NC}"
            ssh-keygen -t rsa -N "" -f "$KEYS_DIR/id_rsa" -C "homelab-manager"
            ssh-copy-id -i "$KEYS_DIR/id_rsa.pub" "$ssh_addr"
        }
        echo -e "${GREEN}SSH key added to $node_name!${NC}"
        echo "$node_name" >> "$ONBOARDED_FILE"
    fi

    read -p "Press Enter to continue..."
}

get_remote_specs() {
    local ssh_addr=$1
    local node_name=$2

    # Install neofetch if needed
    ssh -o ConnectTimeout=10 -i "$KEYS_DIR/id_rsa" "$ssh_addr" "command -v neofetch &>/dev/null || (sudo apt-get update && sudo apt-get install -y neofetch)" > /dev/null 2>&1

    # Setup verbose config on remote if verbose mode is enabled
    if [ $verbose_mode -eq 1 ]; then
        # Setup verbose config using dedicated function
        setup_verbose_config_remote "$ssh_addr"

        # Also install sensors on remote if needed
        ssh -o ConnectTimeout=10 -i "$KEYS_DIR/id_rsa" "$ssh_addr" "command -v sensors &>/dev/null || (sudo apt-get update && sudo apt-get install -y lm-sensors > /dev/null 2>&1 && echo 'yes' | sudo sensors-detect > /dev/null 2>&1)" > /dev/null 2>&1

        # Run neofetch with verbose config
        ssh -o ConnectTimeout=10 -i "$KEYS_DIR/id_rsa" "$ssh_addr" "neofetch --config ~/.config/neofetch/config_verbose.conf --stdout" 2>/dev/null
    else
        # Run neofetch standard
        ssh -o ConnectTimeout=10 -i "$KEYS_DIR/id_rsa" "$ssh_addr" "neofetch --stdout" 2>/dev/null
    fi
}

view_all_specs() {
    clear
    echo -e "${BLUE}=== Homelab Specs ===${NC}"
    echo ""

    # Local specs
    echo -e "${YELLOW}>>> LOCAL NODE <<<${NC}"
    get_local_specs
    echo ""

    # Remote nodes
    if [ -s "$NODES_FILE" ]; then
        mapfile -t nodes < "$NODES_FILE"
        for node_line in "${nodes[@]}"; do
            node_name="${node_line%|*}"
            ssh_addr="${node_line#*|}"

            echo -e "${YELLOW}>>> $node_name ($ssh_addr) <<<${NC}"
            get_remote_specs "$ssh_addr" "$node_name"
            echo ""
        done
    fi

    read -p "Press Enter to continue..."
}

remove_node() {
    clear
    echo -e "${BLUE}=== Remove Node ===${NC}"

    if [ ! -s "$NODES_FILE" ]; then
        echo -e "${RED}No nodes configured yet.${NC}"
        read -p "Press Enter to continue..."
        return
    fi

    mapfile -t nodes < "$NODES_FILE"
    for i in "${!nodes[@]}"; do
        echo "$((i+1)). ${nodes[$i]%|*}"
    done

    read -p "Select node number to remove: " node_num
    node_num=$((node_num - 1))

    if [ $node_num -ge 0 ] && [ $node_num -lt ${#nodes[@]} ]; then
        node_name="${nodes[$node_num]%|*}"
        unset 'nodes[$node_num]'
        # Atomic write: write to temp file first, then move
        printf '%s\n' "${nodes[@]}" > "$NODES_FILE.tmp" && mv "$NODES_FILE.tmp" "$NODES_FILE"

        # Also remove from onboarded list (atomic write)
        grep -v "^$node_name$" "$ONBOARDED_FILE" > "$ONBOARDED_FILE.tmp" 2>/dev/null && mv "$ONBOARDED_FILE.tmp" "$ONBOARDED_FILE"

        echo -e "${GREEN}Node removed!${NC}"
    fi

    read -p "Press Enter to continue..."
}

export_specs() {
    clear
    echo -e "${BLUE}=== Export Specs ===${NC}"
    echo ""

    # Use Desktop if it exists, otherwise use HOME
    if [ -d "$HOME/Desktop" ]; then
        export_dir="$HOME/Desktop"
    else
        export_dir="$HOME"
    fi

    echo "Default export location: $export_dir"
    read -p "Use custom location? (y/n): " custom_choice

    if [[ "$custom_choice" == "y" || "$custom_choice" == "Y" ]]; then
        read -p "Enter export path: " custom_path
        custom_path="${custom_path/#\~/$HOME}"  # Expand ~ to home

        if [ ! -d "$custom_path" ]; then
            echo -e "${RED}Error: Directory does not exist.${NC}"
            read -p "Press Enter to continue..."
            return
        fi

        if [ ! -w "$custom_path" ]; then
            echo -e "${RED}Error: No write permission for this directory.${NC}"
            read -p "Press Enter to continue..."
            return
        fi

        export_dir="$custom_path"
    fi

    timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
    filename="homelab_specs_$timestamp.txt"
    filepath="$export_dir/$filename"

    {
        echo "================================"
        echo "Homelab Specs Report"
        echo "Generated: $(date)"
        echo "================================"
        echo ""

        # Local specs
        echo ">>> LOCAL NODE <<<"
        get_local_specs
        echo ""

        # Remote nodes
        if [ -s "$NODES_FILE" ]; then
            mapfile -t nodes < "$NODES_FILE"
            for node_line in "${nodes[@]}"; do
                node_name="${node_line%|*}"
                ssh_addr="${node_line#*|}"

                echo ">>> $node_name ($ssh_addr) <<<"
                get_remote_specs "$ssh_addr" "$node_name"
                echo ""
            done
        fi
    } > "$filepath" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Specs exported to: $filepath${NC}"
    else
        echo -e "${RED}Error: Failed to export specs. Check directory permissions.${NC}"
    fi

    read -p "Press Enter to continue..."
}

view_live_stats() {
    # Install tmux if needed
    if ! command -v tmux &> /dev/null; then
        echo -e "${YELLOW}Installing tmux...${NC}"
        sudo apt-get update && sudo apt-get install -y tmux > /dev/null 2>&1
    fi

    # Check if session already exists
    if tmux has-session -t homelab-live-stats 2>/dev/null; then
        # Session exists, just attach
        tmux attach-session -t homelab-live-stats
        return
    fi

    # Create new session with local node running htop
    tmux new-session -d -s homelab-live-stats "htop"

    # Add panes for each remote node
    if [ -s "$NODES_FILE" ]; then
        mapfile -t nodes < "$NODES_FILE"
        for node_line in "${nodes[@]}"; do
            node_name="${node_line%|*}"
            ssh_addr="${node_line#*|}"

            # Split window vertically and run SSH with proper TTY allocation (-t flag)
            # The -t flag forces pseudo-terminal allocation for interactive commands like htop
            tmux split-window -t homelab-live-stats -v "ssh -o ConnectTimeout=10 -t -i \"$KEYS_DIR/id_rsa\" \"$ssh_addr\" 'htop'"
        done

        # Arrange panes in a tiled layout for optimal viewing
        tmux select-layout -t homelab-live-stats tiled
    fi

    # Attach to the session
    tmux attach-session -t homelab-live-stats
}

run_tests() {
    clear
    echo -e "${BLUE}=== Run Test Suite ===${NC}"
    echo ""

    local test_script="./test-homelab.sh"

    # Check if test script exists in current directory
    if [ ! -f "$test_script" ]; then
        # Try the same directory as this script
        local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        test_script="$script_dir/test-homelab.sh"
    fi

    if [ ! -f "$test_script" ]; then
        echo -e "${RED}Error: test-homelab.sh not found${NC}"
        echo -e "${YELLOW}Expected location: $test_script${NC}"
        echo ""
        read -p "Press Enter to continue..."
        return
    fi

    if [ ! -x "$test_script" ]; then
        echo -e "${YELLOW}Making test script executable...${NC}"
        chmod +x "$test_script"
    fi

    echo -e "${GREEN}Launching test suite...${NC}"
    echo ""
    sleep 1

    # Execute test script
    "$test_script"
}

# ===== CLI MODE HANDLER =====

run_cli_mode() {
    local command=$1
    shift

    case "$command" in
        specs)
            local scope="${1:-all}"
            clear
            print_info "=== Homelab Specs Report ==="
            echo ""

            case "$scope" in
                local)
                    print_info ">>> LOCAL NODE <<<"
                    get_local_specs
                    ;;
                remote)
                    if [ ! -s "$NODES_FILE" ]; then
                        print_error "No remote nodes configured."
                        exit 1
                    fi

                    mapfile -t nodes < "$NODES_FILE"
                    for node_line in "${nodes[@]}"; do
                        node_name="${node_line%|*}"
                        ssh_addr="${node_line#*|}"

                        print_info ">>> $node_name ($ssh_addr) <<<"
                        get_remote_specs "$ssh_addr" "$node_name"
                        echo ""
                    done
                    ;;
                all|*)
                    print_info ">>> LOCAL NODE <<<"
                    get_local_specs
                    echo ""

                    if [ -s "$NODES_FILE" ]; then
                        mapfile -t nodes < "$NODES_FILE"
                        for node_line in "${nodes[@]}"; do
                            node_name="${node_line%|*}"
                            ssh_addr="${node_line#*|}"

                            print_info ">>> $node_name ($ssh_addr) <<<"
                            get_remote_specs "$ssh_addr" "$node_name"
                            echo ""
                        done
                    fi
                    ;;
            esac
            ;;

        status)
            print_info "=== Node Status ==="
            echo ""
            echo -e "${GREEN}✓ LOCAL NODE${NC} (online)"
            echo ""

            if [ -s "$NODES_FILE" ]; then
                mapfile -t nodes < "$NODES_FILE"
                for node_line in "${nodes[@]}"; do
                    node_name="${node_line%|*}"
                    ssh_addr="${node_line#*|}"
                    host_only="${ssh_addr#*@}"

                    if ping -c 1 -W 2 "$host_only" &> /dev/null; then
                        echo -e "${GREEN}✓ $node_name${NC} (online)"
                    else
                        echo -e "${RED}✗ $node_name${NC} (offline)"
                    fi
                done
            else
                print_warning "No remote nodes configured."
            fi
            ;;

        bandwidth)
            local target="${1:-all}"

            case "$target" in
                local)
                    print_info "=== Bandwidth Test - Local Node ==="
                    echo ""
                    test_bandwidth_local
                    ;;
                all)
                    print_info "=== Bandwidth Test - All Nodes ==="
                    echo ""
                    test_bandwidth_local
                    echo ""

                    if [ -s "$NODES_FILE" ]; then
                        mapfile -t nodes < "$NODES_FILE"
                        for node_line in "${nodes[@]}"; do
                            node_name="${node_line%|*}"
                            ssh_addr="${node_line#*|}"

                            echo "---"
                            echo ""
                            test_bandwidth_remote "$ssh_addr" "$node_name"
                            echo ""
                        done
                    fi
                    ;;
                *)
                    # Assume it's a node name
                    if [ ! -s "$NODES_FILE" ]; then
                        print_error "No remote nodes configured."
                        exit 1
                    fi

                    mapfile -t nodes < "$NODES_FILE"
                    found=0
                    for node_line in "${nodes[@]}"; do
                        node_name="${node_line%|*}"
                        ssh_addr="${node_line#*|}"

                        if [ "$node_name" = "$target" ]; then
                            test_bandwidth_remote "$ssh_addr" "$node_name"
                            found=1
                            break
                        fi
                    done

                    if [ $found -eq 0 ]; then
                        print_error "Node '$target' not found."
                        exit 1
                    fi
                    ;;
            esac
            ;;

        node)
            local action=$1
            shift

            case "$action" in
                add)
                    local name=$1 user=$2 host=$3

                    if [ -z "$name" ] || [ -z "$user" ] || [ -z "$host" ]; then
                        print_error "Usage: homelab node add NAME USER HOST"
                        exit 1
                    fi

                    if grep -q "^$name|" "$NODES_FILE" 2>/dev/null; then
                        print_error "Node '$name' already exists."
                        exit 1
                    fi

                    echo "$name|$user@$host" >> "$NODES_FILE"
                    print_success "Node '$name' added successfully."
                    ;;

                remove)
                    local name=$1

                    if [ -z "$name" ]; then
                        print_error "Usage: homelab node remove NAME"
                        exit 1
                    fi

                    if ! grep -q "^$name|" "$NODES_FILE" 2>/dev/null; then
                        print_error "Node '$name' not found."
                        exit 1
                    fi

                    grep -v "^$name|" "$NODES_FILE" > "$NODES_FILE.tmp" && mv "$NODES_FILE.tmp" "$NODES_FILE"
                    grep -v "^$name$" "$ONBOARDED_FILE" > "$ONBOARDED_FILE.tmp" 2>/dev/null && mv "$ONBOARDED_FILE.tmp" "$ONBOARDED_FILE"
                    print_success "Node '$name' removed."
                    ;;

                list)
                    if [ ! -s "$NODES_FILE" ]; then
                        print_warning "No nodes configured."
                        exit 0
                    fi

                    print_info "Configured nodes:"
                    mapfile -t nodes < "$NODES_FILE"
                    for i in "${!nodes[@]}"; do
                        node_name="${nodes[$i]%|*}"
                        ssh_addr="${nodes[$i]#*|}"

                        if grep -q "^$node_name$" "$ONBOARDED_FILE" 2>/dev/null; then
                            echo "  [✓] $node_name ($ssh_addr)"
                        else
                            echo "  [ ] $node_name ($ssh_addr)"
                        fi
                    done
                    ;;

                onboard)
                    local name=$1

                    if [ -z "$name" ]; then
                        print_error "Usage: homelab node onboard NAME"
                        exit 1
                    fi

                    if ! grep -q "^$name|" "$NODES_FILE" 2>/dev/null; then
                        print_error "Node '$name' not found."
                        exit 1
                    fi

                    if grep -q "^$name$" "$ONBOARDED_FILE" 2>/dev/null; then
                        print_warning "Node '$name' is already onboarded."
                        exit 0
                    fi

                    # Get SSH address
                    ssh_addr=$(grep "^$name|" "$NODES_FILE" | cut -d'|' -f2)

                    print_info "Onboarding node '$name'..."
                    ssh-copy-id -i "$KEYS_DIR/id_rsa.pub" "$ssh_addr" 2>/dev/null || {
                        print_warning "Generating SSH key first..."
                        ssh-keygen -t rsa -N "" -f "$KEYS_DIR/id_rsa" -C "homelab-manager" 2>/dev/null
                        ssh-copy-id -i "$KEYS_DIR/id_rsa.pub" "$ssh_addr"
                    }
                    echo "$name" >> "$ONBOARDED_FILE"
                    print_success "Node '$name' onboarded successfully."
                    ;;

                *)
                    print_error "Unknown node action: $action"
                    print_info "Usage: homelab node [add|remove|list|onboard]"
                    exit 1
                    ;;
            esac
            ;;

        export)
            local path="${1:-.}"

            if [ ! -d "$path" ]; then
                print_error "Directory '$path' does not exist."
                exit 1
            fi

            if [ ! -w "$path" ]; then
                print_error "No write permission for directory '$path'."
                exit 1
            fi

            timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
            filename="homelab_specs_$timestamp.txt"
            filepath="$path/$filename"

            {
                echo "================================"
                echo "Homelab Specs Report"
                echo "Generated: $(date)"
                echo "================================"
                echo ""

                echo ">>> LOCAL NODE <<<"
                get_local_specs
                echo ""

                if [ -s "$NODES_FILE" ]; then
                    mapfile -t nodes < "$NODES_FILE"
                    for node_line in "${nodes[@]}"; do
                        node_name="${node_line%|*}"
                        ssh_addr="${node_line#*|}"

                        echo ">>> $node_name ($ssh_addr) <<<"
                        get_remote_specs "$ssh_addr" "$node_name"
                        echo ""
                    done
                fi
            } > "$filepath"

            print_success "Specs exported to: $filepath"
            ;;

        verbose)
            local action="${1:-toggle}"

            case "$action" in
                on)
                    verbose_mode=1
                    install_sensors
                    setup_verbose_config
                    print_success "Verbose mode enabled."
                    ;;
                off)
                    verbose_mode=0
                    print_success "Verbose mode disabled."
                    ;;
                toggle)
                    if [ $verbose_mode -eq 0 ]; then
                        verbose_mode=1
                        install_sensors
                        setup_verbose_config
                        print_success "Verbose mode enabled."
                    else
                        verbose_mode=0
                        print_success "Verbose mode disabled."
                    fi
                    ;;
                *)
                    print_error "Usage: homelab verbose [on|off|toggle]"
                    exit 1
                    ;;
            esac
            ;;

        live-stats)
            view_live_stats
            ;;

        test)
            run_tests
            ;;

        help|--help|-h)
            show_help
            ;;

        *)
            print_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# ===== MAIN ENTRY POINT =====

# Check if CLI arguments provided
if [ $# -gt 0 ]; then
    # Run in CLI mode
    run_cli_mode "$@"
else
    # Run in interactive mode
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
                        [ $selected -lt 0 ] && selected=$((${#menu_items[@]} - 1))
                        ;;
                    '[B') # Down arrow
                        ((selected++))
                        [ $selected -ge ${#menu_items[@]} ] && selected=0
                        ;;
                esac
                ;;
            '')  # Enter key
                case $selected in
                    0) view_all_specs ;;
                    1) check_node_status ;;
                    2) add_node ;;
                    3) onboard_node ;;
                    4) remove_node ;;
                    5) export_specs ;;
                    6) view_live_stats ;;
                    7) view_bandwidth_interactive ;;
                    8) toggle_verbose_mode ;;
                    9) run_tests ;;
                    10) echo -e "${BLUE}Goodbye!${NC}"; exit 0 ;;
                esac
                ;;
        esac
    done
fi
