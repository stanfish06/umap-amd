#include <hip/hip_runtime.h>
#include <raft/core/resource/cuda_stream.hpp>
#include <raft/core/resources.hpp>
#include <raft/random/rng.cuh>
#include <raft/random/rng_state.hpp>
#include <rmm/device_uvector.hpp>
#include <vector>

namespace RandomInit {
void launcher(int n, int random_state, std::vector<float> *out) {
  raft::resources handle;
  rmm::device_uvector<float> d_out(n, raft::resource::get_cuda_stream(handle));
  raft::random::RngState rng(random_state);
  raft::random::uniform(handle, rng, d_out.data(), n, -10.0f, 10.0f);
  out->resize(n);
  hipMemcpy(out->data(), d_out.data(), n * sizeof(float),
            hipMemcpyDeviceToHost);
}
} // namespace RandomInit
