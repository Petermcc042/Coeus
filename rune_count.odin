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

	fd, errno := os.open(view.fileCurrentPath, os.O_RDONLY)
	if errno != 0 {
		fmt.eprintfln("Error opening file %s: %v", view.fileCurrentPath, errno)
		view.fileNumRunes = 0
		view.runeCountSuccess = false
		return
	}
	defer os.close(fd)

	// 2. Turn the file handle into an io.Stream
	stream := os.to_stream(fd)

	// 3. Initialize the buffered reader using the stream
	b_reader: bufio.Reader
	bufio.reader_init(&b_reader, stream)
	defer bufio.reader_destroy(&b_reader)

	rune_count := 0

	// 4. Stream and read runes directly
	for {
		rn, size, err := bufio.reader_read_rune(&b_reader)
		if err != nil {
			if err == .EOF {
				break // Reached end of file safely
			}
			fmt.eprintfln("Error reading UTF-8 data: %v", err)
			view.fileNumRunes = 0
			view.runeCountSuccess = false
			return
		}
		rune_count += 1
	}

	view.fileNumRunes = i32(rune_count)
	view.runeCountSuccess = true
}
