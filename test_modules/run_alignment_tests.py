#!/usr/bin/env python3
"""
Alignment Test Runner
=====================

Runs test mode: Small subset of reads for algorithm analysis

"""

import os
import sys
import time

# Add test_modules to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Importing Functions
from Utility_Functions.fastq_utils import read_fastq, read_fasta, write_alignments_to_sam
from complexity_analysis import (
    create_complexity_tracker, add_measurement, measure_memory_usage,
    generate_full_report, generate_combined_comparison
)
from Utility_Functions.shared_utils import reverse_complement
from Aln_Algorithm_Functions.hisat_alignment import hisat_align
from Aln_Algorithm_Functions.bowtie_alignment import bowtie2_align
from Aln_Algorithm_Functions.salmon_saf_alignment import salmon_quantify

# =============================================================================
# CONFIGURATION
# =============================================================================

# Input files
FASTQ_R1 = "test_inputs/SRR3884686_1_val_1.fq.gz"
FASTQ_R2 = "test_inputs/SRR3884686_2_val_2.fq.gz"

# Reference options (change as needed)
REFERENCE_FASTA = "test_inputs/All_Smel_Genes.fasta"

# Test mode settings (small subset for algorithm analysis)
TEST_SIZES = [10, 50, 100, 200, 500]
TEST_REF_LIMIT = 10000
TEST_TRANSCRIPT_LIMIT = 10  # Number of transcripts for Salmon test

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

def ensure_dir(directory):
    """Create directory if it doesn't exist."""
    if not os.path.exists(directory):
        os.makedirs(directory)


# =============================================================================
# A Single Implementation of Alignment Test Runner
# =============================================================================

def run_alignment_test(reads, reference, ref_name, output_dir, aligner_name, align_func, align_kwargs=None, try_reverse=False, progress_interval=50):
    """
    Generic alignment test runner.
    
    Args:
        reads:              List of read dictionaries with 'id', 'sequence', 'quality' keys
        reference:          Reference sequence string
        ref_name:           Reference name for output
        output_dir:         Output directory path
        aligner_name:       Name of the aligner
        align_func:         Alignment function to call (hisat_align, bowtie2_align, etc.)
        align_kwargs:       Additional keyword arguments for align_func (default: None)
        try_reverse:        Whether to try reverse complement if no alignment found (default: False)
        progress_interval:  Print progress every N reads (default: 50)
    
    Returns:
        Tuple of (alignments, runtime, memory_mb)
    """
    if align_kwargs is None:
        align_kwargs = {}
    
    
    # Measure initial memory
    mem_before = measure_memory_usage()
    start_time = time.time()
    
    alignments = []
    aligned_count = 0
    
    for i, read in enumerate(reads):
        seq = read['sequence']
        
        # Run alignment
        alns = align_func(seq, reference, **align_kwargs)
        
        # Try reverse complement if requested and no alignment found
        if len(alns) == 0 and try_reverse:
            rc_seq = reverse_complement(seq)
            alns = align_func(rc_seq, reference, **align_kwargs)
        
        if len(alns) > 0:
            best = alns[0]
            aligned_count += 1
            alignments.append({
                'read_id': read['id'],
                'position': best['position'],
                'cigar': best['cigar'],
                'mapq': best.get('mapq', min(60, best.get('score', 60))),
                'sequence': seq,
                'quality': read.get('quality', '*'),
                'unmapped': False
            })
        else:
            alignments.append({
                'read_id': read['id'],
                'sequence': seq,
                'quality': read.get('quality', '*'),
                'unmapped': True
            })
        
        # Progress indicator
        if (i + 1) % progress_interval == 0:
            print("    Processed", i + 1, "/", len(reads), "reads...")
    
    end_time = time.time()
    runtime = end_time - start_time
    
    # Measure memory
    mem_after = measure_memory_usage()
    memory_used = max(0, mem_after - mem_before)
    
    print("  Aligned:", aligned_count, "/", len(reads), "reads")
    print("  Runtime:", round(runtime, 4), "seconds")
    
    return alignments, runtime, memory_used


# =============================================================================
# Aligner Wrapper per Alignment Algorithm
# =============================================================================

def run_hisat_test(reads, reference, ref_name, output_dir):
    """Run HISAT alignment test on a set of reads."""
    return run_alignment_test(
        reads, reference, ref_name, output_dir,
        aligner_name="HISAT",
        align_func=hisat_align,
        align_kwargs={'max_mismatches': 2},
        try_reverse=True
    )


def run_bowtie2_test(reads, reference, ref_name, output_dir):
    """Run Bowtie2 alignment test on a set of reads."""
    return run_alignment_test(
        reads, reference, ref_name, output_dir,
        aligner_name="Bowtie2",
        align_func=bowtie2_align,
        align_kwargs={'seed_len': 15},
        try_reverse=False
    )


def run_salmon_test(reads, transcripts, output_dir):
    """
    Run Salmon quantification test on a set of reads.
    
    Returns:
        Tuple of (tpm_results, runtime, memory_mb)
    """
    print("  Running Salmon quantification on", len(reads), "reads...")
    
    mem_before = measure_memory_usage()
    start_time = time.time()
    
    # Extract just sequences for Salmon
    read_sequences = []
    for read in reads:
        read_sequences.append(read['sequence'])
    
    # Run quantification
    tpm = salmon_quantify(read_sequences, transcripts, kmer_size=15)
    
    end_time = time.time()
    runtime = end_time - start_time
    
    mem_after = measure_memory_usage()
    memory_used = max(0, mem_after - mem_before)
    
    # Count transcripts with expression
    expressed = sum(1 for t in tpm.values() if t > 0)
    
    return tpm, runtime, memory_used


# =============================================================================
# MAIN TEST FUNCTION
# =============================================================================

def get_output_dirs():
    """Get output directories for test mode."""
    return {
        'hisat': "Outputs/HISAT/python_test",
        'bowtie': "Outputs/Bowtie/python_test",
        'salmon': "Outputs/Salmon_Saf/python_test",
        'combined': "Outputs/python_test_comparison"
    }


def run_test_mode(transcripts, reference, ref_name):
    """Run test mode: small subset for algorithm analysis."""
    dirs = get_output_dirs()
    
    for d in dirs.values():
        ensure_dir(d)
    
    # Truncate reference for test mode
    if len(reference) > TEST_REF_LIMIT:
        reference = reference[:TEST_REF_LIMIT]
        print("Truncated reference to", TEST_REF_LIMIT, "bp for test mode")
    
    # Create complexity trackers
    hisat_tracker = create_complexity_tracker()
    hisat_tracker['algorithm'] = 'HISAT'
    bowtie2_tracker = create_complexity_tracker()
    bowtie2_tracker['algorithm'] = 'Bowtie2'
    salmon_tracker = create_complexity_tracker()
    salmon_tracker['algorithm'] = 'Salmon'
    
    # Prepare test transcripts for Salmon
    test_transcripts = {}
    count = 0
    for tid in transcripts:
        if count >= TEST_TRANSCRIPT_LIMIT:
            break
        test_transcripts[tid] = transcripts[tid][:5000]
        count += 1
    
    # Run tests for each size
    for num_reads in TEST_SIZES:
        print("Testing with", num_reads, "reads")
        
        reads = read_fastq(FASTQ_R1, max_reads=num_reads)
        print("Loaded", len(reads), "reads")
        
        if len(reads) == 0:
            continue
        
        # HISAT
        print("HISAT Test")
        alns, runtime, memory = run_hisat_test(reads, reference, ref_name, dirs['hisat'])
        add_measurement(hisat_tracker, len(reads), runtime, memory, 
                       len(reads) * len(reference), str(len(reads)) + " reads")
        sam_file = os.path.join(dirs['hisat'], "alignments_" + str(num_reads) + ".sam")
        write_alignments_to_sam(sam_file, alns, ref_name, len(reference))
        
        # Bowtie2
        print("Bowtie2 Test")
        alns, runtime, memory = run_bowtie2_test(reads, reference, ref_name, dirs['bowtie'])
        add_measurement(bowtie2_tracker, len(reads), runtime, memory,
                       len(reads) * len(reference), str(len(reads)) + " reads")
        sam_file = os.path.join(dirs['bowtie'], "alignments_" + str(num_reads) + ".sam")
        write_alignments_to_sam(sam_file, alns, ref_name, len(reference))
        
        # Salmon
        print("Salmon Test")
        tpm, runtime, memory = run_salmon_test(reads, test_transcripts, dirs['salmon'])
        add_measurement(salmon_tracker, len(reads), runtime, memory,
                       len(reads) * len(test_transcripts), str(len(reads)) + " reads")
        tpm_file = os.path.join(dirs['salmon'], "quant_" + str(num_reads) + ".tsv")
        with open(tpm_file, 'w') as f:
            f.write("transcript_id\tTPM\n")
            for tid, val in sorted(tpm.items(), key=lambda x: x[1], reverse=True):
                f.write(tid + "\t" + str(round(val, 4)) + "\n")
    
    # Generate reports
    print("GENERATING COMPLEXITY REPORTS")
    generate_full_report(hisat_tracker, dirs['hisat'])
    generate_full_report(bowtie2_tracker, dirs['bowtie'])
    generate_full_report(salmon_tracker, dirs['salmon'])
    generate_combined_comparison([hisat_tracker, bowtie2_tracker, salmon_tracker], dirs['combined'])
    
    return dirs


def run_all_tests():
    """Run alignment tests in test mode."""
    
    print("ALIGNMENT ALGORITHM TESTING")
    print("Input FASTQ:", FASTQ_R1)
    print("Reference:", REFERENCE_FASTA)
    
    ensure_dir("logs")
    
    # Check input files
    if not os.path.exists(FASTQ_R1):
        print("ERROR: FASTQ file not found:", FASTQ_R1)
        return
    if not os.path.exists(REFERENCE_FASTA):
        print("ERROR: Reference FASTA not found:", REFERENCE_FASTA)
        return
    
    # Load reference
    print("Loading Reference")
    transcripts = read_fasta(REFERENCE_FASTA)
    print("Loaded", len(transcripts), "sequences")
    
    ref_name = list(transcripts.keys())[0]
    reference = transcripts[ref_name]
    print("Using reference:", ref_name, "length:", len(reference))
    
    # Run test mode
    dirs = run_test_mode(transcripts, reference, ref_name)
    
    # Summary
    print("TEST COMPLETE")
    print("Output directories:")
    for k, v in dirs.items():
        print(" ", k + ":", v)


# =============================================================================
# ENTRY POINT
# =============================================================================

run_all_tests()
