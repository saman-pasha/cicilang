// ... A FREE ONE CALLED BY A QUALIFIED NAME (1.6.55): `no member named 'h' in the global namespace'
void h() = delete;
int main() {
  ::h();
  return 0;
}
