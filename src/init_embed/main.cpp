#include "random_algo.hpp"
#include "spectral_algo.hpp"
#include <raft/core/coo_matrix.hpp>
#include <raft/core/resources.hpp>

int main() {
  int random_state = 1;
  int n_numbers = 10;
  int n_dims = 5;
  std::vector<float> out;
  raft::resources handle;
  cudaStream_t stream = raft::resource::get_cuda_stream(handle);
  raft::sparse::COO<float> coo(stream);
  RandomInit::launcher(n_numbers, n_dims, random_state, &out, handle);
  SpectralInit::launcher(n_numbers, n_dims, &coo, handle);
  for (int i = 0; i < n_numbers; i++) {
    std::cout << out[i] << std::endl;
  }
  return 0;
}
