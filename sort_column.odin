package main

import "core:fmt"
import "core:sort"

// A helper struct to match a row's starting position with its sorting key
SortEntry :: struct {
	rowStartIndex: i32,
	rowEndIndex:   i32,
	key:           []rune, // Points directly inside cellsView.fileRunes (zero-allocation)
}

sortColumn :: proc(cellsView: ^CellsView, fieldNum: i32) {
	if len(cellsView.fileRowCharIndices) == 0 do return

	entries := make([]SortEntry, len(cellsView.fileRowCharIndices), context.allocator)
	defer delete(entries)


	// 2. Extract the sorting key for each row
	for i := 0; i < len(cellsView.fileRowCharIndices); i += 1 {
		rowStart := cellsView.fileRowCharIndices[i].rowStartIndex
		rowEnd := cellsView.fileRowCharIndices[i].rowEndIndex
		// fmt.print("index: ", i, "len: ", len(cellsView.fileRowCharIndices), "\n")

		//fmt.print(cellsView.fileRunes[rowStart:rowEnd], "\n")
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
			rowStartIndex = rowStart,
			rowEndIndex   = rowEnd,
			key           = cellsView.fileRunes[rowStart:rowEnd][startIndex:endIndex],
		}
	}

	// 3. Sort the entries based on their rune slices alphabetically
	// 3. Sort the entries using a 3-way integer comparison
	sort.quick_sort_proc(entries, sortCell)

	// Verify the result
	for entry in entries {
		//fmt.printf("Row: %d, Key: %s\n", entry.rowStartIndex, entry.key)
	}

	// // 4. Repopulate your original index array with the newly sorted layout
	for i := 0; i < len(entries); i += 1 {
		cellsView.fileRowCharIndices[i].rowStartIndex = entries[i].rowStartIndex
		cellsView.fileRowCharIndices[i].rowEndIndex = entries[i].rowEndIndex
	}

	for rowIndex in cellsView.fileRowCharIndices {
		//fmt.print(rowIndex, "\n")
	}
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
