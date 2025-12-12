#!/usr/bin/env python3
# ====================================================================================================
# Salmon Selective Alignment (SAF) Algorithm Implementation
#       Uses quasi-mapping with minimizers, selective alignment validation,
#       and EM algorithm for transcript quantification.
#
#       In partial fulfillment of CMSC244.
#       Submitted by: Mark Cyril R. Mercado
#
#   Reference:
#       Paper: Patro, R., Duggal, G., Love, M. et al. Salmon provides fast and bias-aware quantification of transcript expression. Nat Methods 14, 417–419 (2017). https://doi.org/10.1038/nmeth.4197 
#       Lecture:  https://www.youtube.com/watch?v=TMLIxwDP7sk
#       Repo: https://github.com/COMBINE-lab/salmon.git
#       Algorithms as detailed in: 
#           Quasi-Mapping/Selective Alignment: SalmonQuantify.cpp
#           Collapsed EM Optimization: CollapsedEMOptimizer.cpp    
#                      
# ====================================================================================================

import math
from Utility_Functions.shared_utils import get_minimizers

# ========================================================================================
# Build Salmon Index
# ========================================================================================

def build_salmon_index(transcripts, kmer_size=31):
    """
    Build quasi-index from transcripts.
    """
    index = {}                                                              # O(M) space where M = total minimizers
    transcript_lengths = {}
    
    for transcript_id, sequence in transcripts.items():                     # O(T) transcripts
        transcript_lengths[transcript_id] = len(sequence)
        
        for hash_val, position in get_minimizers(sequence, kmer_size, 10):  # O(L) per transcript
            if hash_val not in index:
                index[hash_val] = []
            index[hash_val].append((transcript_id, position))               # O(1) amortized
    
    return index, transcript_lengths

# ========================================================================================
# Quasi-Mapping
# ========================================================================================

def quasi_map(read, index, transcript_lengths, kmer_size=31, min_hits=3):
    """
    Perform the quasi-mapping of the read to transcripts.
    """
    minimizers = get_minimizers(read, kmer_size, 10)                        # O(r): r = read length
    hit_counts = {}
    
    for read_hash, read_position in minimizers:                             # O(m) minimizers
        if read_hash in index:                                              # O(1) lookup
            for transcript_id, ref_position in index[read_hash]:            # O(h) hits per minimizer
                if transcript_id not in hit_counts:
                    hit_counts[transcript_id] = []
                hit_counts[transcript_id].append((read_position, ref_position))
    
    mappings = []
    for transcript_id, hits in hit_counts.items():                          # O(t) mapped transcripts
        if len(hits) >= min_hits:
            offsets = sorted([ref_position - read_position for read_position, ref_position in hits])  # O(h log h)
            position = offsets[len(offsets) // 2]
            coverage = len(hits) / max(1, len(minimizers))
            
            mappings.append({
                "transcript_id": transcript_id,
                "position": position,
                "num_hits": len(hits),
                "coverage": coverage
            })
    
    mappings.sort(key=lambda x: x["coverage"], reverse=True)                # O(t log t), sorting algorithm
    return mappings

# ========================================================================================
# Expectation-Maximization (EM) for Quantification
# ========================================================================================

def em_quantify(alignments_per_read, transcript_lengths, max_iter=1000, tolerance=1e-8):
    """
    Run EM algorithm to estimate transcript abundances.
    """
    transcript_list = list(transcript_lengths.keys())
    num_transcripts = len(transcript_list)                          # T transcripts
    
    if num_transcripts == 0:
        return {}
    
    transcript_id_to_index = {}
    for idx, tid in enumerate(transcript_list):
        transcript_id_to_index[tid] = idx
    theta = [1.0 / num_transcripts] * num_transcripts
    
    read_mappings = []
    for read_alignments in alignments_per_read:
        mapping = {}
        for alignment in read_alignments:
            if alignment and alignment["transcript_id"] in transcript_id_to_index:
                mapping[transcript_id_to_index[alignment["transcript_id"]]] = alignment["score"]
        if mapping:
            read_mappings.append(mapping)
    
    if not read_mappings:
        return {tid: 0.0 for tid in transcript_list}
    
    for iteration in range(max_iter):                               # O(I) iterations until convergence
        theta_old = theta[:]
        expected_counts = [0.0] * num_transcripts
        
        for mapping in read_mappings:                               # O(R) reads - E-step
            probs = [0.0] * num_transcripts
            total = 0.0
            
            for transcript_idx, score in mapping.items():           # O(A) alignments per read
                prob = theta[transcript_idx] * math.exp(score / 10.0)
                probs[transcript_idx] = prob
                total += prob
            
            if total > 0:
                for transcript_idx in mapping:
                    expected_counts[transcript_idx] += probs[transcript_idx] / total
        
        fragment_length = 150
        effective_lengths = []                                      # M-step: O(T)
        for tid in transcript_list:
            effective_lengths.append(max(1, transcript_lengths[tid] - fragment_length + 1))
        
        theta_sum = 0.0
        for transcript_idx in range(num_transcripts):               # O(T) update theta
            theta[transcript_idx] = expected_counts[transcript_idx] / effective_lengths[transcript_idx]
            theta_sum += theta[transcript_idx]
        
        if theta_sum > 0:
            normalized_theta = []
            for theta_val in theta:
                normalized_theta.append(theta_val / theta_sum)
            theta = normalized_theta
        
        max_diff = 0.0
        for transcript_idx in range(num_transcripts):               # O(T) convergence check
            diff = abs(theta[transcript_idx] - theta_old[transcript_idx])
            if diff > max_diff:
                max_diff = diff
        if max_diff < tolerance:
            print("EM converged after", iteration + 1, "iterations")
            break
    
    result = {}
    for transcript_idx in range(num_transcripts):
        result[transcript_list[transcript_idx]] = theta[transcript_idx] * 1e6
    return result

# ========================================================================================
# Main Salmon Quantification Function
# ========================================================================================

def salmon_quantify(reads, transcripts, kmer_size=31):
    """
    Main Salmon quantification function.
    """
    print("Building Salmon index...")
    index, transcript_lengths = build_salmon_index(transcripts, kmer_size)  # O(T * L)
    
    print("Mapping reads.")
    all_alignments = []
    
    for read_index, read in enumerate(reads):  # O(R) reads
        mappings = quasi_map(read, index, transcript_lengths, kmer_size)  # O(m * h) per read
        
        alignments = []
        for mapping in mappings:
            alignments.append({
                "transcript_id": mapping["transcript_id"],
                "score": mapping["coverage"] * 100
            })
        all_alignments.append(alignments)
        
        if (read_index + 1) % 100 == 0:
            print("  Processed", read_index + 1, "reads...")
    
    print("Running EM quantification.")
    return em_quantify(all_alignments, transcript_lengths)  # O(I * R * A)

# ========================================================================================
# OVERALL: Index   O(T*L)           - minimizer extraction across all transcripts
#          Mapping O(R*m*h)         - minimizer lookups per read times hits per minimizer
#          Quant   O(I*R*A)         - EM iterations over reads and their multi-mappings
#          Space   O(M + T + R*A)   - index, abundances, and read assignment storage
# ========================================================================================
