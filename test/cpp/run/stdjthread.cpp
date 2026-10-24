#include <atomic>
#include <cstdio>
#include <stop_token>
#include <thread>
// std::jthread and std::stop_token (C++20)
int main() {
  std::atomic<int> n{0};
  {
    std::jthread t([&n](std::stop_token st) {
      while (!st.stop_requested()) { n++; if (n > 1000) break; }
    });
    t.request_stop();
  }
  std::printf("%d\n", (int) (n >= 0));
  std::stop_source src;
  std::stop_token tok = src.get_token();
  std::printf("%d %d\n", (int) tok.stop_requested(), (int) tok.stop_possible());
  src.request_stop();
  std::printf("%d\n", (int) tok.stop_requested());
  int hits = 0;
  {
    std::stop_callback cb(tok, [&hits] { hits++; });
  }
  std::printf("%d\n", hits);
  std::jthread j([](int a, int b) { std::printf("%d\n", a + b); }, 2, 3);
  j.join();
  return 0;
}
