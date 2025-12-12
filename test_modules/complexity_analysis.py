#!/usr/bin/env python3
# ====================================================================================================
# Complexity Analysis Module
#      
#       In partial fulfillment of CMSC244.
#           by: Mark Cyril R. Mercado
#
# ====================================================================================================

import time
import os

# ========================================================================================
# Runtime Measurement Functions
# ========================================================================================

def measure_memory_usage():
    """Get current memory usage in MB."""
    with open('/proc/self/status') as f:
        for line in f:
            if line.startswith('VmRSS:'):               # RSS: Resident Set Size
                return int(line.split()[1]) / 1024
    return 0

# ========================================================================================
# Complexity Tracking
# ========================================================================================

def create_complexity_tracker():
    """Create a new complexity tracker dictionary."""
    return {
        'measurements': [],
        'algorithm': '',
        'input_sizes': [],
        'runtimes': [],
        'memory_usages': [],
        'operations_count': []
    }


def add_measurement(tracker, input_size, runtime, memory_mb, operations=0, label=""):
    """Add a measurement to the tracker. O(1)."""
    measurement = {
        'input_size': input_size,
        'runtime': runtime,
        'memory_mb': memory_mb,
        'operations': operations,
        'label': label
    }
    tracker['measurements'].append(measurement)
    tracker['input_sizes'].append(input_size)
    tracker['runtimes'].append(runtime)
    tracker['memory_usages'].append(memory_mb)
    tracker['operations_count'].append(operations)


# =============================================================================
# STEP 5: Exporting to CSV 
# =============================================================================

def export_to_csv(tracker, output_file):
    """Export measurements to CSV file for external graphing."""
    lines = []
    lines.append("input_size,runtime_sec,memory_mb,operations,label")
    
    for m in tracker['measurements']:
        line = ",".join([
            str(m['input_size']),
            str(m['runtime']),
            str(m['memory_mb']),
            str(m['operations']),
            '"' + m['label'] + '"'
        ])
        lines.append(line)
    
    with open(output_file, 'w') as f:
        f.write('\n'.join(lines))


# =============================================================================
# STEP 6: FULL REPORT GENERATION (CSV only, graphs in combined comparison)
# =============================================================================

def generate_full_report(tracker, output_dir):
    """
    Generate complexity report with CSV export only.
    Graphs are generated in combined comparison step.
    """
    os.makedirs(output_dir, exist_ok=True)
    
    # CSV export
    csv_file = os.path.join(output_dir, 'complexity_data.csv')
    export_to_csv(tracker, csv_file)
    
    print("Report generated in:", output_dir)
    print("  - complexity_data.csv")
    
    return ""


# =============================================================================
# STEP 8: Combined Comparison Graphs for All Recreated Algorithm
# =============================================================================

def generate_combined_comparison(trackers, output_dir):
    """
    Generate combined comparison for multiple algorithms.
    
    Args:
        trackers: List of tracker dictionaries, each with 'algorithm' key
        output_dir: Directory to save combined output
    """
    os.makedirs(output_dir, exist_ok=True)
    
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    
    # Rainbow color palette - distinct hues for algorithms
    colors = [
        '#E63946',  # Red - HISAT
        '#2A9D8F',  # Teal - Bowtie2
        '#9B5DE5',  # Purple - Salmon
        '#F4A261',  # Orange
        '#00CED1',  # Cyan
        '#FFD700',  # Gold/Yellow
    ]
    
    # Marker styles for different algorithms
    markers = ['o', 's', '^', 'D', 'v', 'p']
    
    # Get final test size for labels
    final_sizes = []
    for tracker in trackers:
        if len(tracker['measurements']) > 0:
            final_sizes.append(tracker['measurements'][-1]['input_size'])
    final_test_size = max(final_sizes) if final_sizes else 500
    
    # =====================================================================
    # GRAPH 1: Final Test Runtime and Memory Usage Bar Comparison
    # =====================================================================
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6))
    
    names = [t['algorithm'] for t in trackers if len(t['measurements']) > 0]
    final_runtimes = [t['measurements'][-1]['runtime'] for t in trackers if len(t['measurements']) > 0]
    final_memories = [t['measurements'][-1]['memory_mb'] for t in trackers if len(t['measurements']) > 0]
    
    # Runtime bar chart
    bars1 = ax1.bar(names, final_runtimes, color=colors[:len(names)], edgecolor='black', linewidth=1.5)
    ax1.set_ylabel('Runtime (seconds)', fontsize=12)
    ax1.set_title(f'Final Test Runtime ({final_test_size} reads)', fontsize=13, fontweight='bold')
    ax1.set_ylim(0, max(final_runtimes) * 1.15)
    for bar, val in zip(bars1, final_runtimes):
        ax1.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.02, 
                f'{val:.4f}s', ha='center', va='bottom', fontsize=11, fontweight='bold')
    
    # Memory bar chart
    bars2 = ax2.bar(names, final_memories, color=colors[:len(names)], edgecolor='black', linewidth=1.5)
    ax2.set_ylabel('Memory Usage (MB)', fontsize=12)
    ax2.set_title(f'Final Test Memory Usage ({final_test_size} reads)', fontsize=13, fontweight='bold')
    ax2.set_ylim(0, max(final_memories) * 1.15)
    for bar, val in zip(bars2, final_memories):
        ax2.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.005,
                f'{val:.4f} MB', ha='center', va='bottom', fontsize=11, fontweight='bold')
    
    plt.suptitle('Final Test Runtime and Memory Usage Comparison\nHISAT vs Bowtie2 vs Salmon', 
                 fontsize=14, fontweight='bold')
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'final_test_comparison.png'), dpi=150)
    plt.close()
    
    # =====================================================================
    # GRAPH 2: Combined algorithms comparison
    # =====================================================================
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))
    
    for i, tracker in enumerate(trackers):
        if len(tracker['measurements']) > 0:
            sizes = [m['input_size'] for m in tracker['measurements']]
            times = [m['runtime'] for m in tracker['measurements']]
            ax1.plot(sizes, times, '-o', label=tracker['algorithm'], 
                    color=colors[i % len(colors)], linewidth=2, markersize=6)
    
    # Add O(n) and O(n^2) reference lines
    all_sizes = []
    all_times = []
    for tracker in trackers:
        if len(tracker['measurements']) > 0:
            for m in tracker['measurements']:
                all_sizes.append(m['input_size'])
                all_times.append(m['runtime'])
    
    if all_sizes and all_times:
        x_min, x_max = min(all_sizes), max(all_sizes)
        x_range = [x_min, x_max]
        max_time = max(all_times)
        
        # Scale O(n) to end at max_time
        scale = max_time / x_max if x_max > 0 else 0.001
        y_on = [scale * x for x in x_range]
        ax1.plot(x_range, y_on, '--', color='green', alpha=0.6, linewidth=2, label='O(n)')
        
        # Scale O(n^2) to end at 2x max_time (steeper curve)
        scale_n2 = (max_time * 2) / (x_max * x_max) if x_max > 0 else 0.00001
        y_on2 = [scale_n2 * x * x for x in x_range]
        ax1.plot(x_range, y_on2, '--', color='red', alpha=0.6, linewidth=2, label='O(n²)')
    
    ax1.set_xlabel('Input Size (reads)')
    ax1.set_ylabel('Runtime (seconds)')
    ax1.set_title('Runtime Comparison')
    ax1.legend()
    ax1.grid(True, alpha=0.3)
    
    for i, tracker in enumerate(trackers):
        if len(tracker['measurements']) > 0:
            sizes = [m['input_size'] for m in tracker['measurements']]
            mems = [m['memory_mb'] for m in tracker['measurements']]
            ax2.plot(sizes, mems, '-o', label=tracker['algorithm'],
                    color=colors[i % len(colors)], linewidth=2, markersize=6)
    
    ax2.set_xlabel('Input Size (reads)')
    ax2.set_ylabel('Memory Usage (MB)')
    ax2.set_title('Memory Comparison')
    ax2.legend()
    ax2.grid(True, alpha=0.3)
    
    plt.suptitle('Comparison of Actual Run of Recreated Algorithm: HISAT vs Bowtie2 vs Salmon')
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'combined_algorithms_comparison.png'), dpi=150)
    plt.close()
    
    return ""
