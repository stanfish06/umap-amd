#include <cstdint>
#include <hip/hip_runtime.h>

#include <cuvs/neighbors/brute_force.hpp>
#include <raft/core/device_csr_matrix.hpp>
#include <raft/core/device_mdarray.hpp>
#include <raft/core/resources.hpp>

namespace KNNGraph {

void launcher(
    raft::resources &handle,
    raft::device_csr_matrix_view<const float, int, int, int> X,
    raft::device_csr_matrix_view<const float, int, int, int> Y,
    raft::device_matrix_view<int, int64_t, raft::row_major> neighbors,
    raft::device_matrix_view<float, int64_t, raft::row_major> distances,
    bool do_self_knn = true) {
  auto index = cuvs::neighbors::brute_force::build(handle, X);
  cuvs::neighbors::brute_force::sparse_search_params search_params;
  if (do_self_knn) {
    cuvs::neighbors::brute_force::search(handle, search_params, index, X,
                                         neighbors, distances);
  } else {
    cuvs::neighbors::brute_force::search(handle, search_params, index, Y,
                                         neighbors, distances);
  }
}
} // namespace KNNGraph
