#!/bin/bash
# ==============================================================================
# CMSC244 - Alignment Algorithm Test Runner
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ==============================================================================
# Configs
# ==============================================================================

RUN_TEST=true         # Run test mode (a small subset only for algorithm analysis)

# ==============================================================================
# INPUT/OUTPUT PATHS
# ==============================================================================

FASTQ_R1="test_inputs/SRR3884686_1_val_1.fq.gz"
FASTQ_R2="test_inputs/SRR3884686_2_val_2.fq.gz"
#REFERENCE="test_inputs/Eggplant_V4.1_transcripts.function.fa"
REFERENCE="test_inputs/All_Smel_Genes.fasta"

OUTPUT_HISAT="z_Outputs/HISAT"
OUTPUT_BOWTIE="z_Outputs/Bowtie"
OUTPUT_SALMON="z_Outputs/Salmon_Saf"

CONDA_ENV="cmsc_aln"

source test_modules/Utility_Functions/logging_utils.sh
source test_modules/Utility_Functions/bash_utils.sh

main() {
    echo "Date: $(date)"
    echo "Run Test: $RUN_TEST"
    
    setup_logging false
    create_directories "$OUTPUT_HISAT" "$OUTPUT_BOWTIE" "$OUTPUT_SALMON" "logs"
    
    # Run tests
    if [[ "$RUN_TEST" == "true" ]]; then
        activate_conda_env "$CONDA_ENV" "setup_cmsc244.sh"
        run_with_space_time_log --input "test_inputs" --output "Outputs" \
            python test_modules/run_alignment_tests.py --mode test
    fi
    
    echo "Results: $OUTPUT_HISAT, $OUTPUT_BOWTIE, $OUTPUT_SALMON"
    echo "Logs: logs/"
}

main
