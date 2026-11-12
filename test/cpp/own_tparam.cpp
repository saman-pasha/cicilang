/* `own' WHERE ONLY A NAME CAN STAND (0.306; the Ambitious session's finding 37): a template's type parameter, which was
   a syntax error, refused at line 3 (reader k169) */
template <class own> int id(int x) { return x; }
int main() { return id<int>(0); }
