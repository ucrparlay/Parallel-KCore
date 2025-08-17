#!/usr/bin/env python3

import os
import subprocess
import csv
import re
from pathlib import Path

def modify_kcore_header(enable_sampling, enable_local_queue, enable_bucketing):
    """Modify kcore.h with the specified parameter values"""
    header_file = Path("KCore/kcore.h")
    
    # Read the current header file
    with open(header_file, 'r') as f:
        content = f.read()
    
    # Replace the parameter values
    content = re.sub(
        r'static constexpr bool enable_sampling = \w+;',
        f'static constexpr bool enable_sampling = {str(enable_sampling).lower()};',
        content
    )
    content = re.sub(
        r'static constexpr bool enable_local_queue = \w+;',
        f'static constexpr bool enable_local_queue = {str(enable_local_queue).lower()};',
        content
    )
    
    # Replace bucketing-related parameters
    if enable_bucketing:
        # Enable bucketing: log2_single_buckets=3, num_intermediate_buckets=6, bucketing_pt=16
        content = re.sub(
            r'static constexpr uint32_t log2_single_buckets = \d+;',
            'static constexpr uint32_t log2_single_buckets = 3;',
            content
        )
        content = re.sub(
            r'static constexpr uint32_t num_intermediate_buckets = \d+;',
            'static constexpr uint32_t num_intermediate_buckets = 6;',
            content
        )
        content = re.sub(
            r'size_t bucketing_pt = \d+;',
            'size_t bucketing_pt = 16;',
            content
        )
    else:
        # Disable bucketing: log2_single_buckets=4, num_intermediate_buckets=0, bucketing_pt=1
        content = re.sub(
            r'static constexpr uint32_t log2_single_buckets = \d+;',
            'static constexpr uint32_t log2_single_buckets = 4;',
            content
        )
        content = re.sub(
            r'static constexpr uint32_t num_intermediate_buckets = \d+;',
            'static constexpr uint32_t num_intermediate_buckets = 0;',
            content
        )
        content = re.sub(
            r'size_t bucketing_pt = \d+;',
            'size_t bucketing_pt = 1;',
            content
        )
    
    # Write back to the header file
    with open(header_file, 'w') as f:
        f.write(content)

def compile_kcore():
    """Compile the KCore executable"""
    try:
        result = subprocess.run(
            ["make", "-C", "KCore"],
            capture_output=True,
            text=True,
            timeout=120
        )
        
        if result.returncode != 0:
            print(f"  ✗ Compilation failed: {result.stderr}")
            return False
        
        print("  ✓ Compilation successful")
        return True
        
    except subprocess.TimeoutExpired:
        print("  ✗ Compilation timed out (>120s)")
        return False
    except Exception as e:
        print(f"  ✗ Compilation error: {e}")
        return False

def run_kcore_on_graph(graph_path, kcore_executable):
    """Run KCore on a single graph and extract average timing information"""
    try:
        cmd = [str(kcore_executable), "-i", str(graph_path)]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
        
        if result.returncode != 0:
            print(f"  ✗ Execution failed: {result.stderr}")
            return None
        
        # Extract average time from stdout
        output = result.stdout
        avg_match = re.search(r'Average time: ([\d.]+)', output)
        
        if avg_match:
            return float(avg_match.group(1))
        else:
            print(f"  ✗ Could not extract average time from output")
            return None
            
    except subprocess.TimeoutExpired:
        print(f"  ✗ Execution timed out (>600s)")
        return None
    except Exception as e:
        print(f"  ✗ Execution error: {e}")
        return None

def batch_evaluate_all_configs(graph_paths, output_csv="batch_results_all_configs.csv"):
    """Run KCore on multiple graphs with all 4 parameter combinations"""
    
    # Check if KCore directory exists
    if not Path("KCore").exists():
        print("Error: KCore directory not found!")
        return
    
    # Check if Makefile exists
    if not Path("KCore/Makefile").exists():
        print("Error: KCore/Makefile not found!")
        return
    
    # Define all 8 configurations (2×2×2)
    configs = [
        (True, True, True),     # enable_sampling=True, enable_local_queue=True, enable_bucketing=True
        (True, True, False),    # enable_sampling=True, enable_local_queue=True, enable_bucketing=False
        (True, False, True),    # enable_sampling=True, enable_local_queue=False, enable_bucketing=True
        (True, False, False),   # enable_sampling=True, enable_local_queue=False, enable_bucketing=False
        (False, True, True),    # enable_sampling=False, enable_local_queue=True, enable_bucketing=True
        (False, True, False),   # enable_sampling=False, enable_local_queue=True, enable_bucketing=False
        (False, False, True),   # enable_sampling=False, enable_local_queue=False, enable_bucketing=True
        (False, False, False),  # enable_sampling=False, enable_local_queue=False, enable_bucketing=False
    ]
    
    config_names = [
        "sampling_on_local_on_bucket_on",
        "sampling_on_local_on_bucket_off",
        "sampling_on_local_off_bucket_on",
        "sampling_on_local_off_bucket_off",
        "sampling_off_local_on_bucket_on",
        "sampling_off_local_on_bucket_off",
        "sampling_off_local_off_bucket_on",
        "sampling_off_local_off_bucket_off"
    ]
    
    results = []
    
    print(f"Running KCore on {len(graph_paths)} graphs with all 8 configurations...")
    print("=" * 80)
    
    for i, graph_path in enumerate(graph_paths, 1):
        graph_name = Path(graph_path).stem
        print(f"\n[{i}/{len(graph_paths)}] {graph_name}")
        print("-" * 60)
        
        for j, (enable_sampling, enable_local_queue, enable_bucketing) in enumerate(configs, 1):
            config_name = config_names[j-1]
            print(f"  Config {j}/8: {config_name}")
            print(f"    enable_sampling={enable_sampling}, enable_local_queue={enable_local_queue}, enable_bucketing={enable_bucketing}")
            
            # Modify the header file
            modify_kcore_header(enable_sampling, enable_local_queue, enable_bucketing)
            
            # Compile with new parameters
            if not compile_kcore():
                print(f"    ✗ Skipping this configuration due to compilation failure")
                continue
            
            # Run KCore
            kcore_executable = Path("KCore/kcore")
            avg_time = run_kcore_on_graph(graph_path, kcore_executable)
            
            if avg_time is not None:
                result = {
                    'graph': graph_name,
                    'config': config_name,
                    'enable_sampling': enable_sampling,
                    'enable_local_queue': enable_local_queue,
                    'enable_bucketing': enable_bucketing,
                    'avg_time': avg_time
                }
                results.append(result)
                print(f"    ✓ Average time: {avg_time:.6f} seconds")
            else:
                print(f"    ✗ Failed to get timing")
    
    # Save results to CSV with restructured format
    if results:
        # Group results by graph
        graph_results = {}
        for result in results:
            graph_name = result['graph']
            config_name = result['config']
            if graph_name not in graph_results:
                graph_results[graph_name] = {}
            graph_results[graph_name][config_name] = result['avg_time']
        
        # Create CSV with graph as rows and configs as columns
        fieldnames = ['graph'] + config_names
        
        with open(output_csv, 'w', newline='') as csvfile:
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            
            for graph_name in sorted(graph_results.keys()):
                row = {'graph': graph_name}
                for config_name in config_names:
                    row[config_name] = graph_results[graph_name].get(config_name, 'N/A')
                writer.writerow(row)
        
        print("\n" + "=" * 80)
        print(f"✓ Results saved to {output_csv}")
        
        # Print summary table
        print("\nSUMMARY:")
        header = f"{'Graph':<25}"
        for config_name in config_names:
            header += f" {config_name:<15}"
        print(header)
        print("-" * (25 + 15 * len(config_names)))
        
        for graph_name in sorted(graph_results.keys()):
            row = f"{graph_name[:24]:<25}"
            for config_name in config_names:
                time_val = graph_results[graph_name].get(config_name, 'N/A')
                if isinstance(time_val, (int, float)):
                    row += f" {time_val:<15.6f}"
                else:
                    row += f" {time_val:<15}"
            print(row)
        
        # Print configuration comparison for each graph
        print("\nCONFIGURATION COMPARISON:")
        print("=" * 70)
        for graph_name in sorted(graph_results.keys()):
            print(f"\n{graph_name}:")
            # Sort configs by time (excluding N/A values)
            valid_configs = [(config_name, time_val) for config_name, time_val in graph_results[graph_name].items() 
                           if isinstance(time_val, (int, float))]
            valid_configs.sort(key=lambda x: x[1])
            
            for config_name, time_val in valid_configs:
                print(f"  {config_name:<25}: {time_val:.6f}s")
    else:
        print("No successful runs to save!")

def main():
    import argparse
    parser = argparse.ArgumentParser(description='Batch evaluate KCore on multiple graphs with all parameter combinations')
    parser.add_argument('graphs', nargs='+', help='Graph files to test')
    parser.add_argument('--output', '-o', default='batch_results_all_configs.csv', 
                       help='Output CSV file (default: batch_results_all_configs.csv)')
    
    args = parser.parse_args()
    
    # Convert to absolute paths
    valid_graphs = []
    for graph_file in args.graphs:
        graph_path = Path(graph_file)
        if graph_path.exists():
            valid_graphs.append(graph_path.resolve())
        else:
            print(f"Warning: Graph file '{graph_file}' not found, skipping...")
    
    if not valid_graphs:
        print("Error: No valid graph files provided!")
        print("Usage: python batch_evaluate_all_configs.py graph1.txt graph2.txt ...")
        return 1
    
    print(f"Found {len(valid_graphs)} valid graph files:")
    for graph in valid_graphs:
        print(f"  {graph}")
    print()
    
    # Run batch evaluation with all configurations
    batch_evaluate_all_configs(valid_graphs, args.output)
    return 0

if __name__ == "__main__":
    exit(main())
