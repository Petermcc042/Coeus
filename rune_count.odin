package main

import "core:bufio"
import "core:fmt"
import "core:io"
import "core:os"
import "core:thread"


pollRuneCountThread :: proc(view: ^CellsView) {
	// this section is only for tracking and cleaning an active thread
	// it is not about starting the thread
	if view.runeCountThreadActive && view.runeCountThread != nil {
		// This call checks atomic state registers non-blockingly!
		if thread.is_done(view.runeCountThread) {

			// Clean up the thread resources completely
			thread.join(view.runeCountThread)
			thread.destroy(view.runeCountThread)
			view.runeCountThread = nil

			view.runeCountThreadActive = false
			view.runeCountThreadComplete = true
			view.runeArrayNeedsInitialised = true
			fmt.println("Thread finished execution safely!")
			fmt.printfln("%d", view.fileNumRunes)
		}
	}
}


startRuneCountThread :: proc(view: ^CellsView) {

	if view.fileLoadingUnderway && !view.runeCountThreadActive {
		view.runeCountThreadComplete = false
		view.runeCountThread = thread.create(countRunesWorker)
		if view.runeCountThread != nil {
			view.runeCountThread.data = view
			thread.start(view.runeCountThread)
			view.runeCountThreadActive = true
		}
	}
}

countRunesWorker :: proc(t: ^thread.Thread) {
	view := cast(^CellsView)t.data

	// 1. Slurp the entire file into memory
	data, err := os.read_entire_file_from_path(view.fileCurrentPath, context.allocator)
	if err != nil {
		// You can print the specific error (e.g., 'File Not Found')
		fmt.eprintfln("Error reading file %s: %v", view.fileCurrentPath, err)
		view.fileLoadSuccess = false
		return
	}

	// 2. Convert bytes to a string and let Odin count the runes
	file_str := string(data)
	rune_count := 0

	// In Odin, looping over a string automatically decodes it rune-by-rune!
	for _ in file_str {
		rune_count += 1
	}

	delete(data, context.allocator)

	view.fileNumRunes = i32(rune_count)
	view.runeCountSuccess = true
}
