// A STRUCT THAT A DECLARATION ALONE NAMES IS DEFINED (0.250): a class of more than 16 bytes by value is `ptr byval(%struct...)'
// on x86-64, and this instance is named by a declared function's parameter only -- macOS's fpos<mbstate_t>, 136 bytes, its
// mbstate_t a 128-byte union, is basic_streambuf::seekpos's, declared in every stream's table. Built with -c by test/cpp.sh.
typedef union { char __mbstate8[128]; long long _mbstateL; } __st_t;
typedef __st_t st_t;
template <class S> class Fpos { S st_; long long off_; public: Fpos(long long o = 0) : st_(), off_(o) {} };
struct Sb { virtual ~Sb() {} virtual long long seekpos(Fpos<st_t> p, int which); };
struct Mine : Sb { };
Sb *make() { return new Mine; }
