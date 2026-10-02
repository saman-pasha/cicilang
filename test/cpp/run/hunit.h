// a header of the program's own, imported as a header unit by headerunit.cpp and included by hdrinline.cpp:
// its macros reach the importer, and its inline function is defined once, linkonce
#define TEN 10
#define SQ(x) ((x) * (x))
inline int twelve() { return 12; }
