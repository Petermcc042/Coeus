package main

import "core:fmt"
import "core:math"
import "core:mem"
import "core:slice"
import rl "vendor:raylib"

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
	// rl.SetTargetFPS(200)

	app: App = {}
	footer: Footer = {}
	header: Header = {}
	view: CellsView = {}
	filePanel: FilePanel = {}
	info: FileLoadingInfo = {}
	colState := ColumnState {
		dragged_column = -1,
	}

	app.resizeNeeded = false
	initFooter(&footer)
	initHeader(&header)
	initFilePanel(&filePanel)
	defer (clearFilePanel(&filePanel))

	initFileLoadInfo(&info)
	initCellsView(&view, 20)
	defer delete(view.fileRunes)
	defer delete(view.fileFieldsTypes)
	defer delete(view.fileRowCharIndices)
	defer delete(view.fieldRenderHeights)
	defer delete(view.fieldRenderWidths)

	updateAppLayout(&footer, &header, &view, &filePanel, &app)

	loadDirectory(".", &filePanel)

	for !rl.WindowShouldClose() {
		update_loop(&view, &app, &footer, &header, &filePanel, &info, &colState)
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

	panel.rect = rl.Rectangle {
		x      = panel.topLeft.x,
		y      = panel.topLeft.y,
		width  = panel.bottomRight.x - panel.topLeft.x,
		height = panel.bottomRight.y - panel.topLeft.y,
	}

	view.topLeft = {panelEndX, header.charHeight}
	view.bottomRight = {f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()) - footer.charHeight}

	viewWidth := view.bottomRight.x - view.topLeft.x
	viewHeight := f32(rl.GetScreenHeight()) - footer.charHeight

	view.rect = rl.Rectangle {
		x      = view.topLeft.x,
		y      = view.topLeft.y,
		width  = view.bottomRight.x - view.topLeft.x,
		height = view.bottomRight.y - view.topLeft.y,
	}

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
	colState: ^ColumnState,
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

	if rl.IsMouseButtonPressed(.LEFT) && app.mouse_viewCharBlock_y == 0 && view.currentPane {
		sortColumn(view, app.mouse_fieldNum)
	}

	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	// render backgrounds
	draw_cursor(app, view)
	draw_bottom_footer(footer, app)
	drawHeader(header, app)
	drawFilePanel(panel, app)

	if info.fileLoaded do renderCellsView(view, colState)

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
	if !view.currentPane {return}
	rect := rl.Rectangle {
		x      = f32(app.mouse_viewCharBlock_x) * view.charWidth + view.topLeft.x,
		y      = f32(app.mouse_viewCharBlock_y) * view.charHeight + view.topLeft.y,
		width  = view.charWidth,
		height = view.charHeight,
	}

	rl.DrawRectangleRec(rect, rl.Fade(rl.YELLOW, 0.4))
}
