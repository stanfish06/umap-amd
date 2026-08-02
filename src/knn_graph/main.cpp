#include "algo.hpp"
#include <raft/core/device_mdarray.hpp>
#include <raft/core/resources.hpp>
#include <raft/util/cudart_utils.hpp>

#include <iostream>
#include <vector>

int main() {
  raft::resources handle;
  cudaStream_t stream = raft::resource::get_cuda_stream(handle);

  const int64_t n_rows = 4;
  const int64_t n_cols = 2;
  const int64_t k = 2;
  std::vector<float> h_dataset = {
      0.0f, 0.0f, 0.1f, 0.0f, 10.0f, 10.0f, 10.1f, 10.0f,
  };

  auto dataset =
      raft::make_device_matrix<float, int64_t>(handle, n_rows, n_cols);
  raft::update_device(dataset.data_handle(), h_dataset.data(), h_dataset.size(),
                      stream);

  auto neighbors =
      raft::make_device_matrix<int64_t, int64_t>(handle, n_rows, k);
  auto distances = raft::make_device_matrix<float, int64_t>(handle, n_rows, k);

  KNNGraph::launcher(handle, raft::make_const_mdspan(dataset.view()),
                     neighbors.view(), distances.view());

  std::vector<int64_t> h_neighbors(n_rows * k);
  std::vector<float> h_distances(n_rows * k);
  raft::update_host(h_neighbors.data(), neighbors.data_handle(), n_rows * k,
                    stream);
  raft::update_host(h_distances.data(), distances.data_handle(), n_rows * k,
                    stream);
  raft::resource::sync_stream(handle, stream);

  bool ok = true;
  for (int64_t i = 0; i < n_rows; i++) {
    std::cout << "point " << i << " neighbors:";
    for (int64_t j = 0; j < k; j++) {
      std::cout << " (" << h_neighbors[i * k + j] << ", "
                << h_distances[i * k + j] << ")";
    }
    std::cout << std::endl;
  }
  return 0;
}
