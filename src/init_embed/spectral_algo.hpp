#include <cstdint>
#include <cuvs/embed/spectral.hpp>
#include <raft/core/coo_matrix.hpp>
#include <raft/core/device_coo_matrix.hpp>
#include <raft/core/device_mdarray.hpp>
#include <raft/core/device_mdspan.hpp>
#include <raft/core/mdspan_types.hpp>
#include <raft/core/resource/cuda_stream.hpp>
#include <raft/core/resources.hpp>
#include <raft/core/sparse_types.hpp>
#include <raft/sparse/coo.hpp>

namespace SpectralInit {
void launcher(int n, int d, raft::sparse::COO<float> *coo,
              raft::resources &handle) {
  cudaStream_t stream = raft::resource::get_cuda_stream(handle);
  auto tmp_embedding =
      raft::make_device_matrix<float, int, raft::col_major>(handle, n, d);
  auto connectivity_graph_view =
      raft::make_device_coo_matrix_view<float, int, int, int64_t>(
          coo->vals(),
          raft::make_device_coordinate_structure_view<int, int, int64_t>(
              coo->rows(), coo->cols(), n, n, coo->nnz));
  // cuvs::embed::spectral::fit(handle, connectivity_graph_view, d,
  //                            tmp_embedding.view());
}
} // namespace SpectralInit
