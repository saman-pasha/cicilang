// Access control, the forms C++ allows (0.127): a private or protected base's members inside the derived
// class and its friends, a class's and a struct's default base access, a protected member through an object
// of the accessing class's own type ([class.protected]), a private nested type named by a member and a friend
// and through a public alias, a private destructor called from a member, a private operator used inside the
// class and by a friend, and the address of a private member taken inside its class.
#include <cstdio>

struct Base {
  int pub() const { return 1; }
  static int spub() { return 10; }
protected:
  int prot() const { return 2; }
  int pdata = 3;
  static int sprot() { return 20; }
};
class PrivD : private Base {
public:
  int use() const { return pub() + prot() + pdata; }
  friend int peek(const PrivD &);
};
int peek(const PrivD &d) { return d.pub() * 100; }
struct ProtD : protected Base { int use() const { return pub() + prot(); } };
struct GrandD : ProtD { int use2() const { return pub() + prot() + pdata + sprot(); } };
class ClassDefault : Base { public: int use() const { return pub() + spub(); } };
struct StructDefault : Base {};
struct OwnType : Base {
  int peek(OwnType &o) { return o.pdata + o.prot(); }
  static int sp(OwnType *o) { return o->pdata; }
  int stat(Base &) { return Base::sprot(); }   // a static protected member: no object rule
};
class Outer {
  struct Secret { int v = 7; };
public:
  using Alias = Secret;
  Secret make() const { return Secret{}; }
  int get() const { return make().v; }
  friend struct Peek;
};
struct Peek { int get() { Outer::Secret s; return s.v + 1; } };
class Handle {
  ~Handle() {}
public:
  int v = 2;
  static int run() { Handle *h = new Handle; int r = h->v; delete h; return r; }   // the private destructor through a member
};
class Money {
  int c;
  bool operator<(const Money &o) const { return c < o.c; }
public:
  explicit Money(int x) : c(x) {}
  bool less(const Money &o) const { return *this < o; }
  friend bool cmp(const Money &, const Money &);
};
bool cmp(const Money &a, const Money &b) { return a < b; }
class Account {
  int balance = 5;
public:
  static int Account::*field() { return &Account::balance; }
};

int main() {
  PrivD p; ProtD q; GrandD g; ClassDefault c; StructDefault s; OwnType o, o2; Peek pk; Outer out;
  std::printf("%d %d %d %d %d\n", p.use(), peek(p), q.use(), g.use2(), c.use());
  std::printf("%d %d %d %d\n", s.pub(), o.peek(o2), OwnType::sp(&o), o.stat(o2));
  Outer::Alias a;
  std::printf("%d %d %d\n", out.get(), pk.get(), a.v);
  std::printf("%d\n", Handle::run());
  Money m1(1), m2(2);
  std::printf("%d %d\n", (int) m1.less(m2), (int) cmp(m2, m1));
  Account acct;
  std::printf("%d\n", acct.*Account::field());
  return 0;
}
