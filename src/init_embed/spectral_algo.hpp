#include "cuvs_spectral/embed/spectral_patched.hpp"
#include <hip/amd_detail/host_defines.h>
#include <raft/core/coo_matrix.hpp>
#include <raft/core/device_coo_matrix.hpp>
#include <raft/core/device_mdarray.hpp>
#include <raft/core/device_mdspan.hpp>
#include <raft/core/mdspan_types.hpp>
#include <raft/core/resource/cuda_stream.hpp>
#include <raft/core/resources.hpp>
#include <raft/core/sparse_types.hpp>
#include <raft/linalg/add.cuh>
#include <raft/linalg/detail/transpose.cuh>
#include <raft/linalg/transpose.cuh>
#include <raft/linalg/unary_op.cuh>
#include <raft/random/rng.cuh>
#include <raft/random/rng_state.hpp>
#include <raft/sparse/coo.hpp>
#include <raft/util/cudart_utils.hpp>
#include <thrust/device_ptr.h>
#include <thrust/execution_policy.h>
#include <thrust/extrema.h>

#include <algorithm>
#include <cmath>
#include <numeric>
#include <random>
#include <vector>

extern "C" void ssteqr_(const char *compz, int *n, float *d, float *e, float *z,
                        int *ldz, float *work, int *info);
extern "C" void dsteqr_(const char *compz, int *n, double *d, double *e,
                        double *z, int *ldz, double *work, int *info);

namespace SpectralInit {

enum class Backend { GPU, CPU };

namespace detail {

inline void steqr(char compz, int n, float *d, float *e, float *z, int ldz,
                  float *work, int *info) {
  ssteqr_(&compz, &n, d, e, z, &ldz, work, info);
}
inline void steqr(char compz, int n, double *d, double *e, double *z, int ldz,
                  double *work, int *info) {
  dsteqr_(&compz, &n, d, e, z, &ldz, work, info);
}

template <typename T>
void laplacian_matvec(int n, const std::vector<int> &rows,
                      const std::vector<int> &cols, const std::vector<T> &vals,
                      const std::vector<T> &inv_sqrt_deg,
                      const std::vector<T> &v, std::vector<T> &out) {
  std::vector<T> scaled(n);
  for (int i = 0; i < n; i++)
    scaled[i] = v[i] * inv_sqrt_deg[i];

  std::fill(out.begin(), out.end(), T(0));
  for (size_t e = 0; e < rows.size(); e++)
    out[rows[e]] += vals[e] * scaled[cols[e]];

  for (int i = 0; i < n; i++)
    out[i] = v[i] - out[i] * inv_sqrt_deg[i];
}

template <typename T> T dot(const std::vector<T> &a, const std::vector<T> &b) {
  T s = 0;
  for (size_t i = 0; i < a.size(); i++)
    s += a[i] * b[i];
  return s;
}

template <typename T> T norm2(const std::vector<T> &a) {
  return std::sqrt(dot(a, a));
}
template <typename T>
void spectral_cpu(int n, int d, int random_state, T *out,
                  raft::sparse::COO<float> *coo, raft::resources &handle,
                  T tol) {
  cudaStream_t stream = raft::resource::get_cuda_stream(handle);
  int nnz = coo->nnz;

  std::vector<int> h_rows(nnz), h_cols(nnz);
  std::vector<float> h_vals_f(nnz);
  raft::update_host(h_rows.data(), coo->rows(), nnz, stream);
  raft::update_host(h_cols.data(), coo->cols(), nnz, stream);
  raft::update_host(h_vals_f.data(), coo->vals(), nnz, stream);
  raft::resource::sync_stream(handle, stream);
  std::vector<T> h_vals(h_vals_f.begin(), h_vals_f.end());

  std::vector<T> degree(n, T(0));
  for (int e = 0; e < nnz; e++)
    degree[h_rows[e]] += h_vals[e];
  std::vector<T> inv_sqrt_deg(n);
  for (int i = 0; i < n; i++)
    inv_sqrt_deg[i] = degree[i] > T(0) ? T(1) / std::sqrt(degree[i]) : T(0);

  int neigvs = d + 1;
  int m = std::min(n, std::max(10 * neigvs, 100));

  std::vector<std::vector<T>> V(m + 1, std::vector<T>(n));
  std::vector<T> alpha(m, T(0)), beta(m, T(0));

  std::mt19937 gen(random_state);
  std::normal_distribution<T> dist(T(0), T(1));
  for (int i = 0; i < n; i++)
    V[0][i] = dist(gen);
  T v0norm = norm2(V[0]);
  for (int i = 0; i < n; i++)
    V[0][i] /= v0norm;

  std::vector<T> w(n);
  int effIter = m;
  for (int j = 0; j < m; j++) {
    laplacian_matvec(n, h_rows, h_cols, h_vals, inv_sqrt_deg, V[j], w);

    alpha[j] = dot(w, V[j]);
    for (int i = 0; i < n; i++)
      w[i] -= alpha[j] * V[j][i];
    if (j > 0)
      for (int i = 0; i < n; i++)
        w[i] -= beta[j - 1] * V[j - 1][i];

    for (int pass = 0; pass < 2; pass++)
      for (int k = 0; k <= j; k++) {
        T c = dot(w, V[k]);
        for (int i = 0; i < n; i++)
          w[i] -= c * V[k][i];
      }

    beta[j] = norm2(w);
    if (beta[j] <= tol || j == m - 1) {
      effIter = j + 1;
      break;
    }
    for (int i = 0; i < n; i++)
      V[j + 1][i] = w[i] / beta[j];
  }

  std::vector<T> tri_d(alpha.begin(), alpha.begin() + effIter);
  std::vector<T> tri_e(beta.begin(), beta.begin() + std::max(effIter - 1, 0));
  std::vector<T> z(effIter * effIter);
  std::vector<T> work(std::max(1, 2 * effIter - 2));
  int info = 0;
  steqr('I', effIter, tri_d.data(), tri_e.data(), z.data(), effIter,
        work.data(), &info);

  std::vector<int> order(effIter);
  std::iota(order.begin(), order.end(), 0);
  std::sort(order.begin(), order.end(),
            [&](int a, int b) { return tri_d[a] < tri_d[b]; });

  std::vector<T> h_out(n * d, T(0));
  int n_avail = std::max(effIter - 1, 0);
  int n_take = std::min(d, n_avail);
  for (int col = 0; col < n_take; col++) {
    int eig_idx = order[col + 1];
    for (int i = 0; i < n; i++) {
      T val = T(0);
      for (int j = 0; j < effIter; j++)
        val += V[j][i] * z[j + eig_idx * effIter];
      h_out[i * d + col] = val;
    }
  }

  raft::update_device(out, h_out.data(), (size_t)n * d, stream);
  raft::resource::sync_stream(handle, stream);
}

} // namespace detail

// bug: gpu version is not converging, use cpu version for now
template <typename T>
void launcher(int n, int d, int random_state, T *out,
              raft::sparse::COO<float> *coo, raft::resources &handle,
              float tol = 0.01f, Backend backend = Backend::CPU) {
  if (backend == Backend::CPU) {
    detail::spectral_cpu(n, d, random_state, out, coo, handle, T(tol));
    return;
  }

  int n_values = n * d;
  cudaStream_t stream = raft::resource::get_cuda_stream(handle);
  auto tmp_embedding =
      raft::make_device_matrix<float, int, raft::row_major>(handle, n, d);
  auto connectivity_graph_view =
      raft::make_device_coo_matrix_view<float, int, int, int>(
          coo->vals(),
          raft::make_device_coordinate_structure_view<int, int, int>(
              coo->rows(), coo->cols(), n, n, coo->nnz));
  cuvs_local::embed::spectral::fit(handle, connectivity_graph_view, d,
                                   tmp_embedding.view(), 0L, tol);
  raft::linalg::transpose(handle, tmp_embedding.data_handle(), out, n, d,
                          stream);
  raft::linalg::unaryOp(
      tmp_embedding.data_handle(), tmp_embedding.data_handle(), n_values,
      [=] __device__(T input) { return fabsf(input); }, stream);
  thrust::device_ptr<T> d_ptr =
      thrust::device_pointer_cast(tmp_embedding.data_handle());
  T max = *(thrust::max_element(thrust::hip::par.on(stream), d_ptr,
                                d_ptr + n_values));
  raft::random::RngState rng(random_state);
  raft::random::normal(handle, rng, tmp_embedding.data_handle(), n_values, 0.0f,
                       0.0001f);
  raft::linalg::unaryOp(
      out, out, n_values,
      [=] __device__(T input) { return (10.0f / max) * input; }, stream);
  raft::linalg::add(out, out, tmp_embedding.data_handle(), n_values, stream);
}

} // namespace SpectralInit
