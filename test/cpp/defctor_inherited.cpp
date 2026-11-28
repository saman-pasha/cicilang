// A CLASS THAT INHERITS ITS BASE'S CONSTRUCTORS, NONE OF THEM A DEFAULT ONE (1.6.55): its implicit one is deleted
struct B { B(int) {} };
struct D : B { using B::B; };
int main() {
  D d;
  return 0;
}
