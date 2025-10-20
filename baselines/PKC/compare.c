#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <assert.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>
#include <omp.h>

typedef uint64_t vid_t;
typedef uint64_t eid_t;

typedef struct {
  vid_t n;
  eid_t m;
  eid_t *num_edges;
  vid_t *adj;
} graph_t;

int vid_compare(const void *a, const void *b) {
  vid_t va = *(const vid_t *)a;
  vid_t vb = *(const vid_t *)b;
  return (va > vb) - (va < vb);
}

int load_graph_from_binary(char *filename, graph_t *g) {
  printf("Opening file: %s\n", filename);
  int fd = open(filename, O_RDONLY);
  if (fd == -1) {
    fprintf(stderr, "Error: could not open input file: %s.\n Exiting ...\n", filename);
    return -1;
  }

  struct stat sb;
  if (fstat(fd, &sb) == -1) {
    fprintf(stderr, "Error: unable to acquire file stat\n");
    close(fd);
    return -1;
  }

  printf("Mapping file into memory\n");
  char *data = (char *)mmap(0, sb.st_size, PROT_READ, MAP_PRIVATE, fd, 0);
  if (data == MAP_FAILED) {
    fprintf(stderr, "Error: mmap failed\n");
    close(fd);
    return -1;
  }

  size_t len = sb.st_size;
  printf("File size: %zu bytes\n", len);

  g->n = ((uint64_t *)data)[0];
  g->m = ((uint64_t *)data)[1];
  size_t sizes = ((uint64_t *)data)[2];
  printf("n: %lu, m: %lu, sizes: %lu\n", g->n, g->m, sizes);
  assert(sizes == (g->n + 1) * 8 + g->m * 4 + 3 * 8);

  printf("Allocating memory for num_edges\n");
  g->num_edges = (eid_t *)malloc((g->n + 1) * sizeof(eid_t));
  if (!g->num_edges) {
    fprintf(stderr, "Error: could not allocate memory for num_edges\n");
    munmap(data, len);
    close(fd);
    return -1;
  }

  for (long i = 0; i < g->n + 1; i++) {
    g->num_edges[i] = 0;
  }

  printf("Allocating memory for offsets\n");
  eid_t *offsets = (eid_t *)malloc((g->n + 1) * sizeof(eid_t));
  if (!offsets) {
    fprintf(stderr, "Error: could not allocate memory for offsets\n");
    free(g->num_edges);
    munmap(data, len);
    close(fd);
    return -1;
  }

  printf("Reading offsets from data\n");
  for (size_t i = 0; i < g->n + 1; i++) {
    offsets[i] = ((uint64_t *)(data + 3 * sizeof(uint64_t)))[i];
  }

  printf("Calculating num_edges for each vertex\n");
  for (long i = 0; i < g->n; i++) {
    g->num_edges[i] = offsets[i + 1] - offsets[i];
  }

  printf("Allocating memory for temp_num_edges\n");
  eid_t *temp_num_edges = (eid_t *)malloc((g->n + 1) * sizeof(eid_t));
  if (!temp_num_edges) {
    fprintf(stderr, "Error: could not allocate memory for temp_num_edges\n");
    free(g->num_edges);
    free(offsets);
    munmap(data, len);
    close(fd);
    return -1;
  }

  temp_num_edges[0] = 0;

  for (long i = 0; i < g->n; i++) {
    temp_num_edges[i + 1] = temp_num_edges[i] + g->num_edges[i];
  }

  printf("Allocating memory for adj\n");
  g->adj = (vid_t *)malloc(g->m * sizeof(vid_t));
  if (!g->adj) {
    fprintf(stderr, "Error: could not allocate memory for adj\n");
    free(g->num_edges);
    free(offsets);
    free(temp_num_edges);
    munmap(data, len);
    close(fd);
    return -1;
  }

  printf("Allocating memory for current_pos\n");
  eid_t *current_pos = (eid_t *)malloc((g->n + 1) * sizeof(eid_t));
  if (!current_pos) {
    fprintf(stderr, "Error: could not allocate memory for current_pos\n");
    free(g->num_edges);
    free(offsets);
    free(temp_num_edges);
    free(g->adj);
    munmap(data, len);
    close(fd);
    return -1;
  }

  for (long i = 0; i <= g->n; i++) {
    current_pos[i] = temp_num_edges[i];
  }

  printf("Reading edges from data\n");
  vid_t *edges = (vid_t *)(data + 3 * sizeof(uint64_t) + (g->n + 1) * sizeof(eid_t));

  for (long i = 0; i < g->n; i++) {
    for (eid_t j = offsets[i]; j < offsets[i + 1]; j++) {
      if (current_pos[i] >= g->m) {
        fprintf(stderr, "Error: current_pos[%ld] exceeds g->m\n", i);
        free(g->num_edges);
        free(offsets);
        free(temp_num_edges);
        free(g->adj);
        free(current_pos);
        munmap(data, len);
        close(fd);
        return -1;
      }
      g->adj[current_pos[i]++] = edges[j];
    }
  }

  printf("Start sorting\n");
  for (long i = 0; i < g->n; i++) {
    qsort(g->adj + temp_num_edges[i], g->num_edges[i], sizeof(vid_t), vid_compare);
  }
  printf("Done sorting\n");

  if (munmap(data, len) == -1) {
    fprintf(stderr, "Error: munmap failed\n");
    free(g->num_edges);
    free(g->adj);
    free(temp_num_edges);
    free(offsets);
    free(current_pos);
    close(fd);
    return -1;
  }

  close(fd);
  free(temp_num_edges);
  free(offsets);
  free(current_pos);
  return 0;
}

int load_graph_from_file(char *filename, graph_t *g) {
  FILE *infp = fopen(filename, "r");
  if (infp == NULL) {
    fprintf(stderr, "Error: could not open input file: %s.\n Exiting ...\n", filename);
    exit(1);
  }

  fprintf(stdout, "Reading input file: %s\n", filename);

  double t0 = omp_get_wtime();

  fscanf(infp, "%lu %lu\n", &(g->n), &(g->m));
  printf("N: %lu, M: %lu \n", g->n, g->m);

  long m = 0;

  g->num_edges = (eid_t *)malloc((g->n + 1) * sizeof(eid_t));
  assert(g->num_edges != NULL);

#pragma omp parallel for
  for (long i = 0; i < g->n + 1; i++) {
    g->num_edges[i] = 0;
  }

  vid_t u, v;
  while (fscanf(infp, "%lu %lu\n", &u, &v) != EOF) {
    m++;
    g->num_edges[u]++;
    g->num_edges[v]++;
  }

  fclose(infp);

  if (m != g->m) {
    printf("Reading error: file does not contain %lu edges.\n", g->m);
    free(g->num_edges);
    exit(1);
  }

  m = 0;

  eid_t *temp_num_edges = (eid_t *)malloc((g->n + 1) * sizeof(eid_t));
  assert(temp_num_edges != NULL);

  temp_num_edges[0] = 0;

  for (long i = 0; i < g->n; i++) {
    temp_num_edges[i + 1] = temp_num_edges[i] + g->num_edges[i];
  }

  g->adj = (vid_t *)malloc(2 * g->m * sizeof(vid_t));
  assert(g->adj != NULL);

#pragma omp parallel
  {
#pragma omp for schedule(static)
    for (long i = 0; i < g->n + 1; i++) g->num_edges[i] = temp_num_edges[i];
  }

  infp = fopen(filename, "r");
  if (infp == NULL) {
    fprintf(stderr, "Error: could not open input file: %s.\n Exiting ...\n", filename);
    exit(1);
  }

  fscanf(infp, "%lu %lu\n", &(g->n), &(g->m));

  while (fscanf(infp, "%lu %lu\n", &u, &v) != EOF) {
    g->adj[temp_num_edges[u]] = v;
    temp_num_edges[u]++;
    g->adj[temp_num_edges[v]] = u;
    temp_num_edges[v]++;
  }

  fclose(infp);

  for (long i = 0; i < g->n; i++) {
    qsort(g->adj + g->num_edges[i], g->num_edges[i + 1] - g->num_edges[i], sizeof(vid_t), vid_compare);
  }

  fprintf(stdout, "Reading input file took time: %.2lf sec \n", omp_get_wtime() - t0);
  free(temp_num_edges);
  return 0;
}

int compare_graphs(graph_t *g1, graph_t *g2) {
  if (g1->n != g2->n || g1->m != g2->m) {
    printf("Graphs have different sizes: g1(n=%lu, m=%lu), g2(n=%lu, m=%lu)\n",
           g1->n, g1->m, g2->n, g2->m);
    return -1;
  }

  for (vid_t i = 0; i < g1->n; i++) {
    if (g1->num_edges[i] != g2->num_edges[i]) {
      printf("Vertex %lu has different number of edges: g1=%lu, g2=%lu\n",
             i, g1->num_edges[i], g2->num_edges[i]);
      return -1;
    }

    for (eid_t j = g1->num_edges[i]; j < g1->num_edges[i + 1]; j++) {
      if (g1->adj[j] != g2->adj[j]) {
        printf("Different edge at vertex %lu: g1=%lu, g2=%lu\n",
               i, g1->adj[j], g2->adj[j]);
        return -1;
      }
    }
  }

  return 0;
}

void print_graph(graph_t *g) {
  for (vid_t i = 0; i < g->n; i++) {
    printf("Vertex %lu: ", i);
    for (eid_t j = g->num_edges[i]; j < g->num_edges[i + 1]; j++) {
      printf("%lu ", g->adj[j]);
    }
    printf("\n");
  }
}

int main(int argc, char *argv[]) {
  if (argc != 3) {
    fprintf(stderr, "Usage: %s <binary_file> <edge_list_file>\n", argv[0]);
    return 1;
  }

  graph_t g1, g2;
  if (load_graph_from_binary(argv[1], &g1) != 0) {
    fprintf(stderr, "Error loading graph from binary file\n");
    return 1;
  }

  if (load_graph_from_file(argv[2], &g2) != 0) {
    fprintf(stderr, "Error loading graph from edge list file\n");
    return 1;
  }

  if (compare_graphs(&g1, &g2) != 0) {
    fprintf(stderr, "Graphs do not match\n");

    // Print the graphs for debugging
    printf("Graph from binary file:\n");
    print_graph(&g1);
    printf("\nGraph from edge list file:\n");
    print_graph(&g2);

    return 1;
  }

  printf("Graphs match successfully.\n");

  free(g1.num_edges);
  free(g1.adj);
  free(g2.num_edges);
  free(g2.adj);

  return 0;
}
