#include "random_algo.hpp"
#include "spectral_algo.hpp"
#include <raft/core/coo_matrix.hpp>
#include <raft/core/resources.hpp>
#include <raft/util/cudart_utils.hpp>
#include <rmm/device_uvector.hpp>
#include <vector>

int main() {
  int random_state = 1;
  int n_numbers = 10;
  int n_dims = 5;
  std::vector<float> out;
  raft::resources handle;
  cudaStream_t stream = raft::resource::get_cuda_stream(handle);

  int nnz = 5;
  std::vector<int> h_rows = {0, 1, 0, 1, 2};
  std::vector<int> h_cols = {0, 0, 1, 1, 2};
  std::vector<float> h_vals = {1, 1, 1, 1, 1};

  raft::sparse::COO<float> coo(stream);
  coo.allocate(nnz, 3, 3, false, stream);
  raft::update_device(coo.rows(), h_rows.data(), nnz, stream);
  raft::update_device(coo.cols(), h_cols.data(), nnz, stream);
  raft::update_device(coo.vals(), h_vals.data(), nnz, stream);

  rmm::device_uvector<float> spectral_out(n_numbers * n_dims, stream);
  RandomInit::launcher(n_numbers, n_dims, random_state, &out, handle);
  for (int i = 0; i < n_numbers; i++) {
    std::cout << out[i] << std::endl;
  }
  SpectralInit::launcher(n_numbers, n_dims, random_state, spectral_out.data(),
                         &coo, handle);
  for (int i = 0; i < n_numbers; i++) {
    std::cout << spectral_out.data()[i] << std::endl;
  }
  return 0;
}
