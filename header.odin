package main

import "core:fmt"
import rl "vendor:raylib"

initHeader :: proc(header: ^Header) {
	header.font = rl.LoadFontEx(
		"JetBrainsMono-2.304/fonts/ttf/JetBrainsMono-Regular.ttf",
		15,
		nil,
		0,
	)

	header.rune_index = 0
	header.fontSize = 15
	charSpacing := f32(2)
	charSize := rl.MeasureTextEx(header.font, "A", header.fontSize, charSpacing)
	header.charWidth = charSize.x
	header.charHeight = charSize.y

	fmt.print("loaded header \n")
}

drawHeader :: proc(header: ^Header, app: ^App) {

	rect := rl.Rectangle {
		x      = header.topLeft.x,
		y      = header.topLeft.y,
		width  = header.bottomRight.x - header.topLeft.x,
		height = header.bottomRight.y - header.topLeft.y,
	}

	rl.DrawRectangleRec(rect, rl.Fade(rl.YELLOW, 0.2))


	// 1. Get the FPS from Raylib and format it into a temporary Odin string
	fps := rl.GetFPS()
	//fps_text := fmt.tprintf("FPS: %d", fps) // tprintf allocates on the context temporary allocator
	footer_text := fmt.tprintf(
		"FPS: %d | X: %d, Y: %d",
		fps,
		app.mouse_charBlock_x,
		app.mouse_charBlock_y,
	)

	// 2. Clear the old runes and copy the new string into your fixed rune array
	//    (Resetting rune_index to track the actual length of your string)
	header.rune_index = 0
	for r in footer_text {
		if header.rune_index >= 1000 do break // Prevent buffer overflow

		header.chars[header.rune_index] = r

		pos := rl.Vector2{f32(header.rune_index) * header.charWidth, 0}

		rl.DrawTextCodepoint(header.font, r, pos, header.fontSize, rl.WHITE)

		header.rune_index += 1
	}
}
