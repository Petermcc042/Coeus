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
	textView:             TextView,
	footer:               Footer,

	// input state
	left_mouse_clicked:   bool,
	right_mouse_clicked:  bool,
	toggle_pause:         bool,
	mouse_world_position: i32,
	mouse_tile_x:         i32,
	mouse_tile_y:         i32,
}


CharacterBlock :: struct {
	width:  f32,
	height: f32,
}

TextView :: struct {
	colors:     []rl.Color,
	columns:    i32, // width in columns
	rows:       i32, // height in rows
	chars:      [dynamic]rune,
	rune_index: i32,
	font:       rl.Font,
	fontSize:   f32,
	charBlock:  CharacterBlock,
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
	//rl.SetTargetFPS(window.fps)

	app: App

	// setup the text view data
	textView := TextView {
		colors     = []rl.Color{rl.BLUE, rl.SKYBLUE},
		rune_index = 0,
		chars      = make([dynamic]rune, 0, 10000, context.allocator),
	}

	load_font(&textView, 20)
	defer delete(textView.chars)

	footer: Footer
	create_bottom_footer(&footer)

	for !rl.WindowShouldClose() {
		update_loop(&textView, textView.charBlock, &app, &footer)
	}

	rl.UnloadFont(textView.font)
	rl.CloseWindow()
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


load_font :: proc(textView: ^TextView, fontSize: f32) {
	textView.font = rl.LoadFontEx(
		"JetBrainsMono-2.304/fonts/ttf/JetBrainsMono-Regular.ttf",
		cast(i32)fontSize,
		nil,
		0,
	)
	textView.fontSize = fontSize

	charSpacing := f32(2)
	charSize := rl.MeasureTextEx(textView.font, "A", textView.fontSize, charSpacing)

	textView.charBlock = CharacterBlock {
		width  = charSize.x,
		height = charSize.y,
	}

	update_app_dimensions(textView)
}

update_loop :: proc(textView: ^TextView, charBlock: CharacterBlock, app: ^App, footer: ^Footer) {
	// 3. Check for Resize
	if rl.IsWindowResized() {
		update_app_dimensions(textView)
	}

	process_user_input(app, textView, charBlock)

	rl.BeginDrawing()

	// render backgrounds
	rl.ClearBackground(rl.BLACK)
	draw_cursor(app, charBlock)
	draw_bottom_footer(footer)


	// Draw Text
	for y in 0 ..< textView.rows {
		for x in 0 ..< textView.columns {
			index := y * textView.columns + x
			if index >= i32(len(textView.chars)) do break

			char := textView.chars[index]
			pos := rl.Vector2{f32(x) * charBlock.width, f32(y) * charBlock.height}

			if char != 0 {
				rl.DrawTextCodepoint(textView.font, char, pos, textView.fontSize, rl.WHITE)
			}
		}
	}

	//rl.DrawFPS(10, 10)
	rl.EndDrawing()
}

update_text_size :: proc(increase: bool, textView: ^TextView) {
	if (increase) {
		new_size: f32 = textView.fontSize + 10
		load_font(textView, new_size)
	}
}

// Helper to recalculate how many characters fit and resize the buffer
update_app_dimensions :: proc(textView: ^TextView) {
	new_win_w := f32(rl.GetScreenWidth())
	new_win_h := f32(rl.GetScreenHeight()) - 20

	textView.columns = i32(new_win_w / textView.charBlock.width)
	textView.rows = i32(new_win_h / textView.charBlock.height)
}

process_user_input :: proc(app: ^App, textView: ^TextView, charBlock: CharacterBlock) {
	m_pos := rl.GetMousePosition()

	// Calculate tile based on pixel / cell size directly
	mouse_x := i32(m_pos.x / charBlock.width)
	mouse_y := i32(m_pos.y / charBlock.height)

	m_worl_pos := mouse_y * textView.columns + mouse_x

	// Clamp to current grid bounds
	mouse_x = clamp(mouse_x, 0, textView.columns - 1)
	mouse_y = clamp(mouse_y, 0, textView.rows - 1)

	// 1. Handle printable characters (A-Z, 0-9, symbols)
	for {
		char := rl.GetCharPressed()
		if char == 0 do break

		append(&textView.chars, char)
		textView.rune_index += 1
	}

	// 2. Handle functional keys
	if rl.IsKeyPressed(.BACKSPACE) {
		clear(&textView.chars)
		// textView.chars[textView.rune_index - 1] = 0
		// textView.rune_index -= 1
	}

	if rl.IsKeyPressed(.ENTER) {
		load_file_into_view(textView, "tester.txt")
	}

	if rl.IsKeyPressed(.EQUAL) && rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyPressed(.KP_ADD) {
		update_text_size(true, textView)
	}

	if rl.IsMouseButtonDown(.LEFT) && m_worl_pos < i32(len(textView.chars)) {
		textView.chars[m_worl_pos] = 'A'
	}
	if rl.IsMouseButtonDown(.RIGHT) && m_worl_pos < i32(len(textView.chars)) {
		textView.chars[m_worl_pos] = 0
	}
	if app.toggle_pause {
		//textView.pause = !textView.pause
	}

	app^ = App {
		left_mouse_clicked   = rl.IsMouseButtonDown(.LEFT),
		right_mouse_clicked  = rl.IsMouseButtonDown(.RIGHT),
		toggle_pause         = rl.IsKeyPressed(.SPACE),
		mouse_world_position = mouse_y * textView.columns + mouse_x,
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

draw_bottom_footer :: proc(footer: ^Footer) {

	rect := rl.Rectangle {
		x      = 0,
		y      = f32(rl.GetScreenHeight() - 20),
		width  = f32(rl.GetScreenWidth()),
		height = 20,
	}

	rl.DrawRectangleRec(rect, rl.Fade(rl.YELLOW, 0.2))


	// 1. Get the FPS from Raylib and format it into a temporary Odin string
	fps := rl.GetFPS()
	fps_text := fmt.tprintf("FPS: %d", fps) // tprintf allocates on the context temporary allocator

	// 2. Clear the old runes and copy the new string into your fixed rune array
	//    (Resetting rune_index to track the actual length of your string)
	footer.rune_index = 0
	for r in fps_text {
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

load_file_into_view :: proc(view: ^TextView, filepath: string) {
	// 1. Read the entire file into a byte slice ([]u8)
	data, err := os.read_entire_file_from_path(filepath, context.allocator)
	if err != nil {
		// You can print the specific error (e.g., 'File Not Found')
		fmt.eprintfln("Error reading file %s: %v", filepath, err)
		return
	}
	defer delete(data, context.allocator)

	// 2. Clear existing text
	clear(&view.chars)

	// 3. Convert UTF-8 bytes to runes
	// This handles multi-byte characters correctly for DrawTextCodepoint
	str_data := string(data)
	for r in str_data {
		append(&view.chars, r)
	}
}
