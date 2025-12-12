#!/bin/bash

create_runtime_graphs() {
    local base_dir="$1"
    
    for prog_dir in "$base_dir"/*; do
        [ ! -d "$prog_dir" ] && continue
        
        local prog_name=$(basename "$prog_dir")
        local csv_file="${prog_dir}/${prog_name}.csv"
        
        [ ! -f "$csv_file" ] && continue
        
        local output_dir="${prog_dir}/Runtime_Complexity"
        mkdir -p "$output_dir"
        
        Rscript z_analysis/modules/runtime_plots.R "$csv_file" "$output_dir"
    done
}

create_memory_graphs() {
    local base_dir="$1"
    
    for prog_dir in "$base_dir"/*; do
        [ ! -d "$prog_dir" ] && continue
        
        local prog_name=$(basename "$prog_dir")
        local csv_file="${prog_dir}/${prog_name}.csv"
        
        [ ! -f "$csv_file" ] && continue
        
        local output_dir="${prog_dir}/Memory_Usage"
        mkdir -p "$output_dir"
        
        Rscript z_analysis/modules/memory_plots.R "program" "$csv_file" "$output_dir" "$prog_name"
    done
}

create_input_size_list_all() {
    local base_dir="$1"
    local output_dir="${base_dir}/Memory_Usage/Input_Size_Lists"
    
    Rscript z_analysis/modules/memory_plots.R "input_list" "$base_dir" "$output_dir"
}

create_input_size_list_selected() {
    local base_dir="$1"
    shift
    local programs=("$@")
    local output_dir="${base_dir}/Memory_Usage/Input_Size_Lists"
    
    # Create individual program lists
    for prog in "${programs[@]}"; do
        Rscript z_analysis/modules/memory_plots.R "input_list" "$base_dir" "$output_dir" "$prog"
    done
}

create_space_time_graphs() {
    local base_dir="$1"
    
    for prog_dir in "$base_dir"/*; do
        [ ! -d "$prog_dir" ] && continue
        
        local prog_name=$(basename "$prog_dir")
        local csv_file="${prog_dir}/${prog_name}.csv"
        
        [ ! -f "$csv_file" ] && continue
        
        local output_dir="${prog_dir}/Space_Time_Tradeoffs"
        mkdir -p "$output_dir"
        
        Rscript z_analysis/modules/space_time_plots.R "$csv_file" "$output_dir"
    done
}

create_scalability_graphs() {
    local base_dir="$1"
    
    for prog_dir in "$base_dir"/*; do
        [ ! -d "$prog_dir" ] && continue
        
        local prog_name=$(basename "$prog_dir")
        local csv_file="${prog_dir}/${prog_name}.csv"
        
        [ ! -f "$csv_file" ] && continue
        
        local output_dir="${prog_dir}/Scalability"
        mkdir -p "$output_dir"
        
        Rscript z_analysis/modules/scalability_plots.R "$csv_file" "$output_dir"
    done
}

create_comparative_graphs() {
    local base_dir="$1"
    local output_dir="${base_dir}/Comparative_Analysis"
    local programs="hisat2,rsem-calculate-expression,salmon_quant"
    local input_size="$2"
    
    mkdir -p "$output_dir"
    Rscript z_analysis/modules/comparative_plots.R "$base_dir" "$output_dir" "$programs" "$input_size"
}

create_cost_graphs() {
    local base_dir="$1"
    
    for prog_dir in "$base_dir"/*; do
        [ ! -d "$prog_dir" ] && continue
        
        local prog_name=$(basename "$prog_dir")
        local csv_file="${prog_dir}/${prog_name}.csv"
        
        [ ! -f "$csv_file" ] && continue
        
        local output_dir="${prog_dir}/Cost_Analysis"
        mkdir -p "$output_dir"
        
        Rscript z_analysis/modules/cost_plots.R "$csv_file" "$output_dir"
    done
}

create_statistical_graphs() {
    local base_dir="$1"
    
    for prog_dir in "$base_dir"/*; do
        [ ! -d "$prog_dir" ] && continue
        
        local prog_name=$(basename "$prog_dir")
        local csv_file="${prog_dir}/${prog_name}.csv"
        
        [ ! -f "$csv_file" ] && continue
        
        local output_dir="${prog_dir}/Statistical_Analysis"
        mkdir -p "$output_dir"
        
        Rscript z_analysis/modules/statistical_plots.R "$csv_file" "$output_dir"
    done
}

create_resource_utilization_graphs() {
    local base_dir="$1"
    
    for prog_dir in "$base_dir"/*; do
        [ ! -d "$prog_dir" ] && continue
        
        local prog_name=$(basename "$prog_dir")
        local csv_file="${prog_dir}/${prog_name}.csv"
        
        [ ! -f "$csv_file" ] && continue
        
        local output_dir="${prog_dir}/Resource_Utilization"
        mkdir -p "$output_dir"
        
        Rscript z_analysis/modules/resource_utilization_plots.R "$csv_file" "$output_dir"
    done
}
