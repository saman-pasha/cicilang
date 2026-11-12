/* `own' WHERE ONLY A NAME CAN STAND (0.306; the Ambitious session's finding 37): a function parameter pack, refused at
   line 3 (reader k169) */
template <class... Ts> int count(Ts... own) { return 0; }
int main() { return count(1, 2); }
