#!/bin/bash

PARENT_DIR="${1:-$(pwd)}"
OUTPUT_FILE="${2:-consolidated_structure.json}"
SCRIPT_PREFIX="\e[32m$0\e[0m : "

build_structure() {
    local dir="$1"
    local json_structure="{"

    local index_file="$dir/index.json"
    if [[ -f "$index_file" ]]; then
        local entries=$(jq '.entries' "$index_file")
        local children=$(jq '.children' "$index_file")
        json_structure+="\"entries\": $entries, \"children\": $children"
    fi

    local child_dirs=()
    for sub_dir in "$dir"/*; do
        if [[ -d "$sub_dir" ]]; then
            child_name=$(basename "$sub_dir")
            child_dirs+=("\"$child_name\": $(build_structure "$sub_dir")")
        fi
    done

    if [[ ${#child_dirs[@]} -gt 0 ]]; then
        if [[ -n "$json_structure" ]]; then
            json_structure+=", "
        fi
        json_structure+="\"subdirectories\": {$(IFS=,; echo "${child_dirs[*]}")}"
    fi

    json_structure+="}"
    echo "$json_structure"
}

echo -e "${SCRIPT_PREFIX}Building consolidated JSON structure from $PARENT_DIR"
consolidated_json=$(build_structure "$PARENT_DIR")

echo "$consolidated_json" | jq '.' > "$OUTPUT_FILE"
echo -e "${SCRIPT_PREFIX}Consolidated JSON structure saved to $OUTPUT_FILE"
