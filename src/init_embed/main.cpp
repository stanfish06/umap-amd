#include "random_algo.hpp"

int main() {
  int random_state = 1;
  int n_numbers = 10;
  std::vector<float> out;
  RandomInit::launcher(n_numbers, random_state, &out);
  for (int i = 0; i < n_numbers; i++) {
    std::cout << out[i] << std::endl;
  }
  return 0;
}
