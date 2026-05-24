package main

import "core:prof/spall"
import rl "vendor:raylib"

render_csv :: proc(cellsView: ^CellsView) {
	rl.ClearBackground(rl.DARKBLUE)


	currentCol: i32 = 0 // keeps track of the exact character coord
	currentRow: i32 = 0 // keeps track of the exact character coord
	currentFieldIndex: i32 = 0 // keeps track of the exact character coord
	currentFieldCharIndex: i32 = 0 // keeps track of how many characters rendered per field
	fileCharIndex: i32 = 0 // keeps track of how far through the file we are
	inQuotes := false

	// loop until we have rendered all characters or
	// at least the screen cells are filled


	// find the row we are at
	// get the char index we want to start at
	// pass it instead of zero
	// be sure to render the header then skip to the row
	fileCharIndex = cellsView.fileRows[cellsView.currentFileRow]

	for fileCharIndex < i32(len(cellsView.fileRunes)) {

		if currentRow > cellsView.charRows {break}

		char := cellsView.fileRunes[fileCharIndex]
		temp_char := char // re-assign the char so we can fill empty cell spots with ' '

		// if we are in the first character of a new csv cell and it starts with a blank skip it
		if currentFieldCharIndex == 0 && char == ' ' {
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


		// If it's a newline, move the "pen" to the next row and reset column
		if char == '\n' || int(currentFieldIndex) >= len(cellsView.fieldWidths) {
			inQuotes = false
			currentCol = 0
			currentRow += 1
			currentFieldIndex = 0 // we are back to looking at the first field
			currentFieldCharIndex = 0 // reset the field index
			fileCharIndex += 1
			continue
		}

		// look at the current column we are in
		// get the width of it and if our current cell char index is greater than it we can move on
		//fmt.printfln("Character %s:  %v", char, currentColumnIndex)
		cell_is_filled: bool = (currentFieldCharIndex) >= cellsView.fieldWidths[currentFieldIndex]

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
			f32(currentCol) * cellsView.charBlock.width,
			f32(currentRow) * cellsView.charBlock.height,
		}

		if temp_char != 0 {
			rl.DrawTextCodepoint(cellsView.font, temp_char, pos, cellsView.fontSize, rl.WHITE)
		}

		currentCol += 1
		currentRow += 0
		currentFieldIndex += 0 // in a same word no need to change
		currentFieldCharIndex += 1 // move to the next cell (char count resets)
		fileCharIndex += 1 // try the next character
	}

	cumulativeCharWidth: i32 = 0
	for charWidth in cellsView.fieldWidths {
		cumulativeCharWidth += charWidth
		rl.DrawLine(
			i32(cellsView.charBlock.width) * cumulativeCharWidth,
			0,
			i32(cellsView.charBlock.width) * cumulativeCharWidth,
			rl.GetScreenHeight(),
			rl.WHITE,
		)
	}

	rl.DrawLine(
		0,
		i32(cellsView.charBlock.height),
		rl.GetScreenWidth(),
		i32(cellsView.charBlock.height),
		rl.WHITE,
	)
}
