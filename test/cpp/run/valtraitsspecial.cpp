// the traits of a copy and a move: deleted ones, implicit ones a declared member suppresses or deletes, and parts that delete them
#include <cstdio>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <tuple>
#include <utility>
#include <vector>
#include <type_traits>
#define P(...) std::printf("%d", (int) (__VA_ARGS__))
struct NC { NC() {} NC(const NC &) = delete; NC(NC &&) = default; };
struct NM { NM() {} NM(NM &&) = delete; };
struct OnlyCopy { OnlyCopy() {} OnlyCopy(const OnlyCopy &) {} };
struct MoveDecl { MoveDecl() {} MoveDecl(MoveDecl &&) {} };
struct MoveAssignDecl { MoveAssignDecl &operator=(MoveAssignDecl &&) { return *this; } };
struct Dtor { ~Dtor() {} };
struct HoldsUnique { std::unique_ptr<int> p; };
struct HoldsMutex { std::mutex m; };
struct HoldsRef { int &r; };
struct HoldsConst { const int c = 0; };
struct DefCopy { std::unique_ptr<int> p; DefCopy() = default; DefCopy(const DefCopy &) = default; DefCopy(DefCopy &&) = default; };
struct Base { Base() {} Base(const Base &) = delete; };
struct Derived : Base { Derived() {} };
int main() {
  P(std::is_copy_constructible_v<NC>); P(std::is_move_constructible_v<NC>); P(std::is_copy_assignable_v<NC>); P(std::is_move_assignable_v<NC>);
  P(std::is_copy_constructible_v<NM>); P(std::is_move_constructible_v<NM>);
  std::puts("");
  P(std::is_copy_constructible_v<OnlyCopy>); P(std::is_move_constructible_v<OnlyCopy>); P(std::is_copy_constructible_v<MoveDecl>); P(std::is_move_constructible_v<MoveDecl>);
  P(std::is_copy_constructible_v<MoveAssignDecl>); P(std::is_copy_assignable_v<MoveAssignDecl>); P(std::is_move_assignable_v<MoveAssignDecl>);
  P(std::is_move_constructible_v<Dtor>); P(std::is_move_assignable_v<Dtor>);
  std::puts("");
  P(std::is_copy_constructible_v<HoldsUnique>); P(std::is_move_constructible_v<HoldsUnique>); P(std::is_copy_assignable_v<HoldsUnique>); P(std::is_move_assignable_v<HoldsUnique>);
  P(std::is_copy_constructible_v<HoldsMutex>); P(std::is_move_constructible_v<HoldsMutex>);
  P(std::is_copy_constructible_v<HoldsRef>); P(std::is_copy_assignable_v<HoldsRef>); P(std::is_copy_constructible_v<HoldsConst>); P(std::is_copy_assignable_v<HoldsConst>);
  P(std::is_copy_constructible_v<DefCopy>); P(std::is_move_constructible_v<DefCopy>);
  P(std::is_copy_constructible_v<Derived>); P(std::is_default_constructible_v<Derived>);
  std::puts("");
  P(std::is_copy_constructible_v<std::unique_ptr<int>>); P(std::is_move_constructible_v<std::unique_ptr<int>>); P(std::is_copy_assignable_v<std::unique_ptr<int>>);
  P(std::is_copy_constructible_v<std::mutex>); P(std::is_move_constructible_v<std::mutex>);
  P(std::is_copy_constructible_v<std::pair<int, std::unique_ptr<int>>>); P(std::is_move_constructible_v<std::pair<int, std::unique_ptr<int>>>);
  P(std::is_copy_constructible_v<std::tuple<std::unique_ptr<int>>>); P(std::is_copy_constructible_v<std::optional<std::unique_ptr<int>>>);
  P(std::is_copy_assignable_v<std::pair<const int, int>>); P(std::is_copy_constructible_v<std::vector<std::unique_ptr<int>>>);
  std::puts("");
  P((std::is_constructible_v<int &, int &>)); P((std::is_constructible_v<int &, int>)); P((std::is_constructible_v<const int &, int>)); P((std::is_constructible_v<int &&, int &>));
  P((std::is_constructible_v<int &&, int>)); P((std::is_constructible_v<const long &, int &>)); P((std::is_constructible_v<Base &, Derived &>)); P((std::is_convertible_v<int, int &>));
  P((std::is_assignable_v<int &, int>)); P((std::is_assignable_v<int, int>)); P((std::is_assignable_v<const int &, int>)); P((std::is_assignable_v<int &, double>));
  std::puts("");
}
