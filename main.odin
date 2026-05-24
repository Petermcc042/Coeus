package main

import "core:fmt"
import "core:math"
import "core:thread"
import rl "vendor:raylib"


main :: proc() {

	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	window := Window{"Adaptive Avoidance", 1280, 720, 120}
	rl.InitWindow(window.width, window.height, window.name)
	// rl.SetTargetFPS(120)


	app: App


	// setup the text view data
	view := CellsView {
		colors              = []rl.Color{rl.BLUE, rl.SKYBLUE},
		fileLoadingUnderway = false,
		preprocessed        = false,
		currentFileRow      = 0,
	}

	load_font(&view, 20)
	defer delete(view.fileRunes)

	footer: Footer
	create_bottom_footer(&footer)

	// tracking for counting rune thread
	view.runeCountNeedsStarted = false
	view.runeCountThread = nil
	view.fileNumRunes = 0
	view.fileCurrentPath = csv_file_name
	view.runeCountThreadActive = false
	view.runeCountThreadComplete = false

	for !rl.WindowShouldClose() {
		update_loop(&view, view.charBlock, &app, &footer)
	}

	rl.UnloadFont(view.font)
	rl.CloseWindow()
}


update_loop :: proc(view: ^CellsView, charBlock: CharacterBlock, app: ^App, footer: ^Footer) {

	// 3. Check for Resize
	if rl.IsWindowResized() {
		update_app_dimensions(view)
	}
	process_user_input(app, view)

	fileLoadingLogic(view)

	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	// render backgrounds
	draw_cursor(app, charBlock)
	draw_bottom_footer(footer, app)

	if view.preprocessed {
		// render_csv profile scope is maintained inside its own proc,
		// or will nest cleanly here if it contains one
		render_csv(view)
	}

	update_cell_width(view, app)

	rl.EndDrawing()
}

fileLoadingLogic :: proc(view: ^CellsView) {

	if !view.fileLoadingUnderway {return}

	// 1. find length of file
	if view.runeCountNeedsStarted {
		startRuneCountThread(view)
		view.runeCountNeedsStarted = false
	}

	{
		pollRuneCountThread(view)
	}

	// 2. create array
	if view.runeArrayNeedsInitialised {
		if !view.runeCountSuccess {
			// do something here to show there was an error
		} else {
			view.fileRunes = make([]rune, view.fileNumRunes)
			view.runeArrayNeedsInitialised = false
			view.fileLoadNeedsStarted = true
		}
	}

	// 3. load file using fixed array
	if view.fileLoadNeedsStarted {
		startLoadFileThread(view)
		view.fileLoadNeedsStarted = false
	}

	{
		pollFileLoadThread(view)
	}

	if view.fileProcessingNeedsStarted {
		process_csv(view)
	}
}


load_font :: proc(cellsView: ^CellsView, fontSize: f32) {

	cellsView.font = rl.LoadFontEx(
		"JetBrainsMono-2.304/fonts/ttf/JetBrainsMono-Regular.ttf",
		cast(i32)fontSize,
		nil,
		0,
	)
	cellsView.fontSize = fontSize

	charSpacing := f32(6)
	charSize := rl.MeasureTextEx(cellsView.font, "A", cellsView.fontSize, charSpacing)

	cellsView.charBlock = CharacterBlock {
		width  = charSize.x,
		height = charSize.y,
	}

	update_app_dimensions(cellsView)
}

update_cell_width :: proc(cellsView: ^CellsView, app: ^App) {

	if rl.IsMouseButtonDown(rl.MouseButton.LEFT) {
		cumulativeCharWidth: i32 = 0
		for charWidth in cellsView.fieldWidths {
			cumulativeCharWidth += charWidth
			linePos := i32(cellsView.charBlock.width) * cumulativeCharWidth
			if f32(math.abs(rl.GetMouseX() - linePos)) < 5 {
				rl.DrawLine(
					i32(cellsView.charBlock.width) * cumulativeCharWidth,
					0,
					i32(cellsView.charBlock.width) * cumulativeCharWidth,
					rl.GetScreenHeight(),
					rl.RED,
				)
			}
		}
	}
}

process_csv :: proc(cellsView: ^CellsView) {

	colCount := 0
	rowCount := 0

	for char in cellsView.fileRunes {
		if char == ',' && rowCount == 0 {
			colCount += 1
		}

		if char == '\n' {
			rowCount += 1
		}
	}

	// Optimization watchpoint: append causes dynamic array reallocations!
	// Pre-sizing these using reserve() before loops would mitigate spikes.
	reserve(&cellsView.fieldWidths, len(cellsView.fieldWidths) + colCount + 1)
	for i := 0; i <= colCount; i += 1 {
		append(&cellsView.fieldWidths, 10)
	}

	reserve(&cellsView.fieldHeights, len(cellsView.fieldHeights) + rowCount + 1)
	for i := 0; i <= rowCount; i += 1 {
		append(&cellsView.fieldHeights, 1)
	}

	cellsView.preprocessed = true
	cellsView.fileLoadingUnderway = false
	fmt.printfln("file processed")
}

update_text_size :: proc(increase: bool, cellsView: ^CellsView) {
	if (increase) {
		new_size: f32 = cellsView.fontSize + 10
		load_font(cellsView, new_size)
	} else {
		new_size: f32 = cellsView.fontSize - 10
		load_font(cellsView, new_size)
	}
}

update_app_dimensions :: proc(cellsView: ^CellsView) {
	new_win_w := f32(rl.GetScreenWidth())
	new_win_h := f32(rl.GetScreenHeight()) - 20

	cellsView.charColumns = i32(new_win_w / cellsView.charBlock.width)
	cellsView.charRows = i32(new_win_h / cellsView.charBlock.height)
}

draw_cursor :: proc(app: ^App, charBlock: CharacterBlock) {
	rect := rl.Rectangle {
		x      = f32(app.mouse_charBlock_x) * charBlock.width,
		y      = f32(app.mouse_charBlock_y) * charBlock.height,
		width  = charBlock.width,
		height = charBlock.height,
	}

	rl.DrawRectangleRec(rect, rl.Fade(rl.YELLOW, 0.4))
}
