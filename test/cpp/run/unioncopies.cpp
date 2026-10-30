// A UNION'S IMPLICIT COPIES ASK ITS VARIANT MEMBERS' OWN COPIES ([class.copy.ctor]/10, [class.copy.assign]/7; 0.227): a member
// class that writes a constructor of other parameters, beside `= default', still copies trivially, so the union copies, moves
// and is swapped by std::swap -- libc++ 22's string holds `union __rep { __short __s; __long __l; ... }' over such a `__long',
// whose constructor sets two bit-fields of an anonymous packed struct
#include <cstdio>
#include <cstring>
#include <type_traits>
#include <utility>
struct alloc_result { unsigned long ptr; unsigned long count; };
struct Long {
    Long() = default;
    Long(alloc_result a, unsigned long size) : is_long_(true), cap_(a.count / 2), size_(size), data_(a.ptr) {}
    struct __attribute__((packed)) {
        unsigned long is_long_ : 1;
        unsigned long cap_ : 63;
    };
    unsigned long size_;
    unsigned long data_;
};
struct Short {
    struct __attribute__((packed)) {
        unsigned char is_long_ : 1;
        unsigned char size_ : 7;
    };
    char data_[23];
};
struct uninit_tag {};
union Rep {
    Short s;
    Long l;
    Rep() = default;
    Rep(Short r) : s(r) {}
    Rep(Long r) : l(r) {}
    Rep(uninit_tag) {}
};
int main() {
    Rep r = Rep(Long(alloc_result{77, 64}, 16));
    std::printf("%d %lu %lu %lu\n", (int) r.l.is_long_, (unsigned long) r.l.cap_, r.l.size_, r.l.data_);
    Short sh{};
    sh.is_long_ = 0; sh.size_ = 3; std::memcpy(sh.data_, "abc", 4);
    Rep q = sh;
    std::printf("%d %d %s\n", (int) q.s.is_long_, (int) q.s.size_, q.s.data_);
    std::swap(r, q);
    std::printf("%d %s / %d %lu\n", (int) r.s.size_, r.s.data_, (int) q.l.size_, q.l.data_);
    std::printf("%d %d %d %d %d\n", (int) std::is_move_constructible<Rep>::value, (int) std::is_move_assignable<Rep>::value,
                (int) std::is_copy_constructible<Rep>::value, (int) std::is_copy_assignable<Rep>::value, (int) sizeof(Rep));
    Rep u = Rep(uninit_tag());
    u = Rep(Long(alloc_result{5, 10}, 2));
    std::printf("%lu %lu\n", u.l.size_, (unsigned long) u.l.cap_);
    return 0;
}
