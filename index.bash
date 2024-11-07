#!/bin/bash

# Define the parent directory to start processing from; use the current directory if $1 is absent
PARENT_DIR="${1:-$(pwd)}"

# Define a prefix with the script name in green
SCRIPT_PREFIX="\e[32m$0\e[0m : "

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${SCRIPT_PREFIX}The 'jq' tool is required but not installed. Please install jq and try again." >&2
    exit 1
fi

# Process directories in a loop, without recursion
process_directories() {
    local dir_queue=("$1")  # Queue to hold directories to process

    while [[ ${#dir_queue[@]} -gt 0 ]]; do
        local dir="${dir_queue[0]}"
        dir_queue=("${dir_queue[@]:1}")  # Remove the first element from the queue

        local entries=()
        local children=()
        local has_files=false

        echo -e "${SCRIPT_PREFIX}Processing directory: $dir"

        # Associative array to store sort values for directories if matching files are found
        declare -A dir_sort_values

        # Process files in the current directory
        for item in "$dir"/*.json; do
            if [[ -f "$item" && "$(basename "$item")" != "index.json" ]]; then
                local title=$(jq -r '.commoncontent__title // .title // empty' "$item")
                local sort=$(jq -r '.sort // 1000' "$item")  # Default sort value if not specified
                if [[ -n "$title" ]]; then
                    entries+=("{\"file\": \"$(basename "$item")\", \"title\": \"$title\", \"sort\": $sort}")
                    has_files=true
                    echo -e "${SCRIPT_PREFIX}  Added entry: {\"file\": \"$(basename "$item")\", \"title\": \"$title\", \"sort\": $sort}"

                    # If a directory exists with the same name as the file (excluding .json), store its sort value
                    local dir_name="${item%.json}"
                    if [[ -d "$dir_name" ]]; then
                        dir_sort_values["$(basename "$dir_name")"]=$sort
                    fi
                else
                    echo -e "${SCRIPT_PREFIX}  No title found in $item"
                fi
            else
                echo -e "${SCRIPT_PREFIX}  Skipping file $item"
            fi
        done

        # Sort entries based on the sort key and join as a comma-separated JSON array
        IFS=$'\n' entries=($(echo "${entries[*]}" | jq -s 'sort_by(.sort) | .[] | del(.sort)' | jq -c '.'))
        local entries_string=$(IFS=,; echo "[${entries[*]}]")

        # Process each subdirectory, adding it to the queue if it needs processing
        for item in "$dir"/*; do
            if [[ -d "$item" ]]; then
                echo -e "${SCRIPT_PREFIX}  Found subdirectory: $item"

                # Queue the directory for further processing
                dir_queue+=("$item")

                local child_name=$(basename "$item")
                local sort_value=${dir_sort_values["$child_name"]:-1000}  # Default sort value if not specified
                children+=("{\"name\": \"$child_name\", \"sort\": $sort_value}")
                echo -e "${SCRIPT_PREFIX}  Added child to children: $child_name with sort value $sort_value"
            else
                echo -e "${SCRIPT_PREFIX}  $item is not a directory, skipping"
            fi
        done

        # Sort children by the sort value and join as a comma-separated JSON array
        IFS=$'\n' children=($(echo "${children[*]}" | jq -s 'sort_by(.sort) | .[] | del(.sort)' | jq -c '.'))
        local children_string=$(IFS=,; echo "[${children[*]}]")

        # Determine the correct path for the index file, set root explicitly
        local index_file="$dir/index.json"
        if [[ "$dir" == "$PARENT_DIR" ]]; then
            index_file="$PARENT_DIR/index.json"
        fi

        # Only create an index.json if the directory has files or non-empty children
        echo -e "${SCRIPT_PREFIX}Creating index.json at $index_file"
        if [[ "$has_files" == true || "$children_string" != "[]" ]]; then
            echo "{\"entries\": $entries_string, \"children\": $children_string}" > "$index_file"
            echo -e "${SCRIPT_PREFIX}Created index.json at $index_file"
            echo -e "${SCRIPT_PREFIX}Listing directory content after creation for $dir:"
            ls -l "$dir"
            echo -e "${SCRIPT_PREFIX}Content of $index_file:" && cat "$index_file"
        else
            echo -e "${SCRIPT_PREFIX}Skipping creation of index.json in: $dir (no files or children)"
        fi
    done
}

# Start processing from the parent directory
process_directories "$PARENT_DIR"
