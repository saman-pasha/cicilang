// An anonymous struct inside an anonymous union is one member of the union, its fields in sequence (0.112): libc++
// 18's basic_format_args keeps `union { struct { const value *__values_; uint64_t __types_; }; const arg *__args_; }'
#include <cstdint>
#include <cstdio>
const int vals[2] = {10, 20};
struct Args {
  size_t size_{0};
  union {
    struct {
      const int *values_;
      uint64_t types_;
    };
    const long *args_;
  };
  Args(uint64_t t) : size_(2) { values_ = vals; types_ = t; }
  int get(size_t i) const { return values_[i] + (int) (types_ >> (4 * i) & 0xF); }
};
int main() {
  Args a(0x21);
  std::printf("%d %d %d\n", a.get(0), a.get(1), (int) sizeof(Args));
  std::printf("%d %d\n", a.args_ == (const long *) vals, (int) a.types_);
  return 0;
}
