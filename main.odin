package main

import "core:fmt"
import "core:math"
import "core:os"
import "core:slice"
import rl "vendor:raylib"

debugCountdown: f32 = 1

main :: proc() {
	//SetConfigFlags(FLAG_WINDOW_HIGHDPI);
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .WINDOW_HIGHDPI})
	window := Window{"Adaptive Avoidance", 1280, 720, 120}
	rl.InitWindow(window.width, window.height, window.name)
	rl.SetTargetFPS(200)

	app: App = {}
	footer: Footer = {}
	header: Header = {}
	view: CellsView = {}
	filePanel: FilePanel = {}

	app.resizeNeeded = false
	initFooter(&footer)
	initHeader(&header)
	initFilePanel(&filePanel)

	initCellsView(&view, 20)
	defer delete(view.fileRunes)
	defer delete(view.runesToRender)

	updateAppLayout(&footer, &header, &view, &filePanel, &app)

	loadDirectory(".", &filePanel)
	//defer os.file_info_slice_delete(filePanel.directoryList, context.allocator)

	for !rl.WindowShouldClose() {
		update_loop(&view, &app, &footer, &header, &filePanel)
	}

	rl.UnloadFont(view.font)
	rl.CloseWindow()
}

updateAppLayout :: proc(
	footer: ^Footer,
	header: ^Header,
	view: ^CellsView,
	panel: ^FilePanel,
	app: ^App,
) {

	footer.topLeft = {0, f32(rl.GetScreenHeight()) - footer.charHeight}
	footer.bottomRight = {f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}

	header.topLeft = {0, 0}
	header.bottomRight = {f32(rl.GetScreenWidth()), header.charHeight}

	full_screen := rl.GetScreenHeight()
	// this is the end x pos and the starting x pos of the other panels
	panelEndX := panel.charWidth * f32(panel.charColumns)

	panel.topLeft = {0, header.bottomRight.y}
	panel.bottomRight = {panelEndX, footer.topLeft.y}

	view.topLeft = {panelEndX, header.charHeight}
	view.bottomRight = {f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()) - footer.charHeight}

	viewWidth := view.bottomRight.x - view.topLeft.x
	viewHeight := f32(rl.GetScreenHeight()) - footer.charHeight

	fmt.print("viewWidth: ", viewWidth, " viewHeigh: ", viewHeight)

	view.charColumns = i32(viewWidth / view.charWidth)
	view.charRows = i32(viewHeight / view.charHeight)

	app.resizeNeeded = false

	delete(view.runesToRender)
	view.runesToRender = make([]rune, view.charColumns * view.charRows)

}


update_loop :: proc(
	view: ^CellsView,
	app: ^App,
	footer: ^Footer,
	header: ^Header,
	panel: ^FilePanel,
) {

	// 3. Check for Resize
	if rl.IsWindowResized() || app.resizeNeeded {
		fmt.print("app layout resized \n")
		updateAppLayout(footer, header, view, panel, app)
	}
	process_user_input(app, view, panel)

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
	drawHeader(header, app)
	drawFilePanel(panel, app)

	if view.preprocessed {
		// render_csv profile scope is maintained inside its own proc,
		// or will nest cleanly here if it contains one
		renderCellsView(view)
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
		loadCellViewFont(cellsView, new_size)
	} else {
		new_size: f32 = cellsView.fontSize - 10
		loadCellViewFont(cellsView, new_size)
	}
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
