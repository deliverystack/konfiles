#!/bin/bash

BASE_DELIVERY_API_URL="https://deliver.kontent.ai"
ENVIRONMENT_ID="97d53770-a796-0065-c458-d65e6dcfc537"
CONTENT_TYPE_HEADER="Content-Type: application/json"
FILE_BASE="./files"
CONTENT_TYPES_DIR="$FILE_BASE/content_types"
ENTRIES_DIR="$FILE_BASE/entries"
FLATTENED_ENTRIES_DIR="$FILE_BASE/flattened_entries"
URL_BASE_DIR="$FILE_BASE/url_based_structure"

download_entries_for_content_type() {
    local content_type=$1
    local page_size=100
    local skip=0

    response=$(curl -s -H "$CONTENT_TYPE_HEADER" \
        "$BASE_DELIVERY_API_URL/$ENVIRONMENT_ID/items?system.type=$content_type&skip=$skip&limit=$page_size&includeTotalCount=true")
    total_items=$(echo "$response" | jq -r '.pagination.total_count')

    while (( skip < total_items )); do
        response=$(curl -s -H "$CONTENT_TYPE_HEADER" \
            "$BASE_DELIVERY_API_URL/$ENVIRONMENT_ID/items?system.type=$content_type&skip=$skip&limit=$page_size&includeTotalCount=true")

        echo "$response" | jq -c '.items[]' | while read -r entry; do
            entry_id=$(echo "$entry" | jq -r '.system.id')
            entry_file="$ENTRIES_DIR/$content_type/$entry_id.json"
            mkdir -p "$(dirname "$entry_file")"
            echo "$entry" > "$entry_file"
            echo "$0 : Saved original entry: $entry_file"
        done

        skip=$((skip + page_size))
    done
}

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
    codename=`echo "$entry" | jq -r '.system.codename' | tr ' ' '_' | tr '[:upper:]' '[:lower:]'`
    cp $output_file "$ENTRIES_DIR/$codename.json"
    echo "$0 : Flattened entry saved to: $output_file and $ENTRIES_DIR/$codename.json"
}

process_entries() {
    local content_type=$1
    
    for entry_file in "$ENTRIES_DIR/$content_type/"*.json; do

        # "If there are no .json files in the directory...
        # the loop will still execute once, with entry_file holding 
        # the literal string "$ENTRIES_DIR/$content_type/"*.json.
        [[ -f "$entry_file" ]] || continue

        entry=$(< "$entry_file")
        entry_id=$(echo "$entry" | jq -r '.system.id')
        entry_name=$(echo "$entry" | jq -r '.system.name' | tr ' ' '_' | tr '[:upper:]' '[:lower:]')
        output_file="$FLATTENED_ENTRIES_DIR/$content_type/$entry_name.json"
        mkdir -p "$(dirname "$output_file")"
        flatten_entry "$entry" "$output_file"
        output_file_by_id="$FLATTENED_ENTRIES_DIR/$content_type/$entry_id.json"
        cp "$output_file" "$output_file_by_id"
        echo "$0 : Duplicated flattened entry to ID structure: $output_file_by_id"
        url=$(echo "$entry" | jq -r '.elements.pagecontent__url.value')

        if [[ -n "$url" && "$url" != "null" ]]; then
            if [[ "$url" == "/" ]]; then
                url_path="home"
            else
                url_path="${url#/}"
            fi
            
            url_dir="$URL_BASE_DIR/$url_path"
            mkdir -p "$(dirname "$url_dir")"
            cp "$output_file" "$url_dir.json"
            echo "$0 : Copied flattened entry to URL structure: $url_dir.json"
        fi
    done
}

mkdir -p "$CONTENT_TYPES_DIR" "$ENTRIES_DIR" "$FLATTENED_ENTRIES_DIR" "$URL_BASE_DIR"

# read content types
content_types=()
while read -r type; do
    codename=$(echo "$type" | jq -r '.system.codename')
    echo "$type" > "$CONTENT_TYPES_DIR/$codename.json"
    echo "$0 : Saved content type: $CONTENT_TYPES_DIR/$codename.json"
    content_types+=("$codename")
done < <(curl -s -H "$CONTENT_TYPE_HEADER" "$BASE_DELIVERY_API_URL/$ENVIRONMENT_ID/types" | jq -c '.types[]')

# process entries for content types
for content_type in "${content_types[@]}"; do
    echo "$0 : Processing content type: $content_type (${#content_types[@]} total)"
    download_entries_for_content_type "$content_type" &
    wait
    process_entries "$content_type" &
done

wait
echo "$0 : Finished."