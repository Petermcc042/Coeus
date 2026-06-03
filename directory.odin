package main

import "core:fmt"
import "core:os"

// Recursively walks through directories and prints a visual tree
view_directory :: proc(dir_path: string, depth := 0) {
	// os.read_dir allocates a slice of File_Info structs
	infos, err := os.read_directory_by_path(dir_path, 0, context.allocator)
	if err != 0 {
		fmt.eprintln("Error reading directory:", dir_path)
		return
	}
	// CRITICAL: Clean up the allocated slice to prevent memory leaks!
	defer os.file_info_slice_delete(infos, context.allocator)

	for info in infos {
		// Create a scannable visual indentation based on tree depth
		for _ in 0 ..< depth {
			fmt.print("  ")
		}

		if info.type == .Directory {
			fmt.printf("📁 %s/\n", info.name)

			// Dive into the subdirectory using its absolute/working fullpath
			// view_directory(info.fullpath, depth + 1)
		} else {
			fmt.printf("📄 %s (%d bytes)\n", info.name, info.size)
		}
	}
}

testCWD :: proc() {
	target := "." // "." targets your current working directory
	fmt.printf("Scanning directory tree for: %s\n", target)
	view_directory(target)
}
