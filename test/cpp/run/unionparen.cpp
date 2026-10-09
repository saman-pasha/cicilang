// A plain struct or union member initialized by parentheses from a value that is not its own type is aggregate
// initialization (C++20): the first member from the first value. libc++ 21's basic_string() : __rep_(__short()) sets the
// union __rep to a short string; also the plain case, the copy of the member, and a class template's nested union.
#include <cstdio>

struct Short {
  unsigned char flag;
  char data[23];
};
struct Long {
  unsigned long cap;
  unsigned long size;
  unsigned long ptr;
};
union Rep {
  Short s;
  Long l;
};
struct Str {
  Rep rep_;
  int tag_;
  Str() : rep_(Short{7, {1, 2}}), tag_(1) {}
  explicit Str(int t) : rep_(), tag_(t) {}
  Str(const Str &o) : rep_(o.rep_), tag_(o.tag_) {}
  int flag() const { return rep_.s.flag; }
  int first() const { return rep_.s.data[0] + rep_.s.data[1]; }
};

template <class C>
struct BS {
  struct Small {
    unsigned char flag;
    C data[23];
  };
  struct Large {
    unsigned long cap;
    unsigned long size;
    unsigned long ptr;
  };
  union Store {
    Small s;
    Large l;
  };
  Store rep_;
  int tag_;
  BS() : rep_(Small()), tag_(1) { rep_.s.flag = 5; }
  explicit BS(int t) : rep_(Small{9, {3, 4}}), tag_(t) {}
  int flag() const { return rep_.s.flag; }
  int first() const { return rep_.s.data[0] + rep_.s.data[1]; }
};

int main() {
  Str a;
  Str b(2);
  Str c(a);
  std::printf("%d %d %d %d %d %d %d\n", a.flag(), b.flag(), a.tag_, b.tag_, a.first(), c.flag(), c.first());
  BS<char> x;
  BS<char> y(2);
  BS<short> z(3);
  std::printf("%d %d %d %d %d %d\n", x.flag(), y.flag(), x.tag_, y.tag_, y.first(), z.first());
  return 0;
}
