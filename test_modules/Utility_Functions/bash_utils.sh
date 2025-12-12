#!/bin/bash
# ==============================================================================
# BASH UTILITY FUNCTIONS
# ==============================================================================
# Helper functions for the main run_algorithm.sh script.
# ==============================================================================

create_directories() {
    # Create output directories
    for dir in "$@"; do
        mkdir -p "$dir"
        echo "Created: $dir"
    done
}

activate_conda_env() {
    # Activate conda environment, run setup if needed
    local env_name="$1"
    local setup_script="$2"
    
    eval "$(conda shell.bash hook)"
    
    if conda activate "$env_name" 2>/dev/null; then
        echo "Activated conda environment: $env_name"
    else
        echo "WARNING: Could not activate $env_name"
        conda activate "$env_name"
    fi
    
    python --version
}
