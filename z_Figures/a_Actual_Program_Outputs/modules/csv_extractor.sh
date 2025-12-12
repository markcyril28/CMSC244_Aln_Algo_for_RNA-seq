#!/bin/bash

# Extract command base name from full command string
extract_command_name() {
    local cmd="$1"
    # Remove leading/trailing quotes and spaces
    cmd=$(echo "$cmd" | sed 's/^[[:space:]]*"*//;s/"*[[:space:]]*$//')
    
    # Extract first word and get basename
    local first_word=$(echo "$cmd" | awk '{print $1}')
    first_word=$(basename "$first_word" 2>/dev/null || echo "$first_word")
    
    if [[ "$first_word" == "samtools" || "$first_word" == "salmon" ]]; then
        local second_word=$(echo "$cmd" | awk '{print $2}')
        echo "${first_word}_${second_word}"
    else
        echo "$first_word"
    fi
}

# Extract CPU count from command
extract_cpu_count() {
    local cmd="$1"
    # Try different patterns for thread count
    local cpu=""
    cpu=$(echo "$cmd" | sed -n 's/.*-p \([0-9]\+\).*/\1/p' | head -n1)
    [ -z "$cpu" ] && cpu=$(echo "$cmd" | sed -n 's/.*--threads=\([0-9]\+\).*/\1/p' | head -n1)
    [ -z "$cpu" ] && cpu=$(echo "$cmd" | sed -n 's/.*-@ \([0-9]\+\).*/\1/p' | head -n1)
    [ -z "$cpu" ] && cpu=$(echo "$cmd" | sed -n 's/.*--threads \([0-9]\+\).*/\1/p' | head -n1)
    echo "$cpu"
}

# Process single CSV file
process_csv_file() {
    local source_file="$1"
    local output_dir="$2"
    local mode="$3"
    local cpu_versioning="$4"
    
    [ ! -f "$source_file" ] && return
    
    # Read header
    local header=$(head -n1 "$source_file")
    
    # Process each data line
    tail -n +2 "$source_file" | while IFS= read -r line; do
        [ -z "$line" ] && continue
        
        # Extract command (second field in CSV)
        local command=$(echo "$line" | cut -d',' -f2)
        local cmd_name=$(extract_command_name "$command")
        
        [ -z "$cmd_name" ] && continue
        
        # Create program subfolder
        local prog_dir="${output_dir}/${cmd_name}"
        mkdir -p "$prog_dir"
        
        # Write to combined file
        local output_file="${prog_dir}/${cmd_name}.csv"
        
        # Handle skip mode for combined file
        if [[ "$mode" == "skip" && -f "$output_file" ]]; then
            continue
        fi
        
        # Create file with header if doesn't exist
        [ ! -f "$output_file" ] && echo "$header" > "$output_file"
        
        # Append line
        echo "$line" >> "$output_file"
        
        # CPU versioning
        if [[ "$cpu_versioning" == "true" ]]; then
            local cpu_count=$(extract_cpu_count "$command")
            if [[ -n "$cpu_count" ]]; then
                local cpu_file="${prog_dir}/${cmd_name}_cpu${cpu_count}.csv"
                [ ! -f "$cpu_file" ] && echo "$header" > "$cpu_file"
                echo "$line" >> "$cpu_file"
            fi
        fi
    done
}

# Main extraction function
extract_per_command() {
    local source_dir="$1"
    local output_dir="$2"
    local mode="${3:-overwrite}"
    local cpu_versioning="${4:-false}"
    
    mkdir -p "$output_dir"
    
    # Clear existing files if overwrite mode
    [[ "$mode" == "overwrite" ]] && rm -rf "$output_dir"/*
    
    # Process all CSV files in source directory
    for csv_file in "$source_dir"/*.csv; do
        [ -f "$csv_file" ] && process_csv_file "$csv_file" "$output_dir" "$mode" "$cpu_versioning"
    done
}
