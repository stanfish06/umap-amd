#include <hip/hip_runtime.h>

#include <cuvs/neighbors/brute_force.hpp>
#include <raft/core/device_mdarray.hpp>
#include <raft/core/resources.hpp>

namespace KNNGraph {
void launcher(
    raft::resources &handle,
    raft::device_matrix_view<const float, int64_t, raft::row_major> dataset,
    raft::device_matrix_view<int64_t, int64_t, raft::row_major> neighbors,
    raft::device_matrix_view<float, int64_t, raft::row_major> distances) {
  cuvs::neighbors::brute_force::index_params index_params;
  auto index =
      cuvs::neighbors::brute_force::build(handle, index_params, dataset);

  cuvs::neighbors::brute_force::search_params search_params;
  cuvs::neighbors::brute_force::search(handle, search_params, index, dataset,
                                       neighbors, distances);
}
} // namespace KNNGraph
