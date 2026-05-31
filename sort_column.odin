package main

import "core:fmt"
import "core:sort"

// A helper struct to match a row's starting position with its sorting key
SortEntry :: struct {
	row_index: i32,
	key:       []rune, // Points directly inside cellsView.fileRunes (zero-allocation)
}

sortColumn :: proc(cellsView: ^CellsView, fieldNum: i32) {
	if len(cellsView.fileRowCharIndices) == 0 do return

	// 1. Allocate a temporary slice to hold our sorting entries
	// len() - 1 because the last entry is the last '\n' in the file
	entries := make([]SortEntry, len(cellsView.fileRowCharIndices) - 1, context.allocator)
	defer delete(entries)


	// 2. Extract the sorting key for each row
	for i := 0; i < len(cellsView.fileRowCharIndices); i += 1 {
		rowStart := cellsView.fileRowCharIndices[i]
		rowEnd: i32
		fmt.print("index: ", i, "len: ", len(cellsView.fileRowCharIndices), "\n")

		if i + 1 >= len(cellsView.fileRowCharIndices) {
			continue
		} else {
			rowEnd = cellsView.fileRowCharIndices[i + 1]
		}

		// fmt.print(cellsView.fileRunes[rowStart:rowEnd], "\n")
		// fmt.print("Sorting for column: ", fieldNum, "\n")
		currentField: i32 = 0
		startIndex := 0
		endIndex := 0
		inQuotes := false
		indexCount := 0

		for rune in cellsView.fileRunes[rowStart:rowEnd] {
			if rune == '\r' {
				continue
			}


			if rune == '"' {
				if inQuotes {
					inQuotes = false
				} else {
					inQuotes = true
				}
			}


			if (rune == ',' && inQuotes == false) || rune == '\n' {
				if currentField == fieldNum {
					endIndex = indexCount
					//fmt.print(cellsView.fileRunes[rowStart:rowEnd][startIndex:endIndex], "\n")
					break
				}
				currentField += 1
				startIndex = indexCount + 1
			}

			indexCount += 1

		}

		// Store the index alongside its key
		entries[i] = SortEntry {
			row_index = rowStart,
			key       = cellsView.fileRunes[rowStart:rowEnd][startIndex:endIndex],
		}
	}

	// 3. Sort the entries based on their rune slices alphabetically
	// 3. Sort the entries using a 3-way integer comparison
	sort.quick_sort_proc(entries, sortCell)

	// Verify the result
	// for entry in entries {
	// 	fmt.printf("Row: %d, Key: %s\n", entry.row_index, entry.key)
	// }

	// // 4. Repopulate your original index array with the newly sorted layout
	for i := 0; i < len(entries); i += 1 {
		cellsView.fileRowCharIndices[i] = entries[i].row_index
	}

	// for rowIndex in cellsView.fileRowCharIndices {
	// 	fmt.print(rowIndex, "\n")
	// }
}


sortCell :: proc(a, b: SortEntry) -> int {
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
}
