# Scalability test
echo "Running scalability tests..."

# Create scalability results directory
mkdir -p scalability_results

# Define scalability test parameters - specific CPU core counts
declare -a thread_counts=(1 2 4 12 48 96 192)
declare -a test_graphs=(
  "africa_sym.bin"
  "europe_sym.bin"
  "twitter_sym.bin"
  "soc-LiveJournal1_sym.bin"
  "friendster_sym.bin"
  "clueweb_sym.bin"
  "GeoLifeNoScale_2_sym.bin"
  "hugetrace-00020_sym.bin"
)
declare graph_path="/data/graphs/links/"

# Run scalability tests for our KCore implementation
echo "Running scalability tests for our KCore implementation..."
cd ./../../
for graph in "${test_graphs[@]}"; do
    echo "Testing scalability on $graph..."
    graph_full_path="${graph_path}${graph}"
    
    # Store sequential time for speedup calculation
    sequential_time=""
    
    # Run scalability test with different thread counts
    for threads in "${thread_counts[@]}"; do
        echo "  Testing with $threads threads..."
        
        # Use taskset to control the number of cores across 4 sockets
        # For 4 sockets, cores are numbered: socket 0: 0,4,8,12..., socket 1: 1,5,9,13..., etc.
        if [ "$threads" -le 4 ]; then
            # For small core counts, use cores from first socket (0,4,8,12...)
            taskset_cmd="taskset -c 0"
            for ((i=1; i<threads; i++)); do
                taskset_cmd="$taskset_cmd,$((i*4))"
            done
        elif [ "$threads" -le 48 ]; then
            # For medium core counts, distribute across first 2 sockets
            cores_per_socket=$((threads / 2))
            taskset_cmd="taskset -c 0"
            for ((i=1; i<cores_per_socket; i++)); do
                taskset_cmd="$taskset_cmd,$((i*4))"
            done
            # Add cores from second socket (1,5,9,13...)
            taskset_cmd="$taskset_cmd,1"
            for ((i=1; i<threads-cores_per_socket; i++)); do
                taskset_cmd="$taskset_cmd,$((1+i*4))"
            done
        elif [ "$threads" -le 96 ]; then
            # For larger core counts, distribute across first 3 sockets
            cores_per_socket=$((threads / 3))
            taskset_cmd="taskset -c 0"
            for ((i=1; i<cores_per_socket; i++)); do
                taskset_cmd="$taskset_cmd,$((i*4))"
            done
            # Add cores from second socket (1,5,9,13...)
            taskset_cmd="$taskset_cmd,1"
            for ((i=1; i<cores_per_socket; i++)); do
                taskset_cmd="$taskset_cmd,$((1+i*4))"
            done
            # Add cores from third socket (2,6,10,14...)
            taskset_cmd="$taskset_cmd,2"
            for ((i=1; i<threads-2*cores_per_socket; i++)); do
                taskset_cmd="$taskset_cmd,$((2+i*4))"
            done
        else
            # For largest core counts, distribute across all 4 sockets
            cores_per_socket=$((threads / 4))
            taskset_cmd="taskset -c 0"
            for ((i=1; i<cores_per_socket; i++)); do
                taskset_cmd="$taskset_cmd,$((i*4))"
            done
            # Add cores from second socket (1,5,9,13...)
            taskset_cmd="$taskset_cmd,1"
            for ((i=1; i<cores_per_socket; i++)); do
                taskset_cmd="$taskset_cmd,$((1+i*4))"
            done
            # Add cores from third socket (2,6,10,14...)
            taskset_cmd="$taskset_cmd,2"
            for ((i=1; i<cores_per_socket; i++)); do
                taskset_cmd="$taskset_cmd,$((2+i*4))"
            done
            # Add cores from fourth socket (3,7,11,15...)
            taskset_cmd="$taskset_cmd,3"
            for ((i=1; i<threads-3*cores_per_socket; i++)); do
                taskset_cmd="$taskset_cmd,$((3+i*4))"
            done
        fi
        
        echo "    Core distribution: $taskset_cmd"
        
        # Run our KCore executable directly with all 3 techniques enabled
        # First, ensure the header file has the right configuration
        echo "    Updating KCore header for all optimizations enabled..."
        python3 -c "
import re
from pathlib import Path

header_file = Path('KCore/kcore.h')
with open(header_file, 'r') as f:
    content = f.read()

# Enable all optimizations
content = re.sub(
    r'static constexpr bool enable_sampling = \w+;',
    'static constexpr bool enable_sampling = true;',
    content
)
content = re.sub(
    r'static constexpr bool enable_local_queue = \w+;',
    'static constexpr bool enable_local_queue = true;',
    content
)

# Enable bucketing
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

with open(header_file, 'w') as f:
    f.write(content)

print('Header updated successfully')
"
        
        # Compile KCore with the updated configuration
        echo "    Compiling KCore..."
        if make -C KCore > /dev/null 2>&1; then
            echo "    ✓ Compilation successful"
            
            # Check if graph file exists
            if [ ! -f "$graph_full_path" ]; then
                echo "    ✗ Graph file not found: $graph_full_path"
                echo "NA" > "scalability_results/ours_${graph%.*}_${threads}threads.csv"
                continue
            fi
            
            # Check if KCore executable exists
            if [ ! -f "./KCore/kcore" ]; then
                echo "    ✗ KCore executable not found: ./KCore/kcore"
                echo "NA" > "scalability_results/ours_${graph%.*}_${threads}threads.csv"
                continue
            fi
            
            # Run KCore executable directly with taskset for distributed core allocation
            echo "    Running KCore on: $graph_full_path with $threads cores"
            echo "    Command: $taskset_cmd ./KCore/kcore -i \"$graph_full_path\""
            
            # Capture both stdout and stderr
            kcore_output=$($taskset_cmd ./KCore/kcore -i "$graph_full_path" 2>&1)
            kcore_exit_code=$?
            
            echo "    Exit code: $kcore_exit_code"
            echo "    Output: $kcore_output"
            
            if [ $kcore_exit_code -eq 0 ]; then
                # Extract average time from output (format: "Average time: X.XXXXX")
                execution_time=$(echo "$kcore_output" | grep -o "Average time: [0-9]\+\.[0-9]\+" | cut -d' ' -f3)
                
                if [ -n "$execution_time" ]; then
                    echo "    ✓ Execution time: $execution_time seconds"
                    echo "$execution_time" > "scalability_results/ours_${graph%.*}_${threads}threads.csv"
                else
                    echo "    ✗ Could not extract execution time from output"
                    echo "    Full output: $kcore_output"
                    echo "NA" > "scalability_results/ours_${graph%.*}_${threads}threads.csv"
                fi
            else
                echo "    ✗ Execution failed with exit code $kcore_exit_code"
                echo "    Error output: $kcore_output"
                echo "NA" > "scalability_results/ours_${graph%.*}_${threads}threads.csv"
            fi
        else
            echo "    ✗ Compilation failed"
            echo "NA" > "scalability_results/ours_${graph%.*}_${threads}threads.csv"
        fi
        
        # Store sequential time (1 thread) for speedup calculation
        if [ "$threads" -eq 1 ]; then
            if [ -f "scalability_results/ours_${graph%.*}_${threads}threads.csv" ]; then
                sequential_time=$(cat "scalability_results/ours_${graph%.*}_${threads}threads.csv" | tr -d '\n\r')
            fi
        fi
    done
    
    # Calculate speedup for each thread count
    echo "Calculating speedup for $graph..."
    graph_name="${graph%.*}"
    speedup_line="$graph_name"
    
    for threads in "${thread_counts[@]}"; do
        if [ -f "scalability_results/ours_${graph_name}_${threads}threads.csv" ]; then
            current_time=$(cat "scalability_results/ours_${graph_name}_${threads}threads.csv" | tr -d '\n\r')
            if [ "$current_time" != "NA" ] && [ -n "$sequential_time" ] && [ "$sequential_time" != "NA" ]; then
                # Calculate speedup: sequential_time / current_time
                speedup=$(echo "scale=6; $sequential_time / $current_time" | bc -l 2>/dev/null || echo "NA")
                speedup_line="$speedup_line $speedup"
            else
                speedup_line="$speedup_line NA"
            fi
        else
            speedup_line="$speedup_line NA"
        fi
    done
    
    # Save speedup results in the format like scale.txt
    echo "$speedup_line" > "scalability_results/ours_${graph_name}_speedup.txt"
done

# Combine all speedup results into one file (like scale.txt)
echo "Combining all speedup results..."

# Create combined speedup file
combined_speedup="scalability_results/scale.txt"
echo "# Graph Core1 Core2 Core4 Core12 Core48 Core96 Core192" > "$combined_speedup"

# Add our results
for graph in "${test_graphs[@]}"; do
    graph_name="${graph%.*}"
    if [ -f "scalability_results/ours_${graph_name}_speedup.txt" ]; then
        speedup_line=$(cat "scalability_results/ours_${graph_name}_speedup.txt")
        echo "$speedup_line" >> "$combined_speedup"
    fi
done

echo "Scalability test completed!"
echo "Results saved to: scalability_results/"
echo "Combined speedup results: scalability_results/scale.txt"
echo "Format: Graph Core1 Core2 Core4 Core12 Core48 Core96 Core192" 
