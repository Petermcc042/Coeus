package main


import "core:fmt"
import rl "vendor:raylib"

initFilePanel :: proc(panel: ^FilePanel) {
	panel.font = rl.LoadFontEx(
		"JetBrainsMono-2.304/fonts/ttf/JetBrainsMono-Regular.ttf",
		15,
		nil,
		0,
	)

	panel.rune_index = 0
	panel.fontSize = 15
	charSpacing := f32(2)
	charSize := rl.MeasureTextEx(panel.font, "A", panel.fontSize, charSpacing)
	panel.charWidth = charSize.x
	panel.charHeight = charSize.y
	panel.charColumns = 40

	fmt.print("loaded file panel \n")
}


drawFilePanel :: proc(panel: ^FilePanel, app: ^App) {
	rect := rl.Rectangle {
		x      = panel.topLeft.x,
		y      = panel.topLeft.y,
		width  = panel.bottomRight.x - panel.topLeft.x,
		height = panel.bottomRight.y - panel.topLeft.y,
	}

	rl.DrawRectangleRec(rect, rl.Fade(rl.BEIGE, 0.2))
}
