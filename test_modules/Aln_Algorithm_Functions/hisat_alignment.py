#!/usr/bin/env python3
# ====================================================================================================
# HISAT Alignment Algorithm Implementation
#       Implements splice-aware alignment using FM-index with seed-and-extend strategy.
#
#       In partial fulfillment of CMSC244.
#       Submitted by: Mark Cyril R. Mercado
#   
#   Reference: 
#       Paper: Kim, D., Langmead, B. & Salzberg, S. HISAT: a fast spliced aligner with low memory requirements. Nat Methods 12, 357–360 (2015). https://doi.org/10.1038/nmeth.3317
#       Repo: https://github.com/DaehwanKimLab/hisat2.git
#       Algorithm of HISAT: 
#           FM-index search: gfm.cpp
#           Seed-and-extend: aligner_seed.cpp
#           Splice detection: hi_aligner.h
#           CIGAR with N (introns): hi_aligner.h and aln_sink.cpp
#
# ====================================================================================================

from Utility_Functions.shared_utils import (
    build_suffix_array, build_BWT, build_count_table, build_occurrence_table,
    FM_backward_search
)

# ========================================================================================
# Finding the FM-Index Pattern
# ========================================================================================

def locate_pattern(pattern, suffix_array, count_table, occurence):
    """
    Find all positions of pattern in reference."""
    suffix_len = len(suffix_array)
    top, bottom = FM_backward_search(pattern, count_table, occurence, suffix_len)     # O(m) char-by-char
    if top >= bottom or top < 0:
        return []
    positions = []
    for index in range(top, bottom):                                                  # O(k) retrieving k suffix array entries
        positions.append(suffix_array[index])
    return sorted(positions)                                                          # O(k log k) - sorting algorithm; highest thus this is the main determinant in this step


# ========================================================================================
# Seed-and-Extend with Mismatches
# ========================================================================================

def count_mismatches(seq1, seq2):
    """
    Count number of mismatches between two sequences.
    """
    mismatches = 0
    for position in range(min(len(seq1), len(seq2))): # O(min(|seq1|, |seq2|)) single pass, kung alin ang maliit sa dalawa
        if seq1[position] != seq2[position]:
            mismatches += 1
    return mismatches


def seed_and_extend(read, reference, suffix_array, count_table, occurence, max_mismatches):
    """
    Seed-and-extend strategy for approximate matching.
    """
    alignments = []
    read_len = len(read)
    ref_len = len(reference)
    
    seed_len = max(8, read_len // (max_mismatches + 1))
    seed_positions = list(range(0, read_len - seed_len + 1, seed_len))
    checked_positions = {}
    
    for seed_offset in seed_positions:                                              # O(s), s meaning number of seeds
        seed = read[seed_offset:seed_offset + seed_len]
        hit_positions = locate_pattern(seed, suffix_array, count_table, occurence)  # O(m) per seed
        for hit_position in hit_positions:                                          # O(h) hits per seed
            read_start = hit_position - seed_offset
            if read_start < 0 or read_start + read_len > ref_len:
                continue
            if read_start in checked_positions:
                continue
            checked_positions[read_start] = True
            
            ref_segment = reference[read_start:read_start + read_len]
            mismatch_count = count_mismatches(read, ref_segment)                    # O(r) per candidate
            
            if mismatch_count <= max_mismatches:
                alignments.append({
                    "position": read_start,
                    "cigar": str(read_len) + "M",
                    "mismatches": mismatch_count,
                    "score": read_len - mismatch_count,
                    "spliced": False
                })
    return alignments

# ========================================================================================
# Splice-Aware Alignment
# ========================================================================================

def check_canonical_splice_site(reference, donor_position, acceptor_position):
    """
    Check for canonical GT-AG splice site signals.
    """
    if donor_position + 2 > len(reference) or acceptor_position < 2:
        return False
    donor = reference[donor_position:donor_position + 2]                # O(1) constant time
    acceptor = reference[acceptor_position - 2:acceptor_position]       # O(1)
    return donor == "GT" and acceptor == "AG"


def spliced_alignment(read, reference, suffix_array, count_table, occurence):
    """
    Attempt spliced alignment for reads spanning introns.
    """
    alignments = []
    read_len = len(read)
    min_anchor = 8
    max_intron = 500000
    min_intron = 50
    
    for split_position in range(min_anchor, read_len - min_anchor):         # O(r) split positions
        left_segment = read[:split_position]
        right_segment = read[split_position:]
        
        left_positions = locate_pattern(left_segment, suffix_array, count_table, occurence)  # O(m)
        right_positions = locate_pattern(right_segment, suffix_array, count_table, occurence)  # O(m)
        
        for left_pos in left_positions:  # O(L) left anchor hits
            left_end = left_pos + len(left_segment)
            for right_pos in right_positions:  # O(R) right anchor hits
                intron_length = right_pos - left_end
                
                if min_intron <= intron_length <= max_intron:
                    if check_canonical_splice_site(reference, left_end, right_pos):
                        cigar = str(len(left_segment)) + "M" + str(intron_length) + "N" + str(len(right_segment)) + "M"
                        alignments.append({
                            "position": left_pos,
                            "cigar": cigar,
                            "mismatches": 0,
                            "score": read_len,
                            "spliced": True,
                            "intron_start": left_end,
                            "intron_end": right_pos
                        })
    return alignments

# ========================================================================================
# Main HISAT Alignment Function
# ========================================================================================

def hisat_align(read, reference, max_mismatches=2):
    """
    Main HISAT alignment function.
    """
    ref_with_term = reference + "$"
    
    print("Building FM-index.")
    suffix_array = build_suffix_array(ref_with_term)  # O(n log n)
    bwt = build_BWT(ref_with_term, suffix_array)  # O(n)
    count_table, _ = build_count_table(bwt)  # O(n)
    occurence = build_occurrence_table(bwt)  # O(n)
    
    print("Searching for exact matches.")
    exact_positions = locate_pattern(read, suffix_array, count_table, occurence)  # O(r + k)
    
    alignments = []
    for position in exact_positions:
        alignments.append({
            "position": position,
            "cigar": str(len(read)) + "M",
            "mismatches": 0,
            "score": len(read),
            "spliced": False
        })
    
    if len(alignments) == 0:
        print("Trying approximate matching.")
        alignments = seed_and_extend(read, reference, suffix_array, count_table, occurence, max_mismatches)  # O(s * h * r)
    
    if len(alignments) == 0:
        print("Trying spliced alignment.")
        alignments = spliced_alignment(read, reference, suffix_array, count_table, occurence)  # O(r * L * R)
    
    alignments.sort(key=lambda x: x["score"], reverse=True)
    return alignments

# ========================================================================================
# OVERALL: Index O(n log n), 
#          Steps or Tiers:
#               Per-Read O(r + k) exact  - FM-index search scales with read length plus matches found
#               O(s*h*r) approx          - seeds × hits per seed × mismatch counting across read
#               O(r*L*R) spliced         - split positions × left anchor hits × right anchor hits
# ========================================================================================
