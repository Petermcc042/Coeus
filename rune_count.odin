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
		// You can print the specific error (e.g., 'File Not Found')
		fmt.eprintfln("1. Error reading file %s: %v", view.fileCurrentPath, err)
		//view.fileLoadSuccess = false
		return
	}

	// 2. Convert bytes to a string and let Odin count the runes
	file_str := string(data)
	rune_count: i32 = 0
	rowCount: i32 = 0
	fieldCount: i32 = 0
	inQuotes := false

	// In Odin, looping over a string automatically decodes it rune-by-rune!
	for rune in file_str {
		if rune == '\r' {
			rune_count += 1
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

			if rowCount < 1 {
				fieldCount += 1
			}


			if rune == '\n' {
				rowCount += 1
			}
		}

		rune_count += 1
	}

	delete(data, context.allocator)

	view.fileNumRunes = rune_count
	view.fileNumRows = rowCount
	view.fileNumFields = fieldCount
	//view.runeCountSuccess = true

}
