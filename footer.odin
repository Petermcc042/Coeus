package main

import "core:fmt"
import rl "vendor:raylib"

import "core:prof/spall"

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


draw_bottom_footer :: proc(footer: ^Footer, app: ^App) {
	spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)

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
	footer_text := fmt.tprintf(
		"FPS: %d | X: %d, Y: %d",
		fps,
		app.mouse_charBlock_x,
		app.mouse_charBlock_y,
	)

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
