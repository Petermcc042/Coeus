package main

import "core:fmt"
import "core:os"
import "core:thread"

initFileLoadInfo :: proc(info: ^FileLoadingInfo) {
	info.fileLoadingUnderway = false
	info.fileLoaded = false

	// tracking for counting rune thread
	info.runeCountNeedsStarted = false
	info.runeCountThread = nil
	info.runeCountThreadActive = false
	info.runeCountThreadComplete = false

	info.fileLoadNeedsStarted = false // used to begin the thread to load the current file
	info.fileLoadSuccess = false // were there any errors in the file load thread
	info.fileLoadThreadActive = false
	info.fileLoadThreadComplete = false

	// step 4: process column info ^ todo: move to step 1
	info.fileProcessingNeedsStarted = false // used to begin the column and row count proc
}

fileLoadingLogic :: proc(view: ^CellsView, info: ^FileLoadingInfo) {

	if !info.fileLoadingUnderway {return}

	// 1. find length of file
	if info.runeCountNeedsStarted {
		startRuneCountThread(view, info)
		info.runeCountNeedsStarted = false
	}

	pollRuneCountThread(info, view)

	// 2. create array
	if info.runeArrayNeedsInitialised {
		delete(view.fileRunes, context.allocator)
		view.fileRunes = make([]rune, view.fileNumRunes)
		info.runeArrayNeedsInitialised = false
		info.fileLoadNeedsStarted = true
		fmt.println("Rune array initialised!")
	}

	// 3. load file using fixed array
	if info.fileLoadNeedsStarted {
		fmt.println("Starting Loading Thread!")
		startLoadFileThread(info, view)
		info.fileLoadNeedsStarted = false
	}

	pollFileLoadThread(view, info)

	if info.fileProcessingNeedsStarted {
		process_csv(view)
		info.fileLoaded = true
		info.fileProcessingNeedsStarted = false
		info.fileLoadingUnderway = false

		fmt.printfln("file processed")
	}
}


startLoadFileThread :: proc(info: ^FileLoadingInfo, view: ^CellsView) {
	if !info.fileLoadThreadActive {
		info.fileLoadThreadComplete = false
		info.fileLoadThread = thread.create(fileLoadWorker)
		if info.fileLoadThread != nil {
			info.fileLoadThread.data = view
			thread.start(info.fileLoadThread)
			info.fileLoadThreadActive = true
		}
	}
}

pollFileLoadThread :: proc(view: ^CellsView, info: ^FileLoadingInfo) {
	// this section is only for tracking and cleaning an active thread
	// it is not about starting the thread
	if info.fileLoadThreadActive && info.fileLoadThread != nil {
		// This call checks atomic state registers non-blockingly!
		if thread.is_done(info.fileLoadThread) {

			// Clean up the thread resources completely
			thread.join(info.fileLoadThread)
			thread.destroy(info.fileLoadThread)
			info.fileLoadThread = nil

			info.fileLoadThreadActive = false
			info.fileLoadThreadComplete = true

			info.fileProcessingNeedsStarted = true
			fmt.println("File Load Thread finished execution safely!")
		}
	}
}

fileLoadWorker :: proc(t: ^thread.Thread) {
	view := cast(^CellsView)t.data

	data, err := os.read_entire_file_from_path(view.fileCurrentPath, context.allocator)
	if err != nil {
		// You can print the specific error (e.g., 'File Not Found')
		fmt.eprintfln("Error reading file %s: %v", view.fileCurrentPath, err)
		//view.fileLoadSuccess = false
		return
	}
	defer delete(data, context.allocator)

	// 2. Clear existing text
	// delete(&view.fileChars)

	// 3. Convert UTF-8 bytes to runes
	// This handles multi-byte characters correctly for DrawTextCodepoint
	str_data := string(data)

	temp_count: i32 = 0
	rowStartIndex: i32 = 0

	for r in str_data {
		if r == '\n' {
			append(&view.fileRowCharIndices, RowInfo{rowStartIndex, temp_count})
			rowStartIndex = temp_count + 1
		}

		//append(&view.fileChars, r)
		view.fileRunes[temp_count] = r
		temp_count += 1
	}

	//view.fileLoadSuccess = true
	fmt.printfln("loadded filleeeee")
}
