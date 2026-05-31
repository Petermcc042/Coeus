package main

import "core:fmt"
import rl "vendor:raylib"

initCellsView :: proc(view: ^CellsView, fontSize: f32) {
	// tracking for counting rune thread
	view.runeCountNeedsStarted = false
	view.runeCountThread = nil
	view.fileNumRunes = 0
	view.fileCurrentPath = csv_file_name
	view.runeCountThreadActive = false
	view.runeCountThreadComplete = false

	view.colors = []rl.Color{rl.BLUE, rl.SKYBLUE}
	view.fileLoadingUnderway = false
	view.preprocessed = false
	view.currentFileRow = 0
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


render_csv :: proc(cellsView: ^CellsView) {
	//rl.ClearBackground(rl.DARKBLUE)
	rect := rl.Rectangle {
		x      = 0,
		y      = cellsView.topLeft.y,
		width  = cellsView.bottomRight.x - cellsView.topLeft.x,
		height = cellsView.bottomRight.y - cellsView.topLeft.y,
	}

	rl.DrawRectangleRec(rect, rl.Fade(rl.BLUE, 0.2))


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
	fileCharIndex = cellsView.fileRowCharIndices[cellsView.currentFileRow].rowStartIndex

	for i in 0 ..< i32(len(cellsView.fileRowCharIndices)) {
		if i > cellsView.charRows {break}

		fileCharIndex = cellsView.fileRowCharIndices[i].rowStartIndex
		for {
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
				f32(currentCol) * cellsView.charWidth,
				f32(currentRow) * cellsView.charHeight,
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


	cumulativeCharWidth: i32 = 0
	for charWidth in cellsView.fieldRenderWidths {
		cumulativeCharWidth += charWidth
		rl.DrawLine(
			i32(cellsView.charWidth) * cumulativeCharWidth,
			0,
			i32(cellsView.charWidth) * cumulativeCharWidth,
			rl.GetScreenHeight(),
			rl.WHITE,
		)
	}

	rl.DrawLine(
		0,
		i32(cellsView.charHeight),
		rl.GetScreenWidth(),
		i32(cellsView.charHeight),
		rl.WHITE,
	)
}
