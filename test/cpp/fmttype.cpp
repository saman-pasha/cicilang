// A TYPE THE FORMATTER DOES NOT TAKE (0.164): `x' for a floating-point argument, refused at compile time where the
// check reaches the library's __throw_invalid_type_format_error, as clang++ refuses it
#include <format>
#include <string>
std::string hex() { return std::format("{:x}", 1.5); }
