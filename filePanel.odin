package main


import "core:fmt"
import "core:mem"
import "core:os"
import "core:path/filepath"
import rl "vendor:raylib"

initFilePanel :: proc(panel: ^FilePanel) {
	panel.font = rl.LoadFontEx(
		"JetBrainsMono-2.304/fonts/ttf/JetBrainsMono-Regular.ttf",
		15,
		nil,
		0,
	)

	panel.rune_index = 0
	panel.fontSize = 15
	charSpacing := f32(2)
	charSize := rl.MeasureTextEx(panel.font, "A", panel.fontSize, charSpacing)
	panel.charWidth = charSize.x
	panel.charHeight = charSize.y
	panel.charColumns = 40

	fmt.print("loaded file panel \n")
}


drawFilePanel :: proc(panel: ^FilePanel, app: ^App) {
	rect := rl.Rectangle {
		x      = panel.topLeft.x,
		y      = panel.topLeft.y,
		width  = panel.bottomRight.x - panel.topLeft.x,
		height = panel.bottomRight.y - panel.topLeft.y,
	}

	rl.DrawRectangleRec(rect, rl.Fade(rl.BEIGE, 0.1))

	// 1. Grab the current mouse coordinates
	mousePos := rl.GetMousePosition()

	// Reset hover state at the start of the frame.
	// If the mouse isn't over any file, it stays -1.
	panel.hoverIndex = -1


	currentCol: i32 = 0 // keeps track of the exact character coord
	currentRow: i32 = 0 // keeps track of the exact character coord
	currentCharIndex := 0
	appendStartCount := 0
	tempChar: rune

	// idx is an Odin feature
	for info, idx in panel.directoryList {

		// 2. Define a bounding box for the ENTIRE row width
		rowRect := rl.Rectangle {
			x      = panel.topLeft.x,
			y      = panel.topLeft.y + (f32(idx) * panel.charHeight),
			width  = rect.width,
			height = panel.charHeight,
		}

		// 3. Check if the mouse cursor is inside this specific row's box
		if rl.CheckCollisionPointRec(mousePos, rowRect) {
			panel.hoverIndex = i32(idx) // Store the row number!

			// Draw a subtle background highlight for the hovered file row
			rl.DrawRectangleRec(rowRect, rl.Fade(rl.SKYBLUE, 0.3))
		}

		currentCol = 0
		currentCharIndex = 0
		appendStartCount = 0

		for {
			if currentCol >= panel.charColumns {break}
			if currentCharIndex >= len(info.name) {break}

			pos := rl.Vector2 {
				f32(currentCol) * panel.charWidth + panel.topLeft.x,
				f32(currentRow) * panel.charHeight + panel.topLeft.y,
			}

			if appendStartCount < 3 {
				if appendStartCount == 0 {
					if info.type == .Directory {
						tempChar = 'D'
					} else {
						tempChar = 'F'
					}
				}

				if appendStartCount == 1 {
					tempChar = ':'
				}

				if appendStartCount == 2 {
					tempChar = ' '
				}

				currentCharIndex -= 1

			} else {
				tempChar = rune(info.name[currentCharIndex])
			}

			if tempChar != 0 {
				rl.DrawTextCodepoint(panel.font, tempChar, pos, panel.fontSize, rl.WHITE)
			}

			currentCol += 1
			currentCharIndex += 1
			appendStartCount += 1
		}

		currentRow += 1
	}
}


loadDirectory :: proc(filePath: string, panel: ^FilePanel) {
	infos, err := os.read_directory_by_path(filePath, 0, context.allocator)
	if err != 0 {
		fmt.eprintln("Error reading directory:", filePath)
		return
	}
	defer os.file_info_slice_delete(infos, context.allocator)

	// Free the old list before replacing it
	for i in 0 ..< panel.directoryCount {
		os.file_info_delete(panel.directoryList[i], context.allocator)
	}

	// Zero out all slots so no stale data remains
	panel.directoryList = {}
	panel.directoryCount = 0

	// Update path buffers
	mem.zero_slice(panel.currentPath[:])
	mem.zero_slice(panel.parentPath[:])
	copy_from_string(panel.currentPath[:], filePath)
	parent := filepath.dir(filePath)
	copy_from_string(panel.parentPath[:], parent)

	// ".." entry at index 0
	panel.directoryList[0] = os.File_Info {
		name = "..",
		type = .Directory,
	}

	// Deep copy each real entry into slots 1..n
	count := min(len(infos), 99)
	for i in 0 ..< count {
		panel.directoryList[i + 1], _ = os.file_info_clone(infos[i], context.allocator)
	}
	panel.directoryCount = count + 1
}
