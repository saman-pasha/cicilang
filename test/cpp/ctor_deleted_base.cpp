// ... A BASE WHOSE DEFAULT CONSTRUCTOR IS DELETED (1.6.55)
struct X { X() = delete; };
struct Y : X {
  Y() {}
};
int main() {
  return 0;
}
