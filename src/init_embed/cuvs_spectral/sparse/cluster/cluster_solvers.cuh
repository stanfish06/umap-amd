/*
 * Copyright (c) 2019-2024, NVIDIA CORPORATION.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef __CLUSTER_SOLVERS_H
#define __CLUSTER_SOLVERS_H

#pragma once

#include <raft/spectral/matrix_wrappers.hpp>

#include <utility> // for std::pair

namespace cuvs {
namespace spectral {

using namespace raft::spectral::matrix;

// aggregate of control params for Eigen Solver:
//
template <typename index_type_t, typename value_type_t,
          typename size_type_t = index_type_t>
struct cluster_solver_config_t {
  size_type_t n_clusters;
  size_type_t maxIter;

  value_type_t tol;

  unsigned long long seed{123456};
};

} // namespace spectral
} // namespace cuvs

#endif
