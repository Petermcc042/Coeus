package main

import "core:strings"
import "vendor:sdl2"

copy_runes_to_spreadsheet_clipboard :: proc(runes: []rune) {
	// 1. Initialize a string builder using the temporary allocator
	b: strings.Builder
	strings.builder_init(&b, context.temp_allocator)

	for r in runes {
		switch r {
		case ',':
			// Swap commas out for tabs so Google Sheets auto-formats cells
			strings.write_rune(&b, '\t')
		case:
			// Automatically encodes the 32-bit rune into 1-4 UTF-8 bytes
			strings.write_rune(&b, r)
		}
	}

	// 2. Extract the string and clone it into a null-terminated cstring
	utf8_str := strings.to_string(b)
	c_str := strings.clone_to_cstring(utf8_str, context.temp_allocator)

	// 3. Hand off the UTF-8 C-string to the OS clipboard via SDL2
	sdl2.SetClipboardText(c_str)
}

main :: proc() {
	// Initialize your cross-platform windowing/input backend
	sdl2.Init({.VIDEO})
	defer sdl2.Quit()

	// Example fixed array of runes representing: Name,Age\nAlice,30
	my_csv_runes := []rune {
		'N',
		'a',
		'm',
		'e',
		',',
		'A',
		'g',
		'e',
		'\n',
		'A',
		'l',
		'i',
		'c',
		'e',
		',',
		'3',
		'0',
	}

	copy_runes_to_spreadsheet_clipboard(my_csv_runes)

	// Everything allocated via context.temp_allocator is automatically freed
	// at the end of the execution block/frame depending on your main loop setup.
}
