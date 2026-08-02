// Local patch of cuvs::embed::spectral::fit() with tol exposed

#include "../sparse/cluster/detail/spectral.cuh"
#include <cuvs/embed/spectral.hpp>
#include <raft/core/device_coo_matrix.hpp>
#include <raft/core/resources.hpp>

namespace cuvs_local::embed::spectral {

template <typename T>
void fit(const raft::resources &handle,
         raft::device_coo_matrix_view<T, int, int, int> knn_graph,
         int n_components, raft::device_matrix_view<T, int> out,
         unsigned long long seed = 0L, T tol = 0.01) {
  cuvs::sparse::cluster::spectral::detail::fit_embedding(
      handle, knn_graph.structure_view().get_rows().data(),
      knn_graph.structure_view().get_cols().data(),
      knn_graph.get_elements().data(), knn_graph.structure_view().get_nnz(),
      knn_graph.structure_view().get_n_rows(), n_components, out.data_handle(),
      seed, tol);
}

} // namespace cuvs_local::embed::spectral
