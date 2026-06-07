package main

import "core:fmt"
import "core:os"
import "core:strings"

main :: proc() {
	// Open the current directory (.)
	handle, err := os.open(".")
	if err != os.ERROR_NONE {
		fmt.eprintln("Error opening directory:", err)
		return
	}
	defer os.close(handle)

	// Read all file infos from the directory
	file_infos, read_err := os.read_dir(handle, -1, context.allocator)
	if read_err != os.ERROR_NONE {
		fmt.eprintln("Error reading directory:", read_err)
		return
	}
	defer delete(file_infos)

	total_lines := 0
	total_files := 0

	for info in file_infos {
		// Skip directories and ensure it ends with ".odin"
		if info.type == .Directory || !strings.has_suffix(info.name, ".odin") {
			continue
		}

		// Read the entire file content
		data, success := os.read_entire_file_from_path(info.fullpath, context.allocator)
		if success != nil {
			fmt.eprintf("Failed to read file: %s\n", info.name)
			continue
		}
		defer delete(data)

		// Convert bytes to a string and count the lines
		content := string(data)
		file_lines := count_lines(content)

		fmt.printf("%-30s : %d lines\n", info.name, file_lines)
		total_lines += file_lines
		total_files += 1
	}

	fmt.println("------------------------------------------------")
	fmt.printf("Total: %d lines across %d .odin files.\n", total_lines, total_files)
}

// Helper function to count lines by splitting on newlines
count_lines :: proc(content: string) -> int {
	if len(content) == 0 {
		return 0
	}

	count := 0
	// Iterate through the string line by line
	it := content
	for _ in strings.split_lines_iterator(&it) {
		count += 1
	}
	return count
}
