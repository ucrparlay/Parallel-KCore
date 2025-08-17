#!/usr/bin/env python3

import os
import subprocess
import csv
import re
from pathlib import Path

def run_kcore_on_graph(graph_path, kcore_executable):
    """Run KCore on a single graph and extract all timing information"""
    try:
        cmd = [str(kcore_executable), "-i", str(graph_path)]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
        
        if result.returncode != 0:
            print(f"  ✗ Execution failed: {result.stderr}")
            return None
        
        # Extract all timing information from stdout
        output = result.stdout
        timing_data = {}
        
        # Extract warmup round
        warmup_match = re.search(r'Warmup Round: ([\d.]+)', output)
        if warmup_match:
            timing_data['warmup_time'] = float(warmup_match.group(1))
        
        # Extract individual rounds
        for i in range(1, 6):  # NUM_ROUND = 5
            round_match = re.search(rf'Round {i}: ([\d.]+)', output)
            if round_match:
                timing_data[f'round_{i}_time'] = float(round_match.group(1))
        
        # Extract average time
        avg_match = re.search(r'Average time: ([\d.]+)', output)
        if avg_match:
            timing_data['avg_time'] = float(avg_match.group(1))
        
        if not timing_data:
            print(f"  ✗ Could not extract timing information from output")
            return None
            
        return timing_data
            
    except subprocess.TimeoutExpired:
        print(f"  ✗ Execution timed out (>600s)")
        return None
    except Exception as e:
        print(f"  ✗ Execution error: {e}")
        return None

def batch_evaluate_graphs(graph_paths, kcore_executable, output_csv="batch_results.csv"):
    """Run KCore on multiple graphs and save results to CSV"""
    
    # Check if executable exists
    if not kcore_executable.exists():
        print(f"Error: KCore executable not found at {kcore_executable}")
        print("Please compile first: cd KCore && make")
        return
    
    results = []
    
    print(f"Running KCore on {len(graph_paths)} graphs...")
    print(f"Executable: {kcore_executable}")
    print("-" * 60)
    
    for i, graph_path in enumerate(graph_paths, 1):
        graph_name = Path(graph_path).stem
        print(f"[{i}/{len(graph_paths)}] {graph_name}")
        
        timing_data = run_kcore_on_graph(graph_path, kcore_executable)
        
        if timing_data is not None:
            result = {
                'graph': graph_name,
                'avg_time': timing_data.get('avg_time', 'N/A')
            }
            results.append(result)
            
            # Print summary of this run
            if 'avg_time' in timing_data:
                print(f"  ✓ Average time: {timing_data['avg_time']:.6f} seconds")
            if 'warmup_time' in timing_data:
                print(f"    Warmup: {timing_data['warmup_time']:.6f}s")
            round_times = [f"R{i}: {timing_data.get(f'round_{i}_time', 'N/A'):.6f}s" 
                          for i in range(1, 6) if f'round_{i}_time' in timing_data]
            if round_times:
                print(f"    Rounds: {', '.join(round_times)}")
        else:
            print(f"  ✗ Failed to get timing")
    
    # Save results to CSV
    if results:
        # Only include essential fields: graph name and average time
        fieldnames = ['graph', 'avg_time']
        
        with open(output_csv, 'w', newline='') as csvfile:
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(results)
        
        print("-" * 60)
        print(f"✓ Results saved to {output_csv}")
        
        # Print summary table
        print("\nSUMMARY:")
        print(f"{'Graph':<25} {'Avg Time':<12} {'Warmup':<12} {'Round 1-5 Times':<30}")
        print("-" * 80)
        for result in results:
            avg_time = result.get('avg_time', 'N/A')
            # warmup_time = result.get('warmup_time', 'N/A')
            # round_times = [str(result.get(f'round_{i}_time', 'N/A'))[:6] for i in range(1, 6)]
            # rounds_str = ', '.join(round_times)
            
            # print(f"{result['graph'][:24]:<25} {avg_time:<12.6f} {warmup_time:<12.6f} {rounds_str:<30}")
        
        if len(results) < len(graph_paths):
            print(f"\nNote: {len(graph_paths) - len(results)} graphs failed to run")
    else:
        print("No successful runs to save!")

def main():
    import argparse
    parser = argparse.ArgumentParser(description='Batch evaluate KCore on multiple graphs')
    parser.add_argument('graphs', nargs='+', help='Graph files to test')
    parser.add_argument('--output', '-o', default='batch_results.csv', 
                       help='Output CSV file (default: batch_results.csv)')
    parser.add_argument('--executable', '-e', default='KCore/kcore',
                       help='Path to KCore executable (default: KCore/kcore)')
    
    args = parser.parse_args()
    
    # Convert to absolute paths
    kcore_executable = Path(args.executable).resolve()
    
    # Validate graph files
    valid_graphs = []
    for graph_file in args.graphs:
        graph_path = Path(graph_file)
        if graph_path.exists():
            valid_graphs.append(graph_path.resolve())
        else:
            print(f"Warning: Graph file '{graph_file}' not found, skipping...")
    
    if not valid_graphs:
        print("Error: No valid graph files provided!")
        print("Usage: python batch_evaluate.py graph1.txt graph2.txt ...")
        return 1
    
    print(f"Found {len(valid_graphs)} valid graph files:")
    for graph in valid_graphs:
        print(f"  {graph}")
    print()
    
    # Run batch evaluation
    batch_evaluate_graphs(valid_graphs, kcore_executable, args.output)
    return 0

if __name__ == "__main__":
    exit(main())