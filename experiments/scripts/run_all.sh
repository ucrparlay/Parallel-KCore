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

# Run OURS experiments
cd ./../../
echo "Running our KCore experiments on all graphs..."

# Combine all graphs into one array for our experiments
all_graphs_for_ours=()
for g in "${graph[@]}"; do
    all_graphs_for_ours+=("${graph_path}${g}")
done
for g in "${graph_syn[@]}"; do
    all_graphs_for_ours+=("${graph_path_syn}${g}")
done

# Run our experiments with all graphs
python3 batch_evaluate_all_configs.py "${all_graphs_for_ours[@]}" 
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

# Get all unique graph names from all three CSV files (normalized without extensions)
declare -A all_graphs

# Function to normalize graph name (remove .bin, .txt extensions)
normalize_graph_name() {
    local name="$1"
    echo "$name" | sed 's/\.bin$//' | sed 's/\.txt$//'
}

# Read from our results
if [ -f "batch_results_all_configs.csv" ]; then
    while IFS=',' read -r graph rest; do
        if [ "$graph" != "graph" ]; then  # Skip header
            normalized_name=$(normalize_graph_name "$graph")
            all_graphs["$normalized_name"]=1
        fi
    done < "batch_results_all_configs.csv"
fi

# Read from gbbs results
if [ -f "baselines/gbbs/benchmarks/KCore/JulienneDBS17/kcore.csv" ]; then
    while IFS=',' read -r graph rest; do
        if [ "$graph" != "graph_name" ]; then  # Skip header
            normalized_name=$(normalize_graph_name "$graph")
            all_graphs["$normalized_name"]=1
        fi
    done < "baselines/gbbs/benchmarks/KCore/JulienneDBS17/kcore.csv"
fi

# Read from PKC results
if [ -f "baselines/PKC/pkc_results.csv" ]; then
    while IFS=',' read -r graph rest; do
        if [ "$graph" != "graph_name" ]; then  # Skip header
            normalized_name=$(normalize_graph_name "$graph")
            all_graphs["$normalized_name"]=1
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
        # Try to find results with normalized name (without extensions)
        our_line=$(grep "^$graph," "batch_results_all_configs.csv" | head -1 | tr -d '\n\r')
        if [ -z "$our_line" ]; then
            # Try with .bin extension
            our_line=$(grep "^$graph.bin," "batch_results_all_configs.csv" | head -1 | tr -d '\n\r')
        fi
        if [ -z "$our_line" ]; then
            # Try with .txt extension
            our_line=$(grep "^$graph.txt," "batch_results_all_configs.csv" | head -1 | tr -d '\n\r')
        fi
        
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
        # Try to find results with normalized name (without extensions)
        gbbs_line=$(grep "^$graph," "baselines/gbbs/benchmarks/KCore/JulienneDBS17/kcore.csv" | head -1 | tr -d '\n\r')
        if [ -z "$gbbs_line" ]; then
            # Try with .bin extension
            gbbs_line=$(grep "^$graph.bin," "baselines/gbbs/benchmarks/KCore/JulienneDBS17/kcore.csv" | head -1 | tr -d '\n\r')
        fi
        if [ -z "$gbbs_line" ]; then
            # Try with .txt extension
            gbbs_line=$(grep "^$graph.txt," "baselines/gbbs/benchmarks/KCore/JulienneDBS17/kcore.csv" | head -1 | tr -d '\n\r')
        fi
        
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
        # Try to find results with normalized name (without extensions)
        pkc_line=$(grep "^$graph," "baselines/PKC/pkc_results.csv" | head -1 | tr -d '\n\r')
        if [ -z "$pkc_line" ]; then
            # Try with .bin extension
            pkc_line=$(grep "^$graph.bin," "baselines/PKC/pkc_results.csv" | head -1 | tr -d '\n\r')
        fi
        if [ -z "$pkc_line" ]; then
            # Try with .txt extension
            pkc_line=$(grep "^$graph.txt," "baselines/PKC/pkc_results.csv" | head -1 | tr -d '\n\r')
        fi
        
        if [ -n "$pkc_line" ]; then
            pkc_times=$(echo "$pkc_line" | cut -d',' -f2-)
            result_line="$result_line,$pkc_times"
        else
            result_line="$result_line,NA,NA"
        fi
    else
        result_line="$result_line,NA,NA"
    fi
    
    # Write to combined CSV (ensure no newlines in the data)
    clean_line=$(echo "$result_line" | tr -d '\n\r')
    echo "$clean_line" >> "$combined_csv"
done

# Clean up the final CSV file to remove any remaining newlines
echo "Cleaning up CSV file..."
temp_csv="${combined_csv}.tmp"
mv "$combined_csv" "$temp_csv"
cat "$temp_csv" | tr -d '\r' | sed 's/[[:space:]]*$//' > "$combined_csv"
rm "$temp_csv"

echo "Combined results saved to $combined_csv"
echo "Columns: graph_name, 8_ours_configs, gbbs_time, pkc_park_time, pkc_pkc_time"

