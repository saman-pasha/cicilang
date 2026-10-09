// access control, the allowed forms (0.117): a class's own members, a nested class, a friend class and a friend function, a friend operator, a
// protected member in a derived class, a private constructor used by a static member, private data read through another object of
// the same class, a lambda in a member function; test/cpp/access_*.cpp are the refusals
#include <cstdio>
class Account {
  int balance = 10;
  static int count;
  void audit() { std::printf("audit %d\n", balance); }
protected:
  int limit = 100;
  void tweak() { limit++; }
public:
  Account() { count++; }
  int get() const { return balance; }
  void deposit(int n) { balance += n; audit(); }
  friend class Auditor;
  friend void peek(const Account &a);
  friend bool operator==(const Account &a, const Account &b);
  struct Inner { int read(const Account &a) { return a.balance; } };
  static int made() { return count; }
  int viaLambda() { auto f = [this]() { return balance * 2 + limit; }; return f(); }
};
int Account::count = 0;
class Auditor { public: int look(const Account &a) { return a.balance + a.limit; } void poke(Account &a) { a.audit(); a.tweak(); } };
void peek(const Account &a) { std::printf("peek %d\n", a.balance); }
bool operator==(const Account &a, const Account &b) { return a.balance == b.balance; }
class Savings : public Account { public: int lim() { tweak(); return limit; } };
struct Plain { int open = 1; private: int hidden = 2; public: int sum() { return open + hidden; } };
union U { int i; float f; };
class Priv { Priv() {} public: static Priv *make() { return new Priv(); } int v = 3; };
class Multi { public: Multi(int) {} private: Multi(double) {} public: static Multi make() { return Multi(1.5); } };
template <class T> class Holder { T v; public: Holder(T x) : v(x) {} T get() const { return v; } template <class U> friend class Holder; template <class U> T from(const Holder<U> &h) { return (T)h.v; } };
struct Base { protected: int prot = 7; private: int priv = 8; public: int pub = 9; int getPriv() { return priv; } };
struct Der : Base { int sum() { return prot + pub + getPriv(); } };
int main() {
  Account a; a.deposit(5);
  Auditor au; std::printf("%d\n", au.look(a)); au.poke(a);
  peek(a);
  Account::Inner in; std::printf("%d %d\n", in.read(a), (int)(a == a));
  Savings s; std::printf("%d\n", s.lim());
  Plain p; std::printf("%d\n", p.sum());
  Priv *pp = Priv::make(); std::printf("%d\n", pp->v); delete pp;
  auto m = Multi::make(); (void)m;
  U u; u.i = 3;
  std::printf("%d %d\n", a.viaLambda(), Account::made());
  Holder<int> hi(4); Holder<long> hl(5); std::printf("%d %d\n", hi.get(), (int)hl.from(hi));
  Der d; std::printf("%d\n", d.sum());
  return 0;
}
