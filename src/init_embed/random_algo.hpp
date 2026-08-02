#include <hip/hip_runtime.h>
#include <raft/core/resource/cuda_stream.hpp>
#include <raft/core/resources.hpp>
#include <raft/random/rng.cuh>
#include <raft/random/rng_state.hpp>
#include <rmm/device_uvector.hpp>
#include <vector>

namespace RandomInit {
void launcher(int n, int d, int random_state, std::vector<float> *out,
              raft::resources &handle) {
  int n_values = n * d;
  cudaStream_t stream = raft::resource::get_cuda_stream(handle);
  rmm::device_uvector<float> d_out(n_values, stream);
  raft::random::RngState rng(random_state);
  raft::random::uniform(handle, rng, d_out.data(), n_values, -10.0f, 10.0f);
  out->resize(n_values);
  hipMemcpy(out->data(), d_out.data(), n_values * sizeof(float),
            hipMemcpyDeviceToHost);
}
} // namespace RandomInit
