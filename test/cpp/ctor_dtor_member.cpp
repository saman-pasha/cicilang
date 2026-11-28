// ... A MEMBER WHOSE DESTRUCTOR IS DELETED, which the constructor destroys where a later part throws (1.6.55; [class.base.init]/12)
struct D { ~D() = delete; };
struct E {
  D d;
  E() {}
};
int main() {
  return 0;
}
