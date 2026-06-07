package main

import "core:fmt"
import "core:os"
import "core:thread"


pollRuneCountThread :: proc(info: ^FileLoadingInfo, view: ^CellsView) {
	// this section is only for tracking and cleaning an active thread
	// it is not about starting the thread
	if info.runeCountThreadActive && info.runeCountThread != nil {
		// This call checks atomic state registers non-blockingly!
		if thread.is_done(info.runeCountThread) {

			// Clean up the thread resources completely
			thread.join(info.runeCountThread)
			thread.destroy(info.runeCountThread)
			info.runeCountThread = nil

			info.runeCountThreadActive = false
			info.runeCountThreadComplete = true
			info.runeArrayNeedsInitialised = true
			fmt.println("1. Count Thread finished execution safely!")
			fmt.printfln("1. File Read Rune Count: %i", view.fileNumRunes)
		}
	}
}


startRuneCountThread :: proc(view: ^CellsView, info: ^FileLoadingInfo) {
	fmt.println("1. start rune count proc")
	if info.fileLoadingUnderway && !info.runeCountThreadActive {
		info.runeCountThreadComplete = false
		info.runeCountThread = thread.create(countRunesWorker)
		if info.runeCountThread != nil {
			info.runeCountThread.data = view
			thread.start(info.runeCountThread)
			info.runeCountThreadActive = true
		}
	}
}

countRunesWorker :: proc(t: ^thread.Thread) {
	fmt.println("1. in thread now:")

	view := cast(^CellsView)t.data

	// 1. Slurp the entire file into memory
	data, err := os.read_entire_file_from_path(view.fileCurrentPath, context.allocator)
	if err != nil {
		fmt.eprintfln("1. Error reading file %s: %v", view.fileCurrentPath, err)
		return
	}

	file_str := string(data)
	rune_count: i32 = 0
	rowCount: i32 = 0
	fieldCount: i32 = 0
	inQuotes := false

	// Trackers for the current field being processed
	current_field_idx := 0
	current_field_len := 0

	// Clear any existing data if this dynamic array is reused
	clear(&view.fieldRenderWidths)

	for rune in file_str {
		if rune == '\r' {
			rune_count += 1
			continue
		}

		if rune == '"' {
			inQuotes = !inQuotes
			// Optional: If you don't want the quote characters to count
			// toward the render width, uncomment the next two lines:
			// rune_count += 1
			// continue
		}

		// Check for field boundaries (comma outside quotes, or a newline)
		if (rune == ',' && !inQuotes) || rune == '\n' {

			// 1. Cap the field width at 15
			if current_field_len > 20 {
				current_field_len = 20
			}

			// 2. Store or update the max width
			if rowCount == 0 {
				// First row: Discovering columns, grow the array naturally
				append(&view.fieldRenderWidths, i32(current_field_len))
				fieldCount += 1
			} else {
				// Subsequent rows: Array size is locked, update in-place
				if current_field_idx < len(view.fieldRenderWidths) {
					view.fieldRenderWidths[current_field_idx] = max(
						view.fieldRenderWidths[current_field_idx],
						i32(current_field_len),
					)
				}
			}

			// Reset field length for the next field
			current_field_len = 0
			current_field_idx += 1

			if rune == '\n' {
				rowCount += 1
				current_field_idx = 0 // Reset to the first column for the new row
			}
		} else {
			// Increment the character count for the current field content
			// (Excluding the delimiter itself)
			current_field_len += 1
		}

		rune_count += 1
	}

	// Flush the very last field if the file doesn't end with a trailing newline
	if current_field_len > 0 {
		if current_field_len > 15 {current_field_len = 15}
		if rowCount == 0 {
			append(&view.fieldRenderWidths, i32(current_field_len))
			fieldCount += 1
		} else if current_field_idx < len(view.fieldRenderWidths) {
			view.fieldRenderWidths[current_field_idx] = max(
				view.fieldRenderWidths[current_field_idx],
				i32(current_field_len),
			)
		}
	}

	delete(data, context.allocator)

	view.fileNumRunes = rune_count
	view.fileNumRows = rowCount
	view.fileNumFields = fieldCount
}
