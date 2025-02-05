# Parallel-KCore
SIGMOD'25: An efficient parallel algorithm and implementation for k-core decomposition

## Download
```bash
git clone git@github.com:ucrparlay/Parallel-KCore.git
```

## Requirements
+ CMake >= 3.15 
+ g++ or clang with C++17 features support (tested with g++ 12.1.1 and clang 14.0.6) on Linux machines.
+ We use [ParlayLib](https://github.com/cmuparlay/parlaylib) to support fork-join parallelism and some parallel primitives. It is provided as a submodule in our repository. 


## Compilation
```bash
cd KCore && make
```

## Running Code
```bash
./kcore [-s] [-i graph_path]
```

+ -s: make sure the input graph is symmetric (undirected). If not, the directed graph will be symmetrized)
+ -i graph_path: the graph path (in .adj or .bin, see [GBBS graph format](https://paralg.github.io/gbbs/docs/formats))

For example, to run our algorithm on twitter_sym.bin
```bash
./kcore -s -i data/twitter_sym.bin
```
or
```bash
./kcore -s -i data/twitter_sym.adj
```
