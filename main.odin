package main

import "core:fmt"
import "core:math"
import "core:mem"
import "core:slice"
import rl "vendor:raylib"

debugCountdown: f32 = 1

main :: proc() {
	// 1. Set up the tracking allocator
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	defer mem.tracking_allocator_destroy(&track)

	// 2. Override the current context allocator
	context.allocator = mem.tracking_allocator(&track)

	// 3. Set up a defer block to print leaks at the very end of main
	defer {
		if len(track.allocation_map) > 0 {
			fmt.eprintf("=== %v Allocations Leaked ===\n", len(track.allocation_map))
			for _, entry in track.allocation_map {
				fmt.eprintf("- %v bytes leaked at %v\n", entry.size, entry.location)
			}
		}
		if len(track.bad_free_array) > 0 {
			fmt.eprintf("=== %v Bad Frees Detected ===\n", len(track.bad_free_array))
			for entry in track.bad_free_array {
				fmt.eprintf("- Bad free at %v\n", entry.location)
			}
		}
	}


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
	info: FileLoadingInfo = {}

	app.resizeNeeded = false
	initFooter(&footer)
	initHeader(&header)
	initFilePanel(&filePanel)
	initFileLoadInfo(&info)
	initCellsView(&view, 20)
	defer delete(view.fileRunes)

	updateAppLayout(&footer, &header, &view, &filePanel, &app)

	loadDirectory(".", &filePanel)

	for !rl.WindowShouldClose() {
		update_loop(&view, &app, &footer, &header, &filePanel, &info)
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

	view.charColumns = i32(viewWidth / view.charWidth)
	view.charRows = i32(viewHeight / view.charHeight)

	app.resizeNeeded = false
}


update_loop :: proc(
	view: ^CellsView,
	app: ^App,
	footer: ^Footer,
	header: ^Header,
	panel: ^FilePanel,
	info: ^FileLoadingInfo,
) {

	// 3. Check for Resize
	if rl.IsWindowResized() || app.resizeNeeded {
		fmt.print("app layout resized \n")
		updateAppLayout(footer, header, view, panel, app)
	}
	process_user_input(app, view, panel, info, view)

	fileLoadingLogic(view, info)

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

	if info.fileLoaded do renderCellsView(view)

	update_cell_width(view, app)

	rl.EndDrawing()
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
