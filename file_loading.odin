package main

import "core:fmt"
import "core:os"
import "core:thread"

startLoadFileThread :: proc(view: ^CellsView) {
	if !view.fileLoadThreadActive {
		view.fileLoadThreadComplete = false
		view.fileLoadThread = thread.create(fileLoadWorker)
		if view.fileLoadThread != nil {
			view.fileLoadThread.data = view
			thread.start(view.fileLoadThread)
			view.fileLoadThreadActive = true
		}
	}
}

pollFileLoadThread :: proc(view: ^CellsView) {
	// this section is only for tracking and cleaning an active thread
	// it is not about starting the thread
	if view.fileLoadThreadActive && view.fileLoadThread != nil {
		// This call checks atomic state registers non-blockingly!
		if thread.is_done(view.fileLoadThread) {

			// Clean up the thread resources completely
			thread.join(view.fileLoadThread)
			thread.destroy(view.fileLoadThread)
			view.fileLoadThread = nil

			view.fileLoadThreadActive = false
			view.fileLoadThreadComplete = true


			if view.fileLoadSuccess {
				view.fileProcessingNeedsStarted = true
			}
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
		view.fileLoadSuccess = false
		return
	}
	defer delete(data, context.allocator)

	// 2. Clear existing text
	//clear(&view.fileChars)

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

	view.fileLoadSuccess = true
	fmt.printfln("loadded filleeeee")
}
