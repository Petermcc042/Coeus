package main

import "core:fmt"
import "core:math"
import "core:os"
import rl "vendor:raylib"


main :: proc() {
	// 1. Enable Resizing
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	window := Window{"Adaptive Avoidance", 1280, 720, 120}
	rl.InitWindow(window.width, window.height, window.name)
	rl.SetTargetFPS(120)

	app: App
	init_app(&app)

	// setup the text view data
	cellsView := CellsView {
		colors         = []rl.Color{rl.BLUE, rl.SKYBLUE},
		fileChars      = make([dynamic]rune, 0, 10000, context.allocator),
		needsRendered  = true,
		preprocessed   = false,
		currentFileRow = 0,
	}

	load_font(&cellsView, 20)
	defer delete(cellsView.fileChars)

	footer: Footer
	create_bottom_footer(&footer)

	for !rl.WindowShouldClose() {
		update_loop(&cellsView, cellsView.charBlock, &app, &footer)
	}

	rl.UnloadFont(cellsView.font)
	rl.CloseWindow()
}


update_loop :: proc(cellsView: ^CellsView, charBlock: CharacterBlock, app: ^App, footer: ^Footer) {
	// 3. Check for Resize
	if rl.IsWindowResized() {
		update_app_dimensions(cellsView)
	}

	process_user_input(app, cellsView)

	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	// render backgrounds
	draw_cursor(app, charBlock)
	draw_bottom_footer(footer, app)

	process_csv(cellsView)
	if cellsView.preprocessed && cellsView.needsRendered {
		rl.ClearBackground(rl.DARKBLUE)
		render_csv(cellsView)
	}

	update_cell_width(cellsView, app)
	rl.EndDrawing()

}


init_app :: proc(app: ^App) {

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
	if cellsView.preprocessed == true {return}
	if len(cellsView.fileChars) <= 0 {return}

	colCount := 0
	rowCount := 0

	for char in cellsView.fileChars {
		if char == ',' && rowCount == 0 {
			colCount += 1
		}

		if char == '\n' {
			rowCount += 1
		}
	}

	for i := 0; i <= colCount; i += 1 {
		append(&cellsView.fieldWidths, 10)
	}

	for i := 0; i <= rowCount; i += 1 {
		append(&cellsView.fieldHeights, 1)
	}

	cellsView.preprocessed = true
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

// Helper to recalculate how many characters fit and resize the buffer
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


load_file_into_view :: proc(view: ^CellsView, filepath: string) {
	// 1. Read the entire file into a byte slice ([]u8)
	data, err := os.read_entire_file_from_path(filepath, context.allocator)
	if err != nil {
		// You can print the specific error (e.g., 'File Not Found')
		fmt.eprintfln("Error reading file %s: %v", filepath, err)
		return
	}
	defer delete(data, context.allocator)

	// 2. Clear existing text
	clear(&view.fileChars)

	// 3. Convert UTF-8 bytes to runes
	// This handles multi-byte characters correctly for DrawTextCodepoint
	str_data := string(data)

	temp_count: i32 = 0
	append(&view.fileRows, 0)

	for r in str_data {
		if r == '\n' {
			append(&view.fileRows, temp_count + 1)
		}

		append(&view.fileChars, r)
		temp_count += 1
	}
	fmt.printfln("loadded filleeeee")
}
