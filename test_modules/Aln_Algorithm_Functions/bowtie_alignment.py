#!/usr/bin/env python3
# ====================================================================================================
# Bowtie2 Alignment Algorithm Implementation
#       Implements seed-and-extend alignment using FM-index with local and global alignment modes.
#
#       In partial fulfillment of CMSC244.
#       Submitted by: Mark Cyril R. Mercado
#
#   Reference:
#       Paper: Langmead, B., Salzberg, S. Fast gapped-read alignment with Bowtie 2. Nat Methods 9, 357–359 (2012). https://doi.org/10.1038/nmeth.1923
#       Repository: https://github.com/BenLangmead/bowtie2.git
#       Algorithm of Bowtie2 as detailed in their repo: 
#           Seed Finding (FM-index/BWT-based):        
#               aligner_seed.cpp
#           Smith-Waterman Extensions: 
#               aligner_sw.cpp
# ====================================================================================================

from Utility_Functions.shared_utils import (
    build_suffix_array, build_BWT, build_count_table, build_occurrence_table,
    FM_backward_search
)

# ========================================================================================
# Finding FM-Index Pattern
# ========================================================================================

def find_pattern(pattern, suffix_array, count_table, occurrence):
    """
    Find all occurrences of pattern in reference.
    """
    n = len(suffix_array)
    low, high = FM_backward_search(pattern, count_table, occurrence, n)  # O(m) - one character lookup per pattern character
    if low >= high or low < 0:
        return []
    positions = []
    for index in range(low, high):                  # O(k) - extracting k positions from suffix array
        positions.append(suffix_array[index])
    return sorted(positions)                        # O(k log k), sorting algorithm; main determinant of the steps

# ========================================================================================
# CIGAR String Compression
# CIGAR meaning, Compact Idiosyncratic Gapped Alignment Report
#      Codes/Encodes for the match/mismatches (M), indel (I) (D), introns (N), and soft clipping (S)
# ========================================================================================

def compress_cigar(ops):
    """
    Compress CIGAR operations into standard format.
    """
    if len(ops) == 0:
        return ""
    cigar = ""
    current_op = ops[0]
    count = 1
    for op_index in range(1, len(ops)):  # O(n) single pass where n = CIGAR operations
        if ops[op_index] == current_op:
            count += 1
        else:
            cigar += str(count) + current_op
            current_op = ops[op_index]
            count = 1
    cigar += str(count) + current_op
    return cigar

# ========================================================================================
# Smith-Waterman Local Alignment
# ========================================================================================

def smith_waterman(query, target, match_score=2, mismatch_penalty=-4, gap_extend=-1):
    """
    Smith-Waterman local alignment algorithm.
    """
    query_len, target_len = len(query), len(target)
    
    score_matrix = []                                   # O(m * n) initialization of matrix
    for _ in range(query_len + 1):
        score_matrix.append([0] * (target_len + 1))
    traceback = []                                      # O(m * n) space for traceback matrix
    for _ in range(query_len + 1):
        traceback.append([0] * (target_len + 1))
    max_score, max_row, max_col = 0, 0, 0
    
    for row in range(1, query_len + 1):                 # O(m * n) matrix filling
        for col in range(1, target_len + 1):            # each cell O(1)
            match = score_matrix[row-1][col-1] + (match_score if query[row-1] == target[col-1] else mismatch_penalty)
            delete = score_matrix[row-1][col] + gap_extend
            insert = score_matrix[row][col-1] + gap_extend
            
            score_matrix[row][col] = max(0, match, delete, insert)
            
            if score_matrix[row][col] == match:
                traceback[row][col] = 1
            elif score_matrix[row][col] == delete:
                traceback[row][col] = 3
            elif score_matrix[row][col] == insert:
                traceback[row][col] = 2
            
            if score_matrix[row][col] > max_score:
                max_score, max_row, max_col = score_matrix[row][col], row, col
    
    cigar_ops = []
    row, col = max_row, max_col
    while row > 0 and col > 0 and score_matrix[row][col] > 0:  # O(m + n) traceback
        if traceback[row][col] == 1:
            cigar_ops.append("M")
            row, col = row - 1, col - 1
        elif traceback[row][col] == 3:
            cigar_ops.append("I")
            row -= 1
        elif traceback[row][col] == 2:
            cigar_ops.append("D")
            col -= 1
        else:
            break
    
    cigar_ops.reverse()
    return max_score, compress_cigar(cigar_ops), row, col

# ========================================================================================
# Extracting Seeds
# ========================================================================================

def extract_seeds(read, seed_len, seed_interval):
    """
    Extract seeds from read at regular intervals.
    """
    seeds = []
    offset = 0
    while offset <= len(read) - seed_len:  # O(r / i) where r = read length, i = interval
        seeds.append((read[offset:offset + seed_len], offset))
        offset += seed_interval
    return seeds

# ========================================================================================
# Main Function for Bowtie2 Alignment
# ========================================================================================

def bowtie2_align(read, reference, seed_len=22, seed_interval=15):
    """
    Main Bowtie2 alignment function using local mode.
    """
    ref_with_term = reference + "$"
    
    print("Building FM-index.")
    suffix_array = build_suffix_array(ref_with_term)            # O(n log n) where n = reference length
    bwt = build_BWT(ref_with_term, suffix_array)                # O(n)
    count_table, _ = build_count_table(bwt)                     # O(n)
    occurrence = build_occurrence_table(bwt)                    # O(n)
    
    print("Extracting seeds and finding hits.")
    seeds = extract_seeds(read, seed_len, seed_interval)        # O(r / i)
    candidate_positions = []
    
    for seed, offset in seeds:                                  # O(s) where s = number of seeds
        positions = find_pattern(seed, suffix_array, count_table, occurrence)  # O(m + k) per seed
        for position in positions:                              # O(k) hits per seed
            read_start = position - offset
            if 0 <= read_start <= len(reference) - len(read):
                if read_start not in candidate_positions:
                    candidate_positions.append(read_start)
    
    print("Extending candidates.")
    alignments = []
    
    for position in candidate_positions:                        # O(c) where c = candidate positions
        ref_region = reference[position:position + len(read) + 20]
        score, cigar, query_start, target_start = smith_waterman(read, ref_region)  # O(r * w) per candidate
        if score > 0:
            alignments.append({"position": position + target_start, "cigar": cigar, "score": score})
    
    alignments.sort(key=lambda x: x["score"], reverse=True)
    
    for alignment_index, alignment in enumerate(alignments):
        if alignment_index == 0:
            alignment["mapq"] = min(60, alignment["score"])
        else:
            alignment["mapq"] = max(0, 60 - 10 * alignment_index)
    
    return alignments

# ========================================================================================
# OVERALL: Index    O(n log n)      - suffix array construction is the key determinant for Big O; dominates index building
#          Per-Read O(s*m + c*r*w)  - seed lookups + Smith-Waterman extensions per candidate
#          Space    O(n + r*w)      - FM-index storage plus DP matrices for extension
# ========================================================================================
