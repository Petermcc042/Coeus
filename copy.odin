package main

import "core:fmt"
import "core:strings"
import "core:unicode/utf8"
import rl "vendor:raylib"

copy_runes_to_clipboard :: proc(runes: []rune) {
	b: strings.Builder
	// 1. Use the standard heap allocator instead of the temporary one
	strings.builder_init(&b, context.allocator)
	// Defer cleanup so memory is freed the moment this function exits
	defer strings.builder_destroy(&b)

	for r in runes {
		if r == ',' {
			strings.write_rune(&b, '\t')
		} else {
			strings.write_rune(&b, r)
		}
	}

	// 2. ZERO-COPY TRICK: Explicitly append a C null-terminator to the end
	strings.write_byte(&b, 0)

	// Extract the raw string data
	utf8_str := strings.to_string(b)

	// Cast the underlying byte pointer directly to a cstring.
	// Because we added the '0' byte above, this is completely safe and requires 0 bytes of extra memory.
	c_str := cstring(raw_data(utf8_str))

	// 3. Hand it to Raylib. Raylib/OS will clone this data into system memory.
	rl.SetClipboardText(c_str)

	// 4. Function ends here: 'defer' triggers and clears the heap memory instantly.
}
