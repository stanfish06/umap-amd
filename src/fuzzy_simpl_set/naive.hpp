template <typename value_t>
void smooth_knn_dist_kernel(const value_t *knn_dists, int n, float mean_dist,
                            value_t *sigmas, value_t *rhos, int n_neighbors,
                            float local_connectivity = 1.0, int n_iter = 64,
                            float bandwidth = 1.0) {}

void compute_membership_strength_kernel() {}
void smooth_knn_dist() {}
void compute_membership_strength() {}
void symmetrize() {}
void launcher() {}
