#!/usr/bin/env python3
# ====================================================================================================
# This containss Shared Utility Functions for Alignment Algorithms
#       Common functions used by HISAT, Bowtie2, and Salmon aligners.
#
#       In partial fulfillment of CMSC244.
#       Submitted by: Mark Cyril R. Mercado
#
# ====================================================================================================

# ========================================================================================
# DNA Sequence Utilities
# ========================================================================================

def reverse_complement(seq):
    """Compute reverse complement of DNA sequence."""
    complement = {"A": "T", "T": "A", "G": "C", "C": "G", "N": "N"}
    result = ""
    for base in reversed(seq):
        result += complement.get(base, "N")
    return result

# ========================================================================================
# Burrows-Wheeler Transform (BWT) Construction
# ========================================================================================

def build_suffix_array(text):
    """Build suffix array by sorting all suffixes of text."""
    n = len(text)
    suffixes = []
    for i in range(n):
        suffixes.append((text[i:], i))
    suffixes.sort(key=lambda x: x[0])
    suffix_array = []
    for suffix, index in suffixes:
        suffix_array.append(index)
    return suffix_array


def build_BWT(text, suffix_array):
    """Construct BWT from suffix array."""
    n = len(text)
    bwt = ""
    for i in range(n):
        sa_index = suffix_array[i]
        if sa_index == 0:
            bwt += text[n - 1]
        else:
            bwt += text[sa_index - 1]
    return bwt

# ========================================================================================
# FM-Index Construction
# ========================================================================================

def build_count_table(bwt):
    """Build C table: cumulative count of characters lexicographically smaller."""
    counts = {}
    for c in bwt:
        if c not in counts:
            counts[c] = 0
        counts[c] += 1
    
    sorted_chars = sorted(counts.keys())
    c_table = {}
    total = 0
    for c in sorted_chars:
        c_table[c] = total
        total += counts[c]
    return c_table, counts


def build_occurrence_table(bwt):
    """Build occurrence table for rank queries."""
    n = len(bwt)
    alphabet = []
    for c in bwt:
        if c not in alphabet:
            alphabet.append(c)
    
    occ = {}
    for c in alphabet:
        occ[c] = [0] * (n + 1)
    
    for i in range(n):
        for c in alphabet:
            occ[c][i + 1] = occ[c][i]
        curr_char = bwt[i]
        occ[curr_char][i + 1] += 1
    return occ


def FM_backward_search(pattern, c_table, occ, bwt_len):
    """Perform backward search on FM-index."""
    top = 0
    bottom = bwt_len
    
    for i in range(len(pattern) - 1, -1, -1):
        c = pattern[i]
        if c not in c_table:
            return -1, -1
        top = c_table[c] + (occ[c][top] if top > 0 else 0)
        bottom = c_table[c] + occ[c][bottom]
        if top >= bottom:
            return -1, -1
    return top, bottom

# ========================================================================================
# K-mer Utilities (For Salmon)
# ========================================================================================

def hash_kmer(kmer):
    """Hash a k-mer using polynomial rolling hash."""
    base_map = {"A": 0, "C": 1, "G": 2, "T": 3}
    h = 0
    for c in kmer:
        h = h * 4 + base_map.get(c, 0)
    return h


def get_minimizers(sequence, k, w):
    """Extract minimizers from sequence."""
    if len(sequence) < k:
        return []
    
    kmers = []
    for i in range(len(sequence) - k + 1):
        kmer = sequence[i:i + k]
        kmers.append((hash_kmer(kmer), i))
    
    minimizers = []
    last_minimizer = None
    
    for i in range(len(kmers) - w + 1):
        window = kmers[i:i + w]
        min_kmer = min(window, key=lambda x: x[0])
        if last_minimizer is None or min_kmer != last_minimizer:
            minimizers.append(min_kmer)
            last_minimizer = min_kmer
    return minimizers
