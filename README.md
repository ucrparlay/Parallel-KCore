# Parallel-KCore
SIGMOD'25: Parallel k-Core Decomposition: Theory and Practice

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

+ -s: indicate the input graph is symmetric (undirected). If not, the directed graph will be symmetrized without the `-s` parameter.
+ -i graph_path: the graph path (in .adj or .bin, see [GBBS graph format](https://paralg.github.io/gbbs/docs/formats))

For example, to run our algorithm on twitter
```bash
./kcore -s -i data/twitter_sym.bin
./kcore -i data/twitter.bin
```
or
```bash
./kcore -s -i data/twitter_sym.adj
./kcore -i data/twitter.adj
```
