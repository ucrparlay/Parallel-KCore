#!/bin/bash

# Run OURS experiments
cd ./../../
python3 batch_evaluate_all_configs.py

# Run gbbs experiments
cd baselines/gbbs/benchmarks/KCore/JulienneDBS17
bash run_graphs.sh

# Run PKC and ParK
cd ./../../../../PKC
python3 run_PKC.py

# Combine all CSV results into one comprehensive file
cd ./../../
echo "Combining CSV results..."

# Create combined CSV with header
combined_csv="combined_results.csv"
echo "graph_name,ours_sampling_on_local_on_bucket_on,ours_sampling_on_local_on_bucket_off,ours_sampling_on_local_off_bucket_on,ours_sampling_on_local_off_bucket_off,ours_sampling_off_local_on_bucket_on,ours_sampling_off_local_on_bucket_off,ours_sampling_off_local_off_bucket_on,ours_sampling_off_local_off_bucket_off,gbbs_time,pkc_park_time,pkc_pkc_time" > "$combined_csv"

# Get all unique graph names from all three CSV files
declare -A all_graphs

# Read from our results
if [ -f "batch_results_all_configs.csv" ]; then
    while IFS=',' read -r graph rest; do
        if [ "$graph" != "graph" ]; then  # Skip header
            all_graphs["$graph"]=1
        fi
    done < "batch_results_all_configs.csv"
fi

# Read from gbbs results
if [ -f "baselines/gbbs/benchmarks/KCore/JulienneDBS17/kcore.csv" ]; then
    while IFS=',' read -r graph rest; do
        if [ "$graph" != "graph_name" ]; then  # Skip header
            all_graphs["$graph"]=1
        fi
    done < "baselines/gbbs/benchmarks/KCore/JulienneDBS17/kcore.csv"
fi

# Read from PKC results
if [ -f "baselines/PKC/pkc_results.csv" ]; then
    while IFS=',' read -r graph rest; do
        if [ "$graph" != "graph_name" ]; then  # Skip header
            all_graphs["$graph"]=1
        fi
    done < "baselines/PKC/pkc_results.csv"
fi

# Process each graph and combine results
for graph in "${!all_graphs[@]}"; do
    echo "Processing graph: $graph"
    
    # Initialize result line with graph name
    result_line="$graph"
    
    # Add our results (8 columns)
    if [ -f "batch_results_all_configs.csv" ]; then
        our_line=$(grep "^$graph," "batch_results_all_configs.csv" | head -1)
        if [ -n "$our_line" ]; then
            # Extract the 8 timing values (skip graph name)
            our_times=$(echo "$our_line" | cut -d',' -f2-)
            result_line="$result_line,$our_times"
        else
            # Add 8 "NA" values for missing our results
            result_line="$result_line,NA,NA,NA,NA,NA,NA,NA,NA"
        fi
    else
        # Add 8 "NA" values if file doesn't exist
        result_line="$result_line,NA,NA,NA,NA,NA,NA,NA,NA"
    fi
    
    # Add gbbs results
    if [ -f "baselines/gbbs/benchmarks/KCore/JulienneDBS17/kcore.csv" ]; then
        gbbs_line=$(grep "^$graph," "baselines/gbbs/benchmarks/KCore/JulienneDBS17/kcore.csv" | head -1)
        if [ -n "$gbbs_line" ]; then
            gbbs_time=$(echo "$gbbs_line" | cut -d',' -f2)
            result_line="$result_line,$gbbs_time"
        else
            result_line="$result_line,NA"
        fi
    else
        result_line="$result_line,NA"
    fi
    
    # Add PKC results (2 columns: ParK and PKC)
    if [ -f "baselines/PKC/pkc_results.csv" ]; then
        pkc_line=$(grep "^$graph," "baselines/PKC/pkc_results.csv" | head -1)
        if [ -n "$pkc_line" ]; then
            pkc_times=$(echo "$pkc_line" | cut -d',' -f2-)
            result_line="$result_line,$pkc_times"
        else
            result_line="$result_line,NA,NA"
        fi
    else
        result_line="$result_line,NA,NA"
    fi
    
    # Write to combined CSV
    echo "$result_line" >> "$combined_csv"
done

echo "Combined results saved to $combined_csv"
echo "Columns: graph_name, 8_ours_configs, gbbs_time, pkc_park_time, pkc_pkc_time"