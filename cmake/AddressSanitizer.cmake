add_compile_options("$<$<COMPILE_LANGUAGE:C++>:-fsanitize=address>")
add_link_options("$<$<COMPILE_LANGUAGE:C++>:-fsanitize=address>")

add_compile_options("$<$<COMPILE_LANGUAGE:Swift>:-sanitize=address>")
add_link_options("$<$<COMPILE_LANGUAGE:Swift>:-sanitize=address>")
