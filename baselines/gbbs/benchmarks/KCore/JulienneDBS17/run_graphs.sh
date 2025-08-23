#!/bin/bash

declare -a graph=(
  ## Social
  "soc-LiveJournal1_sym.bin"
  "com-orkut_sym.bin"
  "sinaweibo_sym.bin"
  "twitter_sym.bin"
  "friendster_sym.bin"

  ## Web
  "eu-2015-host_sym.bin"
  "sd_arc_sym.bin"
  "clueweb_sym.bin"
  "hyperlink2014_sym.bin"
  #"hyperlink2012_sym.bin"

  ## Road
  "africa_sym.bin"
  "north-america_sym.bin"
  "asia_sym.bin"  
  "europe_sym.bin"

  ## k-NN
  #"Household.lines_5_sym.bin"
  "CHEM_5_sym.bin"
  "GeoLifeNoScale_2_sym.bin"
  "GeoLifeNoScale_5_sym.bin"
  "GeoLifeNoScale_10_sym.bin"
  #"GeoLifeNoScale_15_sym.bin"
  #"GeoLifeNoScale_20_sym.bin"
  "Cosmo50_5_sym.bin"

  ## Synthetic
  #"grid_10000_10000_sym.bin"
  #"grid_1000_100000_sym.bin"
  #"grid_10000_10000_03_sym.bin"
  #"grid_1000_100000_03_sym.bin"
  #"chain_1e7_sym.bin"
  #"chain_1e8_sym.bin"
  "hugetrace-00020_sym.bin"
  "hugebubbles-00020_sym.bin"
)

declare -a graph_syn=(
  "2d.bin"
  "core.bin"
  "powerlaw.bin"
)

declare graph_path="/data/graphs/links/"
declare graph_path_syn="/colddata/yliu908/"

declare numactl="numactl -i all"

# cd ..
make

# Create CSV file with header
echo "graph_name,avg_running_time" > kcore.csv

for graph in "${graph[@]}"; do
  echo "Processing: ${graph_path}${graph}"
  
  # Check if graph file exists
  if [ ! -f "${graph_path}${graph}" ]; then
    echo "  ✗ Graph file not found, skipping..."
    graph_name=$(basename "$graph")
    echo "$graph_name,NA" >> kcore.csv
    echo "------------------------------------" >> kcore.txt
    continue
  fi
  
  # Run KCore multiple times and capture all output
  output=""
  success_count=0
  total_runs=3
  
  for i in {1..3}; do
    echo "  Run $i/3..."
    if run_output=$(${numactl} ./KCore -s -b ${graph_path}${graph} 2>&1); then
      output="$output$run_output"
      success_count=$((success_count + 1))
      echo "    ✓ Run $i successful"
    else
      echo "    ✗ Run $i failed"
      # Still capture output for debugging
      output="$output$run_output"
    fi
    echo "$run_output" >> kcore.txt
  done
  
  # Extract the average time from "time per iter: X.XXXXX" line
  avg_time=$(echo "$output" | grep -o "time per iter: [0-9.]*" | tail -1 | sed 's/time per iter: //')
  
  # Extract just the graph filename without path
  graph_name=$(basename "$graph")
  
  # Check if we got valid timing data
  if [ -n "$avg_time" ] && [ "$success_count" -gt 0 ]; then
    echo "  ✓ Success: $success_count/$total_runs runs, avg_time: $avg_time"
    echo "$graph_name,$avg_time" >> kcore.csv
  else
    echo "  ✗ Failed to get valid timing data, using NA"
    echo "$graph_name,NA" >> kcore.csv
  fi
  
  # Add separator to text file
  echo "------------------------------------" >> kcore.txt
done


for graph in "${graph_syn[@]}"; do
  echo "Processing: ${graph_path_syn}${graph}"
  
  # Check if graph file exists
  if [ ! -f "${graph_path_syn}${graph}" ]; then
    echo "  ✗ Graph file not found, skipping..."
    graph_name=$(basename "$graph")
    echo "$graph_name,NA" >> kcore.csv
    echo "------------------------------------" >> kcore.txt
    continue
  fi
  
  # Run KCore multiple times and capture all output
  output=""
  success_count=0
  total_runs=3
  
  for i in {1..3}; do
    echo "  Run $i/3..."
    if run_output=$(${numactl} ./KCore -s -b ${graph_path_syn}${graph} 2>&1); then
      output="$output$run_output"
      success_count=$((success_count + 1))
      echo "    ✓ Run $i successful"
    else
      echo "    ✗ Run $i failed"
      # Still capture output for debugging
      output="$output$run_output"
    fi
    echo "$run_output" >> kcore.txt
  done
  
  # Extract the average time from "time per iter: X.XXXXX" line
  avg_time=$(echo "$output" | grep -o "time per iter: [0-9.]*" | tail -1 | sed 's/time per iter: //')
  
  # Extract just the graph filename without path
  graph_name=$(basename "$graph")
  
  # Check if we got valid timing data
  if [ -n "$avg_time" ] && [ "$success_count" -gt 0 ]; then
    echo "  ✓ Success: $success_count/$total_runs runs, avg_time: $avg_time"
    echo "$graph_name,$avg_time" >> kcore.csv
  else
    echo "  ✗ Failed to get valid timing data, using NA"
    echo "$graph_name,NA" >> kcore.csv
  fi
  
  # Add separator to text file
  echo "------------------------------------" >> kcore.txt
done

echo "Results saved to kcore.csv"
