package main

import "core:fmt"
import "core:os"
import rl "vendor:raylib"

Window :: struct {
	name:   cstring,
	width:  i32, // width in pixels
	height: i32, // height in pixels
	fps:    i32,
}

App :: struct {
	pause:                bool,

	// input state
	left_mouse_clicked:   bool,
	right_mouse_clicked:  bool,
	toggle_pause:         bool,
	mouse_world_position: i32,
	mouse_tile_x:         i32,
	mouse_tile_y:         i32,
}

// contains the info on width and height of a mono character
CharacterBlock :: struct {
	width:  f32,
	height: f32,
}


// this is the actual panel where cells will be shown
// it contains the information about what file is loaded
CellsView :: struct {
	preprocessed:      bool,
	colors:            []rl.Color,
	fileChars:         [dynamic]rune, // the loaded file
	rune_index:        i32,
	font:              rl.Font,
	fontSize:          f32,
	charBlock:         CharacterBlock, // text character information
	// layout of the cells
	charColumns:       i32, // width in columns
	charRows:          i32, // height in rows
	cellColumnHeights: [dynamic]i32, // an array containing the height of each row of cells being displayed
	cellColumnWidths:  [dynamic]i32, // an array containing the width of each column of cells being displayed
}

Footer :: struct {
	columns:    i32, // width in columns
	chars:      [1000]rune,
	rune_index: i32,
	font:       rl.Font,
	fontSize:   f32,
	charBlock:  CharacterBlock,
}


main :: proc() {
	// 1. Enable Resizing
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	window := Window{"Adaptive Avoidance", 1280, 720, 120}
	rl.InitWindow(window.width, window.height, window.name)

	app: App
	init_app(&app)

	// setup the text view data
	cellsView := CellsView {
		colors     = []rl.Color{rl.BLUE, rl.SKYBLUE},
		rune_index = 0,
		fileChars  = make([dynamic]rune, 0, 10000, context.allocator),
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

init_app :: proc(app: ^App) {

}

create_bottom_footer :: proc(footer: ^Footer) {

	footer.font = rl.LoadFontEx(
		"JetBrainsMono-2.304/fonts/ttf/JetBrainsMono-Regular.ttf",
		15,
		nil,
		0,
	)

	footer.rune_index = 0
	footer.fontSize = 15
	charSpacing := f32(2)
	charSize := rl.MeasureTextEx(footer.font, "A", footer.fontSize, charSpacing)

	footer.charBlock = CharacterBlock {
		width  = charSize.x,
		height = charSize.y,
	}

	new_win_w := f32(rl.GetScreenWidth())

	footer.columns = i32(new_win_w / footer.charBlock.width)
}


load_font :: proc(cellsView: ^CellsView, fontSize: f32) {
	cellsView.font = rl.LoadFontEx(
		"JetBrainsMono-2.304/fonts/ttf/JetBrainsMono-Regular.ttf",
		cast(i32)fontSize,
		nil,
		0,
	)
	cellsView.fontSize = fontSize

	charSpacing := f32(2)
	charSize := rl.MeasureTextEx(cellsView.font, "A", cellsView.fontSize, charSpacing)

	cellsView.charBlock = CharacterBlock {
		width  = charSize.x,
		height = charSize.y,
	}

	update_app_dimensions(cellsView)
}

update_loop :: proc(cellsView: ^CellsView, charBlock: CharacterBlock, app: ^App, footer: ^Footer) {
	// 3. Check for Resize
	if rl.IsWindowResized() {
		update_app_dimensions(cellsView)
	}

	process_user_input(app, cellsView)

	rl.BeginDrawing()

	// render backgrounds
	rl.ClearBackground(rl.BLACK)
	draw_cursor(app, charBlock)
	draw_bottom_footer(footer, app)

	render_csv(cellsView)
	//rl.DrawFPS(10, 10)
	rl.EndDrawing()

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

	for i in 0 ..< colCount {
		append(&cellsView.cellColumnWidths, 7, 7, 7, 7)
	}

	for i in 0 ..< rowCount {
		append(&cellsView.cellColumnHeights, 1)
	}

	cellsView.preprocessed = true
}

render_csv :: proc(cellsView: ^CellsView) {
	process_csv(cellsView)
	if !cellsView.preprocessed {return}

	x_cell: i32 = 0 // keeps track of the exact character coord
	y_cell: i32 = 0 // keeps track of the exact character coord

	currentColumnIndex: i32 = 0 // keeps track of the exact character coord
	currentCellCharIndex: i32 = 0 // keeps track of how many characters rendered

	fileCharIndex := 0 // keeps track of how far through the file we are

	// loop until we have rendered all characters or
	// at least the screen cells are filled
	for fileCharIndex < len(cellsView.fileChars) {

		char := cellsView.fileChars[fileCharIndex]
		temp_char := char // re-assign the char so we can fill empty cell spots with ' '

		if char == ' ' && currentCellCharIndex == 0 {
			x_cell += 0 // new line x is reset back to the start of the panel
			y_cell += 0 // the y coord needs to move one lower with a new line
			currentColumnIndex += 0 // we are back to looking at the first cell column
			currentCellCharIndex += 0
			fileCharIndex += 1 // we move past the new line char to start fresh
			continue
		}

		// If it's a newline, move the "pen" to the next row and reset column
		if char == '\n' {
			x_cell = 0 // new line x is reset back to the start of the panel
			y_cell += 1 // the y coord needs to move one lower with a new line
			currentColumnIndex = 0 // we are back to looking at the first cell column
			currentCellCharIndex = 0
			fileCharIndex += 1 // we move past the new line char to start fresh
			continue
		}

		cell_is_filled: bool =
			(currentCellCharIndex + 1) >= cellsView.cellColumnWidths[currentColumnIndex]

		if char == ',' && cell_is_filled {
			x_cell += 1 // move to the next character space
			y_cell += 0 // no need to change row
			currentColumnIndex += 1 // we are back to looking at the first cell column
			currentCellCharIndex = 0 // move to the next cell (char count resets)
			fileCharIndex += 1 // we move past the new line char to start fresh
			continue // no rendering required skip
		}

		// here we acknowledge we aren't moving to the next letter yet
		// it is to counter balance the increment at the end of the loop
		if char == ',' && !cell_is_filled {
			temp_char = ' '
			fileCharIndex -= 1
		}

		if cell_is_filled {
			fileCharIndex += 1
			continue
		}

		pos := rl.Vector2 {
			f32(x_cell) * cellsView.charBlock.width,
			f32(y_cell) * cellsView.charBlock.height,
		}

		if temp_char != 0 {
			rl.DrawTextCodepoint(cellsView.font, temp_char, pos, cellsView.fontSize, rl.WHITE)
		}

		x_cell += 1 // move to the next character space
		y_cell += 0 // no need to change row
		currentColumnIndex += 0 // in a same word no need to change
		currentCellCharIndex += 1 // move to the next cell (char count resets)
		fileCharIndex += 1 // try the next character
	}

	cumulativeCharWidth: i32 = 0
	for charWidth in cellsView.cellColumnWidths {
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

update_text_size :: proc(increase: bool, cellsView: ^CellsView) {
	if (increase) {
		new_size: f32 = cellsView.fontSize + 10
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

process_user_input :: proc(app: ^App, cellsView: ^CellsView) {
	m_pos := rl.GetMousePosition()

	// Calculate tile based on pixel / cell size directly
	mouse_x := i32(m_pos.x / cellsView.charBlock.width)
	mouse_y := i32(m_pos.y / cellsView.charBlock.height)

	m_worl_pos := mouse_y * cellsView.charColumns + mouse_x

	// Clamp to current grid bounds
	mouse_x = clamp(mouse_x, 0, cellsView.charColumns - 1)
	mouse_y = clamp(mouse_y, 0, cellsView.charRows - 1)

	// 1. Handle printable characters (A-Z, 0-9, symbols)
	for {
		char := rl.GetCharPressed()
		if char == 0 do break

		append(&cellsView.fileChars, char)
		cellsView.rune_index += 1
	}

	// 2. Handle functional keys
	if rl.IsKeyPressed(.BACKSPACE) {
		clear(&cellsView.fileChars)
		// textView.chars[textView.rune_index - 1] = 0
		// textView.rune_index -= 1
	}

	if rl.IsKeyPressed(.ENTER) {
		load_file_into_view(cellsView, "testey.csv")
	}

	if rl.IsKeyPressed(.EQUAL) && rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyPressed(.KP_ADD) {
		update_text_size(true, cellsView)
	}

	if rl.IsMouseButtonDown(.LEFT) && m_worl_pos < i32(len(cellsView.fileChars)) {
		cellsView.fileChars[m_worl_pos] = 'A'
	}
	if rl.IsMouseButtonDown(.RIGHT) && m_worl_pos < i32(len(cellsView.fileChars)) {
		cellsView.fileChars[m_worl_pos] = 0
	}
	if app.toggle_pause {
		//textView.pause = !textView.pause
	}

	app^ = App {
		left_mouse_clicked   = rl.IsMouseButtonDown(.LEFT),
		right_mouse_clicked  = rl.IsMouseButtonDown(.RIGHT),
		toggle_pause         = rl.IsKeyPressed(.SPACE),
		mouse_world_position = mouse_y * cellsView.charColumns + mouse_x,
		mouse_tile_x         = mouse_x,
		mouse_tile_y         = mouse_y,
	}
}

draw_cursor :: proc(app: ^App, charBlock: CharacterBlock) {
	rect := rl.Rectangle {
		x      = f32(app.mouse_tile_x) * charBlock.width,
		y      = f32(app.mouse_tile_y) * charBlock.height,
		width  = charBlock.width,
		height = charBlock.height,
	}

	rl.DrawRectangleRec(rect, rl.Fade(rl.YELLOW, 0.4))
}

draw_bottom_footer :: proc(footer: ^Footer, app: ^App) {

	rect := rl.Rectangle {
		x      = 0,
		y      = f32(rl.GetScreenHeight() - 20),
		width  = f32(rl.GetScreenWidth()),
		height = 20,
	}

	rl.DrawRectangleRec(rect, rl.Fade(rl.YELLOW, 0.2))


	// 1. Get the FPS from Raylib and format it into a temporary Odin string
	fps := rl.GetFPS()
	//fps_text := fmt.tprintf("FPS: %d", fps) // tprintf allocates on the context temporary allocator
	footer_text := fmt.tprintf("FPS: %d | X: %d, Y: %d", fps, app.mouse_tile_x, app.mouse_tile_y)

	// 2. Clear the old runes and copy the new string into your fixed rune array
	//    (Resetting rune_index to track the actual length of your string)
	footer.rune_index = 0
	for r in footer_text {
		if footer.rune_index >= 1000 do break // Prevent buffer overflow

		footer.chars[footer.rune_index] = r

		pos := rl.Vector2 {
			f32(footer.rune_index) * footer.charBlock.width,
			f32(rl.GetScreenHeight()) - 20,
		}

		rl.DrawTextCodepoint(footer.font, r, pos, footer.fontSize, rl.WHITE)

		footer.rune_index += 1
	}
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
	for r in str_data {
		append(&view.fileChars, r)
	}
	fmt.printfln("loadded filleeeee")
}
