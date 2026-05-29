package main

import "core:fmt"
import "core:math"
import "core:slice"
import rl "vendor:raylib"


main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	window := Window{"Adaptive Avoidance", 1280, 720, 120}
	rl.InitWindow(window.width, window.height, window.name)
	// rl.SetTargetFPS(120)

	app: App = {}

	// setup the text view data
	view := CellsView{}

	initApp(&view, &app, 20)
	defer delete(view.fileRunes)
	defer delete(view.runesToRender)

	footer: Footer
	create_bottom_footer(&footer)


	for !rl.WindowShouldClose() {
		update_loop(&view, &app, &footer)
	}

	rl.UnloadFont(view.font)
	rl.CloseWindow()
}


update_loop :: proc(view: ^CellsView, app: ^App, footer: ^Footer) {

	// 3. Check for Resize
	if rl.IsWindowResized() {
		update_app_dimensions(view)
	}
	process_user_input(app, view)

	fileLoadingLogic(view)

	if app.doubleClick {
		fmt.print("double click mf!...\n")
	}

	if rl.IsMouseButtonPressed(.LEFT) && app.mouse_charBlock_y == 0 {
		sortColumn(view, app.mouse_fieldNum)
	}

	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	// render backgrounds
	draw_cursor(app, view)
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

	pollRuneCountThread(view)

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

	pollFileLoadThread(view)

	if view.fileProcessingNeedsStarted {
		text := []rune{'1', '2', '.', '5'}
		//cell_is_numeric(text)
		process_csv(view)
	}
}


update_cell_width :: proc(cellsView: ^CellsView, app: ^App) {

	if rl.IsMouseButtonDown(rl.MouseButton.LEFT) {
		cumulativeCharWidth: i32 = 0
		for charWidth in cellsView.fieldRenderWidths {
			cumulativeCharWidth += charWidth
			linePos := i32(cellsView.charWidth) * cumulativeCharWidth
			if f32(math.abs(rl.GetMouseX() - linePos)) < 5 {
				rl.DrawLine(
					i32(cellsView.charWidth) * cumulativeCharWidth,
					0,
					i32(cellsView.charWidth) * cumulativeCharWidth,
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

	cellsView.fieldRenderWidths = make([]i32, colCount + 1)
	slice.fill(cellsView.fieldRenderWidths, 10)

	cellsView.fieldRenderHeights = make([]i32, rowCount)
	slice.fill(cellsView.fieldRenderHeights, 1)

	cellsView.preprocessed = true
	cellsView.fileLoadingUnderway = false
	fmt.printfln("file processed")
}

update_text_size :: proc(increase: bool, cellsView: ^CellsView) {
	if (increase) {
		new_size: f32 = cellsView.fontSize + 10
		loadFont(cellsView, new_size)
	} else {
		new_size: f32 = cellsView.fontSize - 10
		loadFont(cellsView, new_size)
	}
}

update_app_dimensions :: proc(cellsView: ^CellsView) {
	new_win_w := f32(rl.GetScreenWidth())
	new_win_h := f32(rl.GetScreenHeight()) - 20

	cellsView.charColumns = i32(new_win_w / cellsView.charWidth)
	cellsView.charRows = i32(new_win_h / cellsView.charHeight)

	delete(cellsView.runesToRender)
	cellsView.runesToRender = make([]rune, cellsView.charColumns * cellsView.charRows)
}

draw_cursor :: proc(app: ^App, view: ^CellsView) {
	rect := rl.Rectangle {
		x      = f32(app.mouse_charBlock_x) * view.charWidth,
		y      = f32(app.mouse_charBlock_y) * view.charHeight,
		width  = view.charWidth,
		height = view.charHeight,
	}

	rl.DrawRectangleRec(rect, rl.Fade(rl.YELLOW, 0.4))
}
