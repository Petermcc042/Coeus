package main

import "core:fmt"
import "core:math"
import "core:thread"
import rl "vendor:raylib"

import "core:prof/spall"

// Create global or context-level profiling state
spall_ctx: spall.Context
@(thread_local)
spall_buffer: spall.Buffer

main :: proc() {
	spall_ctx = spall.context_create("game_profile.spall")
	defer spall.context_destroy(&spall_ctx)

	buffer_data := make([]u8, 1024 * 1024)
	defer delete(buffer_data)
	spall_buffer = spall.buffer_create(buffer_data)
	defer spall.buffer_destroy(&spall_ctx, &spall_buffer)


	// 1. Enable Resizing
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	window := Window{"Adaptive Avoidance", 1280, 720, 120}
	rl.InitWindow(window.width, window.height, window.name)
	// rl.SetTargetFPS(120)

	app: App

	// setup the text view data
	view := CellsView {
		colors              = []rl.Color{rl.BLUE, rl.SKYBLUE},
		//fileChars       = make([dynamic]rune, 0, 10000, context.allocator),
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
	spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, "Frame")
	// Flush at the very end of the frame
	defer spall.buffer_flush(&spall_ctx, &spall_buffer)

	// 3. Check for Resize
	if rl.IsWindowResized() {
		spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, "Window Resized")
		update_app_dimensions(view)
	}

	{
		spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, "Process Input")
		process_user_input(app, view)
	}

	{
		spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, "File Loading Logic Block")
		fileLoadingLogic(view)
	}

	{
		spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, "Render Block (CPU Side)")
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
	}

	{
		// Isolate EndDrawing! This shows you your pure GPU wait time / VSync waiting.
		spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, "rl.EndDrawing (GPU Sync)")
		rl.EndDrawing()
	}
}

fileLoadingLogic :: proc(view: ^CellsView) {
	spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)

	if !view.fileLoadingUnderway {return}

	// 1. find length of file
	if view.runeCountNeedsStarted {
		spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, "Start Rune Count Thread")
		startRuneCountThread(view)
		view.runeCountNeedsStarted = false
	}

	{
		spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, "Poll Rune Count Thread")
		pollRuneCountThread(view)
	}

	// 2. create array
	if view.runeArrayNeedsInitialised {
		spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, "Initialize Rune Array Alloc")
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
		spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, "Start File Load Thread")
		startLoadFileThread(view)
		view.fileLoadNeedsStarted = false
	}

	{
		spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, "Poll File Load Thread")
		pollFileLoadThread(view)
	}

	if view.fileProcessingNeedsStarted {
		process_csv(view)
	}
}


load_font :: proc(cellsView: ^CellsView, fontSize: f32) {
	spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)

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
	spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)

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
	spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)

	colCount := 0
	rowCount := 0

	{
		spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, "Count Columns and Rows Loop")
		for char in cellsView.fileRunes {
			if char == ',' && rowCount == 0 {
				colCount += 1
			}

			if char == '\n' {
				rowCount += 1
			}
		}
	}

	{
		spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, "Append Field Dimensions")

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
	}

	cellsView.preprocessed = true
	cellsView.fileLoadingUnderway = false
	fmt.printfln("file processed")
}

update_text_size :: proc(increase: bool, cellsView: ^CellsView) {
	spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)
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
