package main

import "core:fmt"
import rl "vendor:raylib"

initCellsView :: proc(view: ^CellsView, fontSize: f32) {
	view.currentFileRow = 0
	view.fileNumRunes = 0
	view.containsHeader = true

	fmt.print("loaded cells view \n")

	loadCellViewFont(view, fontSize)
}

loadCellViewFont :: proc(view: ^CellsView, fontSize: f32) {
	view.font = rl.LoadFontEx(
		"JetBrainsMono-2.304/fonts/ttf/JetBrainsMono-Regular.ttf",
		i32(fontSize),
		nil,
		0,
	)
	view.fontSize = fontSize

	charSpacing := f32(6)
	charSize := rl.MeasureTextEx(view.font, "A", fontSize, charSpacing)
	view.charWidth = charSize.x
	view.charHeight = charSize.y

	fmt.print("loaded cells font \n")
}


renderCellsView :: proc(cellsView: ^CellsView, ui_state: ^ColumnState) {
	rl.DrawRectangleRec(cellsView.rect, rl.Fade(rl.BLUE, 0.2))


	currentCol: i32 = 0 // keeps track of the exact character coord
	currentRow: i32 = 0 // keeps track of the exact character coord
	currentFieldIndex: i32 = 0 // keeps track of the exact character coord
	currentFieldCharIndex: i32 = 0 // keeps track of how many characters rendered per field
	fileCharIndex: i32 = 0 // keeps track of how far through the file we are
	inQuotes := false

	// find the row we are at
	// get the char index we want to start at
	// pass it instead of zero
	// be sure to render the header then skip to the row


	for i in 0 ..< min(cellsView.charRows, cellsView.fileNumRows) {
		fileCharIndex = cellsView.fileRowCharIndices[cellsView.currentFileRow + i].rowStartIndex

		// this loop is to render one line now?
		for {

			// this section is just a hack to ensure the end of a file breaks the loop
			char: rune
			if fileCharIndex >= i32(len(cellsView.fileRunes)) {
				char = '\n'
			} else {
				char = cellsView.fileRunes[fileCharIndex]
			}

			temp_char := char // re-assign the char so we can fill empty cell spots with ' '

			if currentFieldCharIndex == 0 && char == ' ' {
				fileCharIndex += 1 // we move past the new line char to start fresh
				continue
			}

			// check for the other end line case where it is \r\n
			if char == '\r' {
				fileCharIndex += 1 // we move past the new line char to start fresh
				continue
			}

			// some fields have quotations to allow for commas in fields without destroying parsing
			// we need to account for the fact there could be additional commas not designed for splitting.
			if char == '"' {
				if inQuotes {
					inQuotes = false
					fileCharIndex += 1 // we move past the new line char to start fresh
					continue
				} else {
					inQuotes = true
					fileCharIndex += 1 // we move past the new line char to start fresh
					continue
				}

			}

			if char == '\n' || int(currentFieldIndex) >= len(cellsView.fieldRenderWidths) {
				inQuotes = false
				currentCol = 0
				currentRow += 1
				currentFieldIndex = 0 // we are back to looking at the first field
				currentFieldCharIndex = 0 // reset the field index
				fileCharIndex += 1
				break
			}

			// look at the current column we are in
			// get the width of it and if our current cell char index is greater than it we can move on
			//fmt.printfln("Character %s:  %v", char, currentColumnIndex)
			cell_is_filled: bool =
				(currentFieldCharIndex) >= cellsView.fieldRenderWidths[currentFieldIndex]

			// if we are looping through one cell contents and it is already filled
			// and we find a comma then it is time to move to the next cell
			if char == ',' && cell_is_filled && inQuotes == false {
				currentFieldIndex += 1 // we are back to looking at the first cell column
				currentFieldCharIndex = 0 // move to the next cell (char count resets)
				fileCharIndex += 1 // we move past the new line char to start fresh
				continue // no rendering required skip
			}

			// here we notice that even if the next character is a comma
			// but the cell isn't filled we need to fill the cell with a blank or something
			// we don't want to move past the comma though so we decrement the index to
			// stay on the commma character in the while loop
			if char == ',' && !cell_is_filled && inQuotes == false {
				temp_char = ' '
				fileCharIndex -= 1
			}

			if cell_is_filled {
				currentCol += 0
				currentRow += 0
				currentFieldIndex += 0 // we are back to looking at the first cell column
				currentFieldCharIndex += 0 // move to the next cell (char count resets)
				fileCharIndex += 1 // we move past the new line char to start fresh
				continue // no rendering required skip
			}

			pos := rl.Vector2 {
				f32(currentCol) * cellsView.charWidth + cellsView.topLeft.x,
				f32(currentRow) * cellsView.charHeight + cellsView.topLeft.y,
			}

			if temp_char != 0 {
				rl.DrawTextCodepoint(cellsView.font, temp_char, pos, cellsView.fontSize, rl.WHITE)
			}

			currentCol += 1
			currentRow += 0
			currentFieldIndex += 0
			currentFieldCharIndex += 1
			fileCharIndex += 1
		}
	}


	// 1. Handle active dragging if a column is already grabbed
	if ui_state.dragged_column != -1 {
		if rl.IsMouseButtonDown(.LEFT) {
			mouse_x := rl.GetMouseX()

			// Calculate the X coordinate of the *start* of the dragged column to find the delta
			col_start_x := i32(cellsView.topLeft.x)
			for i in 0 ..< ui_state.dragged_column {
				col_start_x += cellsView.fieldRenderWidths[i] * i32(cellsView.charWidth)
			}

			// Calculate new width based on mouse position
			new_width := (mouse_x - col_start_x) / i32(cellsView.charWidth)

			// Enforce a minimum width so columns don't vanish completely
			if new_width < 2 {new_width = 2}

			cellsView.fieldRenderWidths[ui_state.dragged_column] = new_width
			rl.SetMouseCursor(.RESIZE_EW)
		} else {
			// Mouse released
			ui_state.dragged_column = -1
		}
	}

	// 2. Render lines and check for new hovers/clicks
	ui_state.is_hovering_any = false
	mouse_pos := rl.GetMousePosition()
	cumulativeCharWidth: i32 = 0

	for charWidth, idx in cellsView.fieldRenderWidths {
		cumulativeCharWidth += charWidth

		line_x := i32(cellsView.charWidth) * cumulativeCharWidth + i32(cellsView.topLeft.x)
		top_y := i32(cellsView.topLeft.y)
		bot_y := i32(cellsView.bottomRight.y)

		// Render the column vertical line
		rl.DrawLine(line_x, top_y, line_x, bot_y, rl.WHITE)

		// Define a small invisible bounding box around the line for easier grabbing (e.g., 6 pixels wide)
		grab_padding :: 3
		line_rect := rl.Rectangle {
			x      = f32(line_x - grab_padding),
			y      = f32(top_y),
			width  = f32(grab_padding * 2),
			height = f32(bot_y - top_y),
		}

		// Check if mouse is over this specific line
		if rl.CheckCollisionPointRec(mouse_pos, line_rect) && ui_state.dragged_column == -1 {
			ui_state.is_hovering_any = true
			rl.SetMouseCursor(.RESIZE_EW)

			if rl.IsMouseButtonPressed(.LEFT) {
				ui_state.dragged_column = idx
			}
		}
	}

	// Reset cursor to default if we aren't hovering or dragging a line anymore
	if !ui_state.is_hovering_any && ui_state.dragged_column == -1 {
		rl.SetMouseCursor(.DEFAULT)
	}

	// Render your horizontal header line (unchanged)
	rl.DrawLine(
		0 + i32(cellsView.topLeft.x),
		i32(cellsView.charHeight) + i32(cellsView.topLeft.y),
		i32(cellsView.bottomRight.x),
		i32(cellsView.charHeight) + i32(cellsView.topLeft.y),
		rl.WHITE,
	)
}
