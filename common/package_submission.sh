#!/bin/bash
#
# package_submission.sh - Create final submission archive
# Version 2.0 - Uses tar.gz (no zip dependency)
#

IDENTITY_FILE="$HOME/.lab_identity"
CHECKPOINTS_DIR="$HOME/lab_checkpoints"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
    echo "Usage: $0 <lab_name> [output_directory]"
    echo ""
    echo "Creates a submission archive for the specified lab."
    echo ""
    echo "Arguments:"
    echo "  lab_name         Name of the lab (e.g., 'bgp', 'bgp2')"
    echo "  output_directory Where to save the archive (default: current directory)"
    echo ""
    echo "Example:"
    echo "  $0 bgp ~/Desktop"
    exit 1
}

if [[ -z "$1" ]]; then
    usage
fi

LAB_NAME="$1"
# Convert to absolute path
OUTPUT_DIR="${2:-.}"
if [[ -d "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
else
    OUTPUT_DIR="$(pwd)"
fi

# Check identity (optional now)
if [[ -f "$IDENTITY_FILE" ]]; then
    # Load identity (handle quoted values)
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
else
    group_id="unverified"
    students="anonymous"
    mode="fingerprint-only"
fi

# Check if checkpoints exist
LAB_CHECKPOINTS="$CHECKPOINTS_DIR/$LAB_NAME"
if [[ ! -d "$LAB_CHECKPOINTS" ]]; then
    echo -e "${RED}ERROR: No checkpoints found for lab '$LAB_NAME'${NC}"
    echo "Available labs:"
    ls -1 "$CHECKPOINTS_DIR" 2>/dev/null || echo "  (none)"
    exit 1
fi

# Count checkpoints
CHECKPOINT_COUNT=$(find "$LAB_CHECKPOINTS" -name "manifest.json" | wc -l)
if [[ $CHECKPOINT_COUNT -eq 0 ]]; then
    echo -e "${RED}ERROR: No valid checkpoints found in $LAB_CHECKPOINTS${NC}"
    exit 1
fi

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           SUBMISSION PACKAGE CREATOR                       ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
if [[ "$group_id" != "unverified" ]]; then
    echo -e "Group ID    : ${GREEN}$group_id${NC}"
    echo -e "Students    : ${GREEN}${students//;/, }${NC}"
fi
echo -e "Lab         : ${GREEN}$LAB_NAME${NC}"
echo -e "Checkpoints : ${GREEN}$CHECKPOINT_COUNT${NC}"
if [[ "$mode" == "online" ]]; then
    echo -e "Identity    : ${GREEN}✓ Verified${NC}"
elif [[ "$group_id" != "unverified" ]]; then
    echo -e "Identity    : ${YELLOW}! Offline (unverified)${NC}"
fi
echo ""

# List checkpoints
echo "Checkpoints to include:"
find "$LAB_CHECKPOINTS" -name "manifest.json" -exec dirname {} \; | sort | while read cp_dir; do
    task=$(grep -o '"task_name"[[:space:]]*:[[:space:]]*"[^"]*"' "$cp_dir/manifest.json" 2>/dev/null | cut -d'"' -f4)
    timestamp=$(grep -o '"timestamp"[[:space:]]*:[[:space:]]*"[^"]*"' "$cp_dir/manifest.json" 2>/dev/null | cut -d'"' -f4)
    echo "  - $task ($timestamp)"
done
echo ""

# Generate archive name
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ARCHIVE_NAME="${LAB_NAME}_${group_id}_${TIMESTAMP}.tar.gz"
ARCHIVE_PATH="$OUTPUT_DIR/$ARCHIVE_NAME"

# Create temporary directory for packaging
TEMP_DIR=$(mktemp -d)
PACKAGE_DIR="$TEMP_DIR/${LAB_NAME}_${group_id}"
mkdir -p "$PACKAGE_DIR"

# Copy checkpoints
cp -r "$LAB_CHECKPOINTS"/* "$PACKAGE_DIR/"

# Copy identity file (if exists)
if [[ -f "$IDENTITY_FILE" ]]; then
    cp "$IDENTITY_FILE" "$PACKAGE_DIR/.lab_identity"
fi

# Create summary file
SUMMARY_FILE="$PACKAGE_DIR/SUBMISSION_SUMMARY.txt"
cat > "$SUMMARY_FILE" << EOF
LAB SUBMISSION SUMMARY
═══════════════════════════════════════════════════════════════════

Group ID        : $group_id
Students        : ${students//;/, }
Lab             : $LAB_NAME
Course          : ${course_code:-N/A}
Packaged        : $(date -Iseconds)
Identity Mode   : ${mode:-offline}
Identity Hash   : $identity_hash
EOF

if [[ -n "$activation_id" ]]; then
    echo "Activation ID   : $activation_id" >> "$SUMMARY_FILE"
fi

cat >> "$SUMMARY_FILE" << EOF

CHECKPOINTS INCLUDED:
───────────────────────────────────────────────────────────────────
EOF

find "$LAB_CHECKPOINTS" -name "manifest.json" | sort | while read manifest; do
    task=$(grep -o '"task_name"[[:space:]]*:[[:space:]]*"[^"]*"' "$manifest" 2>/dev/null | cut -d'"' -f4)
    timestamp=$(grep -o '"timestamp"[[:space:]]*:[[:space:]]*"[^"]*"' "$manifest" 2>/dev/null | cut -d'"' -f4)
    checkpoint_hash=$(grep -o '"checkpoint_hash"[[:space:]]*:[[:space:]]*"[^"]*"' "$manifest" 2>/dev/null | cut -d'"' -f4)
    echo "" >> "$SUMMARY_FILE"
    echo "Task: $task" >> "$SUMMARY_FILE"
    echo "  Timestamp : $timestamp" >> "$SUMMARY_FILE"
    echo "  Hash      : ${checkpoint_hash:0:32}..." >> "$SUMMARY_FILE"
done

echo "" >> "$SUMMARY_FILE"
echo "───────────────────────────────────────────────────────────────────" >> "$SUMMARY_FILE"
echo "This submission was created using the lab integrity verification system v2.0" >> "$SUMMARY_FILE"

# Create tar.gz archive
echo "Creating archive..."
cd "$TEMP_DIR"
tar -czf "$ARCHIVE_PATH" "$(basename $PACKAGE_DIR)"

# Cleanup
rm -rf "$TEMP_DIR"

# Verify
if [[ -f "$ARCHIVE_PATH" ]]; then
    SIZE=$(du -h "$ARCHIVE_PATH" | cut -f1)
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN} Submission archive created successfully!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "  File     : $ARCHIVE_PATH"
    echo "  Size     : $SIZE"
    echo ""
    echo -e "${YELLOW}Submit this file according to your instructor's guidelines.${NC}"
    echo ""
    echo "To extract: tar -xzf $ARCHIVE_NAME"
else
    echo -e "${RED}ERROR: Failed to create archive${NC}"
    exit 1
fi
