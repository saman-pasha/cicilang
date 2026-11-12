/* `own' WHERE ONLY A NAME CAN STAND (0.306; the Ambitious session's finding 37): a structured binding, refused at its
   use in a parameter's words, refused at line 6 (reader k169) */
struct pr { int a, b; };
int main() {
    pr p{1, 2};
    auto [own, b] = p;
    return b - 2;
}
