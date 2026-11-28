// A CONST FILE-SCOPE OBJECT WHOSE DEFAULT CONSTRUCTOR IS DELETED, OF A CLASS THAT IS NOT CONST-DEFAULT-CONSTRUCTIBLE TOO (1.6.55):
// the constructor's words first at the file too
struct X { X() = delete; int k; };
const X g;
int main() {
  return 0;
}
