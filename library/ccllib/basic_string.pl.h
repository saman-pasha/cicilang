/* what <basic_string.pl>'s C text calls (0.291): malloc, realloc, free and abort of <stdlib.h>, the memory
   functions and strlen of <string.h>, snprintf of <stdio.h>; and the numbers of a text, which read errno and the
   limits -- macros, which a C text does not see, since it is lexed and never preprocessed. A number that is not
   there, or past the type's range, stops the program (abort), where C++'s std::stoi and its kin throw. A macro file's
   NAME.pl.h is included with it, so a program includes <string.pl> alone. */
#ifndef _CICILANG_CCLLIB_BASIC_STRING_PL_H
#define _CICILANG_CCLLIB_BASIC_STRING_PL_H
#include <errno.h>
#include <limits.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static inline long long ccllib_sto_signed_(const char *s, size_t *pos, int base, long long lo, long long hi) {
    char *end;
    int saved = errno;
    errno = 0;
    long long x = strtoll(s, &end, base);
    if (end == s || errno == ERANGE || x < lo || x > hi) abort();
    errno = saved;
    if (pos) *pos = (size_t)(end - s);
    return x;
}
static inline unsigned long long ccllib_sto_unsigned_(const char *s, size_t *pos, int base, unsigned long long hi) {
    char *end;
    int saved = errno;
    errno = 0;
    unsigned long long x = strtoull(s, &end, base);
    if (end == s || errno == ERANGE || x > hi) abort();
    errno = saved;
    if (pos) *pos = (size_t)(end - s);
    return x;
}
static inline int ccllib_stoi_(const char *s, size_t *pos, int base) {
    return (int)ccllib_sto_signed_(s, pos, base, INT_MIN, INT_MAX);
}
static inline long ccllib_stol_(const char *s, size_t *pos, int base) {
    return (long)ccllib_sto_signed_(s, pos, base, LONG_MIN, LONG_MAX);
}
static inline long long ccllib_stoll_(const char *s, size_t *pos, int base) {
    return ccllib_sto_signed_(s, pos, base, LLONG_MIN, LLONG_MAX);
}
static inline unsigned long ccllib_stoul_(const char *s, size_t *pos, int base) {
    return (unsigned long)ccllib_sto_unsigned_(s, pos, base, ULONG_MAX);
}
static inline unsigned long long ccllib_stoull_(const char *s, size_t *pos, int base) {
    return ccllib_sto_unsigned_(s, pos, base, ULLONG_MAX);
}
static inline float ccllib_stof_(const char *s, size_t *pos) {
    char *end;
    int saved = errno;
    errno = 0;
    float x = strtof(s, &end);
    if (end == s || errno == ERANGE) abort();
    errno = saved;
    if (pos) *pos = (size_t)(end - s);
    return x;
}
static inline double ccllib_stod_(const char *s, size_t *pos) {
    char *end;
    int saved = errno;
    errno = 0;
    double x = strtod(s, &end);
    if (end == s || errno == ERANGE) abort();
    errno = saved;
    if (pos) *pos = (size_t)(end - s);
    return x;
}
static inline long double ccllib_stold_(const char *s, size_t *pos) {
    char *end;
    int saved = errno;
    errno = 0;
    long double x = strtold(s, &end);
    if (end == s || errno == ERANGE) abort();
    errno = saved;
    if (pos) *pos = (size_t)(end - s);
    return x;
}
#endif
