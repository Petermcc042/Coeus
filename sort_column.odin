package main

import "core:sort"

// A helper struct to match a row's starting position with its sorting key
SortEntry :: struct {
	row_index: i32,
	key:       []rune, // Points directly inside cellsView.fileRunes (zero-allocation)
}

sortColumn :: proc(cellsView: ^CellsView, fieldNum: i32) {
	if len(cellsView.fileRowCharIndices) == 0 do return

	// 1. Allocate a temporary slice to hold our sorting entries
	entries := make([]SortEntry, len(cellsView.fileRowCharIndices), context.temp_allocator)
	// No need to manually free if using context.temp_allocator,
	// otherwise use standard allocator and: defer delete(entries)

	// 2. Extract the sorting key for each row
	for i := 0; i < len(cellsView.fileRowCharIndices); i += 1 {
		row_start := cellsView.fileRowCharIndices[i]

		// Determine where this row ends (either the start of the next row, or EOF)
		row_end := i32(len(cellsView.fileRunes))
		if i + 1 < len(cellsView.fileRowCharIndices) {
			row_end = cellsView.fileRowCharIndices[i + 1]
		}

		// Clean up trailing newlines so they don't corrupt our last field
		for row_end > row_start {
			c := cellsView.fileRunes[row_end - 1]
			if c == '\n' || c == '\r' do row_end -= 1
			else do break
		}

		row_runes := cellsView.fileRunes[row_start:row_end]

		// Find the requested column (fieldNum) by splitting on commas
		field_start := 0
		current_field: i32 = 0
		key_slice: []rune = {}

		for idx := 0; idx <= len(row_runes); idx += 1 {
			// Check if we hit a delimiter or the end of the row
			if idx == len(row_runes) || row_runes[idx] == ',' {
				if current_field == fieldNum {
					key_slice = row_runes[field_start:idx]
					break
				}
				current_field += 1
				field_start = idx + 1
			}
		}

		// Store the index alongside its key
		entries[i] = SortEntry {
			row_index = row_start,
			key       = key_slice,
		}
	}

	// 3. Sort the entries based on their rune slices alphabetically
	// 3. Sort the entries using a 3-way integer comparison
	sort.quick_sort_proc(
		entries,
		proc(a, b: SortEntry) -> int {
			min_len := len(a.key) if len(a.key) < len(b.key) else len(b.key)

			// Compare rune by rune
			for i := 0; i < min_len; i += 1 {
				if a.key[i] < b.key[i] do return -1
				if a.key[i] > b.key[i] do return 1
			}

			// If they match up to min_len, the shorter one comes first
			if len(a.key) < len(b.key) do return -1
			if len(a.key) > len(b.key) do return 1

			return 0 // Completely identical
		},
	)

	// 4. Repopulate your original index array with the newly sorted layout
	for i := 0; i < len(entries); i += 1 {
		cellsView.fileRowCharIndices[i] = entries[i].row_index
	}
}
