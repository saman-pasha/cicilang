/* `own' WHERE ONLY A NAME CAN STAND (0.306; the Ambitious session's finding 37): an init-capture, refused at its use in
   a parameter's words, refused at line 5 (reader k169) */
int main() {
    int x = 1;
    auto f = [own = x]() { return 1; };
    return f() - 1;
}
