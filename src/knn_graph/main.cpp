#include "algo.hpp"
#include <raft/core/device_csr_matrix.hpp>
#include <raft/core/device_mdarray.hpp>
#include <raft/core/resources.hpp>
#include <raft/util/cudart_utils.hpp>

#include <iostream>
#include <vector>

int main() {
  raft::resources handle;
  cudaStream_t stream = raft::resource::get_cuda_stream(handle);

  const int n_rows = 4;
  const int n_cols = 2;
  const int nnz = n_rows * n_cols;
  const int64_t k = 2;

  std::vector<int> h_indptr = {0, 2, 4, 6, 8};
  std::vector<int> h_indices = {0, 1, 0, 1, 0, 1, 0, 1};
  std::vector<float> h_values = {
      1.0f, 1.0f, 1.1f, 1.0f, 11.0f, 11.0f, 11.1f, 11.0f,
  };

  auto d_indptr = raft::make_device_vector<int, int>(handle, n_rows + 1);
  auto d_indices = raft::make_device_vector<int, int>(handle, nnz);
  auto d_values = raft::make_device_vector<float, int>(handle, nnz);
  raft::update_device(d_indptr.data_handle(), h_indptr.data(), n_rows + 1,
                      stream);
  raft::update_device(d_indices.data_handle(), h_indices.data(), nnz, stream);
  raft::update_device(d_values.data_handle(), h_values.data(), nnz, stream);

  auto structure = raft::make_device_compressed_structure_view<int, int, int>(
      d_indptr.data_handle(), d_indices.data_handle(), n_rows, n_cols, nnz);
  auto dataset = raft::make_device_csr_matrix_view<const float, int, int, int>(
      d_values.data_handle(), structure);

  auto neighbors = raft::make_device_matrix<int, int64_t>(handle, n_rows, k);
  auto distances = raft::make_device_matrix<float, int64_t>(handle, n_rows, k);

  KNNGraph::launcher(handle, dataset, dataset, neighbors.view(),
                     distances.view(), /*do_self_knn=*/true);

  std::vector<int> h_neighbors(n_rows * k);
  std::vector<float> h_distances(n_rows * k);
  raft::update_host(h_neighbors.data(), neighbors.data_handle(), n_rows * k,
                    stream);
  raft::update_host(h_distances.data(), distances.data_handle(), n_rows * k,
                    stream);
  raft::resource::sync_stream(handle, stream);

  bool ok = true;
  for (int i = 0; i < n_rows; i++) {
    std::cout << "point " << i << " neighbors:";
    for (int64_t j = 0; j < k; j++) {
      std::cout << " (" << h_neighbors[i * k + j] << ", "
                << h_distances[i * k + j] << ")";
    }
    std::cout << std::endl;
  }
  return 0;
}
