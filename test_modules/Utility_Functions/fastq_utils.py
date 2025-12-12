#!/usr/bin/env python3
# ====================================================================================================
# FASTQ Utilities for Alignment Testing
#       Provides functions to read FASTQ files (gzipped or plain) and FASTA reference files.
#
#       In partial fulfillment of CMSC244.
#       Submitted by: Mark Cyril R. Mercado
#
# ====================================================================================================

import gzip

# ========================================================================================
# Read FASTQ Files
# ========================================================================================

def read_fastq(filepath, max_reads=None):
    """
    Read sequences from a FASTQ file (supports .gz compression).
    """
    reads = []
    is_gzipped = filepath.endswith('.gz')
    
    if is_gzipped:
        file_handle = gzip.open(filepath, 'rt')
    else:
        file_handle = open(filepath, 'r')
    
    try:
        line_num = 0
        current_read = {}
        
        for line in file_handle:
            line = line.strip()
            position = line_num % 4
            
            if position == 0:
                current_read = {'id': line[1:]}
            elif position == 1:
                current_read['sequence'] = line
            elif position == 2:
                pass
            elif position == 3:
                current_read['quality'] = line
                reads.append(current_read)
                if max_reads is not None and len(reads) >= max_reads:
                    break
            line_num += 1
    finally:
        file_handle.close()
    
    return reads


# ========================================================================================
# Read FASTA Reference Files
# ========================================================================================

def read_fasta(filepath):
    """
    Read sequences from a FASTA file.
    """
    sequences = {}
    current_id = None
    current_seq = []
    
    is_gzipped = filepath.endswith('.gz')
    if is_gzipped:
        file_handle = gzip.open(filepath, 'rt')
    else:
        file_handle = open(filepath, 'r')
    
    try:
        for line in file_handle:
            line = line.strip()
            
            if line.startswith('>'):
                if current_id is not None:
                    sequences[current_id] = ''.join(current_seq)
                current_id = line[1:].split()[0]
                current_seq = []
            else:
                current_seq.append(line.upper())
        
        if current_id is not None:
            sequences[current_id] = ''.join(current_seq)
    finally:
        file_handle.close()
    
    return sequences


# ========================================================================================
# Write Output Files
# ========================================================================================

def write_sam_header(output_file, reference_name, reference_length):
    """
    Write SAM format header.
    """
    with open(output_file, 'w') as f:
        f.write("@HD\tVN:1.6\tSO:unsorted\n")
        f.write("@SQ\tSN:" + reference_name + "\tLN:" + str(reference_length) + "\n")
        f.write("@PG\tID:test_aligner\tPN:test_aligner\tVN:1.0\n")


def write_sam_alignment(output_file, read_id, flag, ref_name, position, mapq, cigar, sequence, quality):
    """
    Append a SAM alignment record to file.
    """
    with open(output_file, 'a') as f:
        line = "\t".join([
            read_id,
            str(flag),
            ref_name,
            str(position + 1),
            str(mapq),
            cigar,
            "*",
            "0",
            "0",
            sequence,
            quality
        ])
        f.write(line + "\n")


def write_alignments_to_sam(output_file, alignments, ref_name, ref_length):
    ""
    "Write all alignments to SAM file."""
    write_sam_header(output_file, ref_name, ref_length)
    
    for aln in alignments:
        flag = 0
        if aln.get('unmapped', False):
            flag = 4
        
        write_sam_alignment(
            output_file,
            aln.get('read_id', 'unknown'),
            flag,
            ref_name if not aln.get('unmapped', False) else "*",
            aln.get('position', 0),
            aln.get('mapq', 255),
            aln.get('cigar', '*'),
            aln.get('sequence', '*'),
            aln.get('quality', '*')
        )
