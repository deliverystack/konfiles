#!/bin/bash

BASE_DELIVERY_API_URL="https://deliver.kontent.ai"
ENVIRONMENT_ID="97d53770-a796-0065-c458-d65e6dcfc537"
CONTENT_TYPE_HEADER="Content-Type: application/json"
FILE_BASE="./files"
CONTENT_TYPES_DIR="$FILE_BASE/content_types"
ENTRIES_DIR="$FILE_BASE/entries"
FLATTENED_ENTRIES_DIR="$FILE_BASE/flattened_entries"
URL_BASE_DIR="$FILE_BASE/url_based_structure"

# Function to download entries for a specific content type
download_entries_for_content_type() {
    local content_type=$1
    local page_size=2 # for esting paralleliazation logic without creating dozens of items
    local skip=0

    while true; do
        local response=$(curl -s -H "$CONTENT_TYPE_HEADER" \
            "$BASE_DELIVERY_API_URL/$ENVIRONMENT_ID/items?system.type=$content_type&skip=$skip&limit=$page_size&includeTotalCount=true")

        local total_items=$(echo "$response" | jq -r '.pagination.total_count')
        echo "$response" | jq -c '.items[]' | while read -r entry; do
            entry_id=$(echo "$entry" | jq -r '.system.id')
            entry_file="$ENTRIES_DIR/$content_type/$entry_id.json"
            mkdir -p "$(dirname "$entry_file")"
            echo "$entry" > "$entry_file"
            echo "Saved original entry: $entry_file"
        done

        if [[ "$total_items" == "null" || "$total_items" -le "$((skip + page_size))" ]]; then
            break
        fi

        skip=$((skip + page_size))
    done
}

# Function to flatten an entry
flatten_entry() {
    local entry=$1
    local output_file=$2

    jq -n --argjson system "$(echo "$entry" | jq '.system')" \
       --argjson elements "$(echo "$entry" | jq '.elements')" \
       '{
           id: $system.id,
           name: $system.name,
           codename: $system.codename,
           language: $system.language,
           type: $system.type,
           collection: $system.collection,
           sitemap_locations: $system.sitemap_locations,
           last_modified: $system.last_modified,
           workflow: $system.workflow,
           workflow_step: $system.workflow_step
       }
       + ($elements | to_entries | map({(.key): .value.value}) | add)' > "$output_file"

    echo "Flattened entry saved to: $output_file"
}

# Function to process entries to create flattened versions
process_entries() {
    local content_type=$1
    for entry_file in "$ENTRIES_DIR/$content_type/"*.json; do
        [[ -f "$entry_file" ]] || continue
        entry=$(< "$entry_file")

        entry_id=$(echo "$entry" | jq -r '.system.id')
        entry_name=$(echo "$entry" | jq -r '.system.name' | tr ' ' '_' | tr '[:upper:]' '[:lower:]')
        
        output_file="$FLATTENED_ENTRIES_DIR/$content_type/$entry_name.json"
        mkdir -p "$(dirname "$output_file")"
        flatten_entry "$entry" "$output_file"

        output_file_by_id="$FLATTENED_ENTRIES_DIR/$content_type/$entry_id.json"
        cp "$output_file" "$output_file_by_id"
        echo "Duplicated flattened entry to ID structure: $output_file_by_id"

        # Determine URL for saving to the URL structure
        url=$(echo "$entry" | jq -r '.elements.pagecontent__url.value')

        if [[ -n "$url" && "$url" != "null" ]]; then
            # Set filename as 'home.json' if URL is '/'
            if [[ "$url" == "/" ]]; then
                url_path="home"
            else
                url_path="${url#/}"
            fi
            
            url_dir="$URL_BASE_DIR/$url_path"
            mkdir -p "$(dirname "$url_dir")"
            cp "$output_file" "$url_dir.json"
            echo "Copied flattened entry to URL structure: $url_dir.json"
        fi
    done
}

# Ensure required directories exist
mkdir -p "$CONTENT_TYPES_DIR" "$ENTRIES_DIR" "$FLATTENED_ENTRIES_DIR" "$URL_BASE_DIR"

# Fetch content types dynamically and store definitions as JSON
content_types=()

# Fetch content types dynamically and store definitions as JSON
while read -r type; do
    codename=$(echo "$type" | jq -r '.system.codename')
    echo "$type" > "$CONTENT_TYPES_DIR/$codename.json"
    echo "Saved content type: $CONTENT_TYPES_DIR/$codename.json"
    content_types+=("$codename")  # Add codename to the array
done < <(curl -s -H "$CONTENT_TYPE_HEADER" "$BASE_DELIVERY_API_URL/$ENVIRONMENT_ID/types" | jq -c '.types[]')

# Now content_types array will be correctly populated
echo "Final list of content types:"
echo "${content_types[@]}"
echo "Total content types count: ${#content_types[@]}"

# Process content types and download their entries in parallel to the extent possible
for content_type in "${content_types[@]}"; do
    echo "Processing content type: $content_type"
    download_entries_for_content_type "$content_type" &
    
    wait
    process_entries "$content_type" 
done

wait

echo "Script completed!"
