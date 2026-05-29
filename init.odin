package main

import rl "vendor:raylib"


initApp :: proc(view: ^CellsView, app: ^App, fontSize: f32) {

	// tracking for counting rune thread
	view.runeCountNeedsStarted = false
	view.runeCountThread = nil
	view.fileNumRunes = 0
	view.fileCurrentPath = csv_file_name
	view.runeCountThreadActive = false
	view.runeCountThreadComplete = false

	view.colors = []rl.Color{rl.BLUE, rl.SKYBLUE}
	view.fileLoadingUnderway = false
	view.preprocessed = false
	view.currentFileRow = 0
	view.containsHeader = true

	loadFont(view, fontSize)


	new_win_w := f32(rl.GetScreenWidth())
	new_win_h := f32(rl.GetScreenHeight()) - 20

	view.charColumns = i32(new_win_w / view.charWidth)
	view.charRows = i32(new_win_h / view.charHeight)

	view.runesToRender = make([]rune, view.charColumns * view.charRows)

}

loadFont :: proc(view: ^CellsView, fontSize: f32) {
	view.font = rl.LoadFontEx(
		"JetBrainsMono-2.304/fonts/ttf/JetBrainsMono-Regular.ttf",
		i32(fontSize),
		nil,
		0,
	)
	view.fontSize = fontSize

	charSpacing := f32(6)
	charSize := rl.MeasureTextEx(view.font, "A", fontSize, charSpacing)
	view.charWidth = charSize.x
	view.charHeight = charSize.y
}
