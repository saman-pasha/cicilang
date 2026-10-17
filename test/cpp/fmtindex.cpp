// A FORMAT STRING THAT NAMES AN ARGUMENT THE CALL DOES NOT HAVE (0.164): basic_format_string's consteval constructor,
// run at compile time, reaches __throw_format_error, and the program is refused with the library's message, as
// clang++ refuses it
#include <format>
#include <string>
std::string two() { return std::format("{} {}", 1); }
