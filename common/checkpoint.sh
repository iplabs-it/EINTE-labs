#!/bin/bash
#
# checkpoint.sh - Create integrity-verified lab checkpoints
# Version 2.2 - With automatic VM fingerprinting (no manual identity setup required)
#

SCRIPT_VERSION="2.2"
IDENTITY_FILE="$HOME/.lab_identity"
CHECKPOINTS_DIR="$HOME/lab_checkpoints"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
    echo "Usage: $0 [OPTIONS] [TASK_NAME]"
    echo ""
    echo "Creates an integrity-verified checkpoint of all FRR router configs."
    echo ""
    echo "Arguments:"
    echo "  TASK_NAME     Optional task identifier (e.g., 'task1', 'task3_complete')"
    echo "                If not provided, will prompt for it."
    echo ""
    echo "Options:"
    echo "  -d, --dir DIR     Look for .clab.yml in DIR (default: current directory)"
    echo "  -o, --output DIR  Save checkpoints to DIR (default: ~/lab_checkpoints)"
    echo "  --no-identity     Skip identity file (still captures VM fingerprint)"
    echo "  --no-fingerprint  Skip VM fingerprint collection"
    echo "  -h, --help        Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                        # Interactive mode"
    echo "  $0 task1                  # Quick checkpoint for task1"
    echo "  $0 -d ~/Labs/bgp task2"
    echo "  $0 --no-identity task1    # Without identity file, but with VM fingerprint"
    exit 1
}

# Collect VM fingerprint data
collect_vm_fingerprint() {
    local fingerprint_file="$1"
    
    echo "Collecting VM fingerprint..."
    
    {
        echo "# VM Fingerprint - collected at $(date -Iseconds)"
        echo "# This data helps identify the VM instance"
        echo ""
        
        # VirtualBox VM UUID (unique per VM, even for clones)
        echo "## VirtualBox VM UUID"
        sudo dmidecode -s system-uuid 2>/dev/null || echo "unavailable"
        echo ""
        
        # System serial number
        echo "## System Serial"
        sudo dmidecode -s system-serial-number 2>/dev/null || echo "unavailable"
        echo ""
        
        # Machine ID (Debian/Ubuntu specific, stable per installation)
        echo "## Machine ID"
        cat /etc/machine-id 2>/dev/null || echo "unavailable"
        echo ""
        
        # Boot ID (changes every boot - helps with timeline)
        echo "## Boot ID"
        cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo "unavailable"
        echo ""
        
        # Network interfaces and MAC addresses
        echo "## Network Interfaces"
        ip link show 2>/dev/null | grep -E "^[0-9]+:|link/ether" | paste - - 2>/dev/null || echo "unavailable"
        echo ""
        
        # Disk UUIDs (identifies virtual disks)
        echo "## Disk UUIDs"
        lsblk -o NAME,UUID,SIZE 2>/dev/null || blkid 2>/dev/null || echo "unavailable"
        echo ""
        
        # Root filesystem UUID
        echo "## Root FS UUID"
        findmnt -n -o UUID / 2>/dev/null || echo "unavailable"
        echo ""
        
        # CPU info (identifies host hardware)
        echo "## CPU Model"
        grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || echo "unavailable"
        echo ""
        
        # CPU cores
        echo "## CPU Cores"
        nproc 2>/dev/null || echo "unavailable"
        echo ""
        
        # Total RAM (identifies host somewhat)
        echo "## Total RAM (kB)"
        grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "unavailable"
        echo ""
        
        # VirtualBox Guest Additions version (if installed)
        echo "## VBox Guest Additions"
        modinfo vboxguest 2>/dev/null | grep ^version | awk '{print $2}' || echo "unavailable"
        echo ""
        
        # Hostname
        echo "## Hostname"
        hostname 2>/dev/null || echo "unavailable"
        echo ""
        
        # Timezone
        echo "## Timezone"
        timedatectl 2>/dev/null | grep "Time zone" | awk '{print $3}' || cat /etc/timezone 2>/dev/null || echo "unavailable"
        
    } > "$fingerprint_file"
    
    # Calculate fingerprint hash from stable components only
    # (excluding boot_id which changes every boot)
    local stable_components=""
    stable_components+=$(sudo dmidecode -s system-uuid 2>/dev/null)
    stable_components+=$(cat /etc/machine-id 2>/dev/null)
    stable_components+=$(ip link show 2>/dev/null | grep "link/ether" | awk '{print $2}' | sort | tr '\n' ':')
    stable_components+=$(findmnt -n -o UUID / 2>/dev/null)
    
    echo -n "$stable_components" | sha256sum | cut -d' ' -f1
}

# Parse arguments
LAB_DIR="."
SKIP_IDENTITY=false
SKIP_FINGERPRINT=false
TASK_NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dir)
            LAB_DIR="$2"
            shift 2
            ;;
        -o|--output)
            CHECKPOINTS_DIR="$2"
            shift 2
            ;;
        --no-identity)
            SKIP_IDENTITY=true
            shift
            ;;
        --no-fingerprint)
            SKIP_FINGERPRINT=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
        *)
            TASK_NAME="$1"
            shift
            ;;
    esac
done

# Handle identity
identity_hash="none"
group_id="unverified"
students="anonymous"
mode="fingerprint-only"
activation_id=""

if [[ "$SKIP_IDENTITY" != "true" && -f "$IDENTITY_FILE" ]]; then
    # Load identity file if it exists
    while IFS='=' read -r key value; do
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue
        key=$(echo "$key" | xargs)
        value="${value#\"}"
        value="${value%\"}"
        value="${value#\'}"
        value="${value%\'}"
        declare "$key=$value"
    done < "$IDENTITY_FILE"

    echo -e "${CYAN}Identity: ${group_id} (${students//;/, })${NC}"
    if [[ "$mode" == "online" ]]; then
        echo -e "${GREEN}✓ Verified identity${NC}"
    elif [[ "$mode" == "offline" ]]; then
        echo -e "${YELLOW}! Offline mode (self-reported)${NC}"
    fi
elif [[ "$SKIP_IDENTITY" != "true" && ! -f "$IDENTITY_FILE" ]]; then
    echo -e "${CYAN}Using VM fingerprint mode${NC}"
fi
echo ""

# Find ContainerLab topology file
CLAB_FILE=$(find "$LAB_DIR" -maxdepth 1 -name "*.clab.yml" -o -name "*.clab.yaml" 2>/dev/null | head -1)

if [[ -z "$CLAB_FILE" ]]; then
    echo -e "${RED}ERROR: No .clab.yml file found in $LAB_DIR${NC}"
    echo "Make sure you're in the lab directory or use -d option."
    exit 1
fi

echo -e "Found topology: ${GREEN}$CLAB_FILE${NC}"

# Parse lab name from topology file
LAB_NAME=$(grep "^name:" "$CLAB_FILE" | head -1 | awk '{print $2}' | tr -d '"' | tr -d "'")
if [[ -z "$LAB_NAME" ]]; then
    echo -e "${RED}ERROR: Could not parse lab name from $CLAB_FILE${NC}"
    exit 1
fi

echo -e "Lab name: ${GREEN}$LAB_NAME${NC}"

# Parse FRR nodes from topology (nodes with image: frr)
FRR_NODES=()
current_node=""
in_nodes_section=false

while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*nodes:[[:space:]]*$ ]]; then
        in_nodes_section=true
        continue
    fi
    
    if $in_nodes_section && [[ "$line" =~ ^[[:space:]]{0,2}[a-z]+: && ! "$line" =~ ^[[:space:]]{4,} ]]; then
        if [[ ! "$line" =~ ^[[:space:]]*nodes: ]]; then
            in_nodes_section=false
        fi
    fi
    
    if $in_nodes_section; then
        if [[ "$line" =~ ^[[:space:]]{2,4}([A-Za-z0-9_-]+):[[:space:]]*$ ]]; then
            current_node="${BASH_REMATCH[1]}"
        fi
        if [[ -n "$current_node" && "$line" =~ image:[[:space:]]*frr ]]; then
            FRR_NODES+=("$current_node")
            current_node=""
        fi
    fi
done < "$CLAB_FILE"

# Fallback: check running containers if parsing failed
if [[ ${#FRR_NODES[@]} -eq 0 ]]; then
    echo -e "${YELLOW}Parsing found no FRR nodes, checking running containers...${NC}"
    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            node_name="${container#clab-$LAB_NAME-}"
            FRR_NODES+=("$node_name")
        fi
    done < <(docker ps --format '{{.Names}}' 2>/dev/null | grep "^clab-$LAB_NAME-" | while read c; do
        if docker exec "$c" which vtysh &>/dev/null; then
            echo "$c"
        fi
    done)
fi

if [[ ${#FRR_NODES[@]} -eq 0 ]]; then
    echo -e "${RED}ERROR: No FRR nodes found!${NC}"
    echo "Make sure the lab is deployed with 'sudo containerlab deploy'"
    exit 1
fi

echo -e "FRR nodes found: ${GREEN}${FRR_NODES[*]}${NC}"
echo ""

# Get task name if not provided
if [[ -z "$TASK_NAME" ]]; then
    read -p "Enter task/checkpoint name (e.g., 'task1', 'task3_complete'): " TASK_NAME
    if [[ -z "$TASK_NAME" ]]; then
        TASK_NAME="checkpoint"
    fi
fi

# Sanitize task name
TASK_NAME=$(echo "$TASK_NAME" | tr ' ' '_' | tr -cd 'A-Za-z0-9_-')

# Create checkpoint directory
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CHECKPOINT_NAME="${LAB_NAME}_${TASK_NAME}_${TIMESTAMP}"
CHECKPOINT_PATH="$CHECKPOINTS_DIR/$LAB_NAME/$CHECKPOINT_NAME"
mkdir -p "$CHECKPOINT_PATH"

echo -e "${CYAN}Creating checkpoint: $CHECKPOINT_NAME${NC}"
echo ""

# Find previous checkpoint for hash chain
PREV_MANIFEST=""
PREV_HASH="GENESIS"
if [[ -d "$CHECKPOINTS_DIR/$LAB_NAME" ]]; then
    PREV_MANIFEST=$(find "$CHECKPOINTS_DIR/$LAB_NAME" -name "manifest.json" -type f 2>/dev/null | 
                    xargs -I {} dirname {} | 
                    sort | 
                    tail -1)
    if [[ -n "$PREV_MANIFEST" && -f "$PREV_MANIFEST/manifest.json" ]]; then
        PREV_HASH=$(grep '"checkpoint_hash"' "$PREV_MANIFEST/manifest.json" | cut -d'"' -f4)
        echo -e "Previous checkpoint: ${YELLOW}$(basename $PREV_MANIFEST)${NC}"
    fi
fi

# Collect VM fingerprint
VM_FINGERPRINT_HASH="none"
if [[ "$SKIP_FINGERPRINT" != "true" ]]; then
    VM_FINGERPRINT_HASH=$(collect_vm_fingerprint "$CHECKPOINT_PATH/vm_fingerprint.txt")
    echo -e "VM Fingerprint: ${GREEN}${VM_FINGERPRINT_HASH:0:16}...${NC}"
fi
echo ""

# Collect system state
echo "Collecting system state..."
BOOT_TIME=$(who -b 2>/dev/null | awk '{print $3, $4}' || uptime -s 2>/dev/null || echo "unknown")
UPTIME=$(cat /proc/uptime | cut -d' ' -f1)
CURRENT_BOOT_ID=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo "unknown")

# Dump configs and histories
echo "Dumping router configurations and histories..."
CONFIGS_DIR="$CHECKPOINT_PATH/configs"
HISTORIES_DIR="$CHECKPOINT_PATH/histories"
LOGS_DIR="$CHECKPOINT_PATH/logs"
mkdir -p "$CONFIGS_DIR" "$HISTORIES_DIR" "$LOGS_DIR"

for node in "${FRR_NODES[@]}"; do
    container="clab-$LAB_NAME-$node"
    echo -n "  $node: "
    
    # Check if container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        echo -e "${RED}container not running${NC}"
        continue
    fi
    
    # Dump running config
    if docker exec "$container" vtysh -c "show running-config" > "$CONFIGS_DIR/${node}.conf" 2>/dev/null; then
        echo -n "config "
    else
        echo -n "(no config) "
    fi
    
    # Dump bash history
    {
        docker exec "$container" cat /root/.bash_history 2>/dev/null
        docker exec "$container" cat /home/*/.bash_history 2>/dev/null
    } > "$HISTORIES_DIR/${node}_bash.history" 2>/dev/null
    
    # Dump vtysh history
    {
        docker exec "$container" cat /root/.history_vtysh 2>/dev/null
        docker exec "$container" cat /home/*/.history_vtysh 2>/dev/null
    } > "$HISTORIES_DIR/${node}_vtysh.history" 2>/dev/null
    
    if [[ -s "$HISTORIES_DIR/${node}_bash.history" || -s "$HISTORIES_DIR/${node}_vtysh.history" ]]; then
        echo -n "history "
    fi
    
    # Dump FRR logs
    docker exec "$container" cat /var/log/frr/frr.log > "$LOGS_DIR/${node}_frr.log" 2>/dev/null
    docker exec "$container" cat /var/log/frr/bgpd.log >> "$LOGS_DIR/${node}_frr.log" 2>/dev/null
    
    if [[ -s "$LOGS_DIR/${node}_frr.log" ]]; then
        echo -n "logs "
    fi
    
    echo -e "${GREEN}OK${NC}"
done

# Remove empty files
find "$CHECKPOINT_PATH" -type f -empty -delete

# Copy identity file to checkpoint (if exists and not skipped)
if [[ "$SKIP_IDENTITY" != "true" && -f "$IDENTITY_FILE" ]]; then
    cp "$IDENTITY_FILE" "$CHECKPOINT_PATH/.lab_identity"
fi

# Calculate file hashes
echo ""
echo "Calculating checksums..."
HASHES_FILE="$CHECKPOINT_PATH/file_hashes.txt"
find "$CHECKPOINT_PATH" -type f ! -name "manifest.json" ! -name "file_hashes.txt" -exec sha256sum {} \; | 
    sed "s|$CHECKPOINT_PATH/||" | sort > "$HASHES_FILE"

# Calculate overall content hash
CONTENT_HASH=$(cat "$HASHES_FILE" | sha256sum | cut -d' ' -f1)

# Create chain hash (include VM fingerprint for integrity)
CHAIN_DATA="${PREV_HASH}|${CONTENT_HASH}|${identity_hash}|${VM_FINGERPRINT_HASH}|${TIMESTAMP}"
CHECKPOINT_HASH=$(echo -n "$CHAIN_DATA" | sha256sum | cut -d' ' -f1)

# Create manifest
cat > "$CHECKPOINT_PATH/manifest.json" << EOF
{
    "checkpoint_version": "${SCRIPT_VERSION}",
    "checkpoint_name": "${CHECKPOINT_NAME}",
    "lab_name": "${LAB_NAME}",
    "task_name": "${TASK_NAME}",
    "timestamp": "$(date -Iseconds)",
    "timestamp_unix": $(date +%s),
    
    "identity": {
        "group_id": "${group_id}",
        "students": "${students}",
        "identity_hash": "${identity_hash}",
        "mode": "${mode}",
        "activation_id": "${activation_id:-}"
    },
    
    "vm_fingerprint": {
        "fingerprint_hash": "${VM_FINGERPRINT_HASH}",
        "vbox_uuid": "$(sudo dmidecode -s system-uuid 2>/dev/null || echo 'unavailable')",
        "machine_id": "$(cat /etc/machine-id 2>/dev/null || echo 'unavailable')",
        "primary_mac": "$(ip link show 2>/dev/null | grep -A1 '^2:' | grep ether | awk '{print $2}' || echo 'unavailable')",
        "root_fs_uuid": "$(findmnt -n -o UUID / 2>/dev/null || echo 'unavailable')"
    },
    
    "system_state": {
        "boot_time": "${BOOT_TIME}",
        "uptime_seconds": ${UPTIME},
        "boot_id": "${CURRENT_BOOT_ID}",
        "hostname": "$(hostname 2>/dev/null || echo 'unknown')"
    },
    
    "chain": {
        "previous_hash": "${PREV_HASH}",
        "content_hash": "${CONTENT_HASH}",
        "checkpoint_hash": "${CHECKPOINT_HASH}"
    },
    
    "nodes_captured": [$(printf '"%s",' "${FRR_NODES[@]}" | sed 's/,$//')]
}
EOF

# Create combined dump file
COMBINED_FILE="$CHECKPOINT_PATH/${CHECKPOINT_NAME}_combined.txt"
{
    echo "═══════════════════════════════════════════════════════════════════"
    echo " LAB CHECKPOINT: $CHECKPOINT_NAME"
    echo " Generated: $(date)"
    if [[ "$group_id" != "unverified" ]]; then
        echo " Group: $group_id | Students: ${students//;/, }"
    else
        echo " Mode: VM fingerprint only (no group identity)"
    fi
    echo " VM Fingerprint: ${VM_FINGERPRINT_HASH:0:16}..."
    echo " Chain Hash: $CHECKPOINT_HASH"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    
    for conf in "$CONFIGS_DIR"/*.conf; do
        if [[ -f "$conf" ]]; then
            node=$(basename "$conf" .conf)
            echo "┌─────────────────────────────────────────────────────────────────"
            echo "│ ROUTER: $node"
            echo "└─────────────────────────────────────────────────────────────────"
            cat "$conf"
            echo ""
        fi
    done
} > "$COMBINED_FILE"

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN} Checkpoint created successfully!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
echo ""
echo "  Location       : $CHECKPOINT_PATH"
echo "  Task           : $TASK_NAME"
echo "  Timestamp      : $(date -Iseconds)"
if [[ "$group_id" != "unverified" ]]; then
    echo "  Group          : $group_id"
fi
echo "  VM Fingerprint : ${VM_FINGERPRINT_HASH:0:16}..."
echo "  Chain Hash     : ${CHECKPOINT_HASH:0:16}..."
echo "  Prev Hash      : ${PREV_HASH:0:16}..."
echo ""
echo -e "${CYAN}Files created:${NC}"
ls -la "$CHECKPOINT_PATH"/ | tail -n +2
echo ""
echo -e "${YELLOW}For submission, include the entire '$CHECKPOINT_NAME' folder.${NC}"
