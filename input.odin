package main

import "core:fmt"
import "core:math"
import "core:strings"
import rl "vendor:raylib"

// Configuration
DOUBLE_CLICK_THRESHOLD :: 0.25 // Time in seconds

// State tracking
lastClickTiming: f64 = 0.0
doubleClick := false

process_user_input :: proc(
	app: ^App,
	cellsView: ^CellsView,
	panel: ^FilePanel,
	info: ^FileLoadingInfo,
	view: ^CellsView,
) {
	m_pos := rl.GetMousePosition()

	// Calculate tile based on pixel / cell size directly
	mouse_x := i32(m_pos.x / cellsView.charWidth)
	mouse_y := i32(m_pos.y / cellsView.charHeight)

	m_worl_pos := mouse_y * cellsView.charColumns + mouse_x

	// 2. Find the CSV column index
	currentFieldNum := -1
	accumulated_chars: i32 = 0


	for width, index in cellsView.fieldRenderWidths {
		accumulated_chars += width
		if mouse_x < accumulated_chars {
			currentFieldNum = index
			break
		}
	}

	// Clamp to current grid bounds
	mouse_x = clamp(mouse_x, 0, cellsView.charColumns - 1)
	mouse_y = clamp(mouse_y, 0, cellsView.charRows - 1)

	if rl.IsKeyPressed(.ENTER) {
		info.fileLoadingUnderway = true
		info.runeCountNeedsStarted = true
	}

	if rl.IsKeyPressed(.EQUAL) && rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyPressed(.KP_ADD) {
		update_text_size(true, cellsView)
	}

	if rl.IsKeyPressed(.MINUS) && rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyPressed(.KP_SUBTRACT) {
		update_text_size(false, cellsView)
	}

	if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.C) {
		copy_runes_to_clipboard(cellsView.fileRunes)
	}

	if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.B) {
		fmt.print("close panel")
		if panel.charColumns == 0 {panel.charColumns = 40} else {panel.charColumns = 0}
		app.resizeNeeded = true
	}

	// If the user clicks left mouse button AND the mouse is over a valid row
	if rl.IsMouseButtonPressed(.LEFT) && panel.hoverIndex != -1 {

		panel.currentFileIndex = panel.hoverIndex

		// Safely extract the exact file info struct from your array
		targetFile := panel.directoryList[panel.hoverIndex]

		fmt.printfln(
			"User clicked on: %s index: %i path: %s",
			targetFile.name,
			panel.hoverIndex,
			targetFile.fullpath,
		)

		if targetFile.type == .Directory {
			loadDirectory(targetFile.fullpath, panel)

		} else {
			if strings.has_suffix(targetFile.fullpath, ".csv") {
				cellsView.fileCurrentPath = targetFile.fullpath
				resetFileLoading(view, info)
			}

			//load_file_content(targetFile.fullpath)
		}
	}


	scroll := rl.GetMouseWheelMove()

	if scroll != 0 {
		if (rl.IsKeyDown(.LEFT_SHIFT)) {
			//do nothing
		} else {
			// Adjust how fast a single wheel tick scrolls.
			// e.g., 'row_delta * 3' would scroll 3 rows per notch.
			row_delta := i32(scroll * -1) * 3

			cellsView.currentFileRow = math.max(cellsView.currentFileRow + row_delta, 0)
		}
	}

	doubleClick = false
	if rl.IsMouseButtonPressed(.LEFT) {
		currentTime := rl.GetTime()
		timePassed := currentTime - lastClickTiming

		if timePassed < DOUBLE_CLICK_THRESHOLD {
			// Reset last_click_time to 0 so a fast 3rd click
			// doesn't register as a second double-click
			doubleClick = true
			lastClickTiming = 0.0
		} else {
			// Just a normal single click (or first click of a potential double)
			lastClickTiming = currentTime
		}
	}

	app.left_mouse_clicked = rl.IsMouseButtonDown(.LEFT)
	app.right_mouse_clicked = rl.IsMouseButtonDown(.RIGHT)
	app.toggle_pause = rl.IsKeyPressed(.SPACE)
	app.mouse_world_position = mouse_y * cellsView.charColumns + mouse_x
	app.mouse_charBlock_x = mouse_x
	app.mouse_charBlock_y = mouse_y
	app.mouse_fieldNum = i32(currentFieldNum)
	app.doubleClick = doubleClick
}
