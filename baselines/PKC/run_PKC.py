#!python3
import os
import subprocess

graphs = [
    # Social
    "soc-LiveJournal1_sym.bin.txt",
    "com-orkut_sym.bin.txt",
    "sinaweibo_sym.bin.txt",
    "twitter_sym.bin.txt",
    "friendster_sym.bin.txt",

    # Web
    "enwiki-2023_sym.bin.txt",
    "eu-2015-host_sym.bin.txt",
    "sd_arc_sym.bin.txt",
    "clueweb_sym.bin.txt",
    "hyperlink2014_sym.bin.txt",
    "hyperlink2012_sym.txt",

    #Road
    "africa_sym.bin.txt",
    "north-america_sym.bin.txt",
    "asia_sym.bin.txt",
    "europe_sym.bin.txt",
    # "RoadUSA_sym.bin.txt",

    # k-NN
    "CHEM_5_sym.bin.txt",
    "GeoLifeNoScale_5_sym.bin.txt",
    "GeoLifeNoScale_10_sym.bin.txt",
    "Cosmo50_5_sym.bin.txt",

    # Synthetic
    "hugetrace-00020_sym.bin.txt",
    "hugebubbles-00020_sym.bin.txt",
    "2d.txt",
    "3d.txt",
    "core.txt",
    "powerlaw.txt"
]

numactl = "numactl -i all"
graph_dir = "/colddata/yliu908/edgelist/"


# Create CSV file with header
csv_file = "pkc_results.csv"
with open(csv_file, 'w') as f:
    f.write("graph_name,ParK_time,PKC_time\n")

for graph in graphs:
    print(f"Processing: {graph}")
    
    # Check if graph file exists
    graph_path_full = os.path.join(graph_dir, graph)
    if not os.path.exists(graph_path_full):
        print(f"  ✗ Graph file not found: {graph_path_full}")
        # Extract graph name and write NA to CSV
        graph_name = graph.replace(".txt", "").replace(".bin", "")
        with open(csv_file, 'a') as f:
            f.write(f"{graph_name},NA,NA\n")
        continue
    
    # Check if executable exists
    if not os.path.exists("./pkc.exe"):
        print(f"  ✗ Executable not found: ./pkc.exe")
        # Write NA to CSV for this graph
        graph_name = graph.replace(".txt", "").replace(".bin", "")
        with open(csv_file, 'a') as f:
            f.write(f"{graph_name},NA,NA\n")
        continue
    
    flags = " " + graph_dir + graph  
    cmd = " ./pkc.exe " + flags + " 2>&1"  # Capture both stdout and stderr
    print(f"  Running: {cmd}")
    
    try:
        # Run the command and capture output
        result = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True, timeout=1200)  # 2 minute timeout
        
        # Extract CSV output line
        output_lines = result.stdout.split('\n')
        csv_line = None
        for line in output_lines:
            if line.startswith("CSV_OUTPUT:"):
                csv_line = line.replace("CSV_OUTPUT: ", "")
                break
        
        if csv_line and result.returncode == 0:
            # Parse the CSV line to extract individual values
            parts = csv_line.split(',')
            if len(parts) == 3:  # Should have: graph_path, ParK:time, PKC:time
                # Extract just the graph filename without path
                graph_path = parts[0]
                graph_name = os.path.basename(graph_path).replace(".txt", "").replace(".bin", "")
                
                # Extract timing values (remove the "ParK:", "PKC:" prefixes)
                park_time = parts[1].replace("ParK:", "")
                pkc_time = parts[2].replace("PKC:", "")
                
                # Write properly formatted CSV line
                csv_output = f"{graph_name},{park_time},{pkc_time}"
                with open(csv_file, 'a') as f:
                    f.write(csv_output + "\n")
                
                print(f"  ✓ Results saved for {graph_name}: ParK={park_time}s, PKC={pkc_time}s")
            else:
                print(f"  ✗ Invalid CSV format for {graph}: {csv_line}")
                # Write NA to CSV for this graph
                graph_name = graph.replace(".txt", "").replace(".bin", "")
                with open(csv_file, 'a') as f:
                    f.write(f"{graph_name},NA,NA\n")
        else:
            print(f"  ✗ No CSV output found or execution failed for {graph}")
            # Write NA to CSV for this graph
            graph_name = graph.replace(".txt", "").replace(".bin", "")
            with open(csv_file, 'a') as f:
                f.write(f"{graph_name},NA,NA\n")
        
        # Save full log for debugging
        with open(graph + ".log", 'w') as f:
            f.write(f"Return code: {result.returncode}\n")
            f.write(f"STDOUT:\n{result.stdout}\n")
            f.write(f"STDERR:\n{result.stderr}\n")
            
    except subprocess.TimeoutExpired:
        print(f"  ✗ Execution timed out (>20 minutes) for {graph}")
        # Write NA to CSV for this graph
        graph_name = graph.replace(".txt", "").replace(".bin", "")
        with open(csv_file, 'a') as f:
            f.write(f"{graph_name},NA,NA\n")
        
        # Save timeout log
        with open(graph + ".log", 'w') as f:
            f.write("Execution timed out after 20 minutes\n")
            
    except Exception as e:
        print(f"  ✗ Unexpected error for {graph}: {e}")
        # Write NA to CSV for this graph
        graph_name = graph.replace(".txt", "").replace(".bin", "")
        with open(csv_file, 'a') as f:
            f.write(f"{graph_name},NA,NA\n")
        
        # Save error log
        with open(graph + ".log", 'w') as f:
            f.write(f"Unexpected error: {e}\n")

print(f"\nAll results saved to {csv_file}")

# recompile with replace 
