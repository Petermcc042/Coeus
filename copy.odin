package main

import "core:fmt"
import "core:strings"
import "core:unicode/utf8"
import rl "vendor:raylib"

copy_runes_to_clipboard :: proc(runes: []rune) {
	// Single allocation: runes -> utf8 string
	fmt.print("copying")
	str := utf8.runes_to_string(runes)
	defer delete(str)

	// clone_to_cstring is unavoidable — Raylib needs a cstring
	cstr := strings.clone_to_cstring(str)
	defer delete(cstr)

	rl.SetClipboardText(cstr)
}
