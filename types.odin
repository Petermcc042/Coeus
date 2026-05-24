package main

import "core:thread"
import rl "vendor:raylib"

// csv_file_name :: "data/testey.csv" //easy
// csv_file_name :: "data/testier.csv"
csv_file_name :: "data/customers-500000.csv"


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
	mouse_charBlock_x:    i32, // the mouses character column position
	mouse_charBlock_y:    i32, // the mouses character row position
}

// contains the info on width and height of a mono character
CharacterBlock :: struct {
	width:  f32,
	height: f32,
}


// this is the actual panel where cells will be shown
// it contains the information about what file is loaded
CellsView :: struct {
	preprocessed:               bool,
	colors:                     []rl.Color,
	font:                       rl.Font,
	fontSize:                   f32,
	charBlock:                  CharacterBlock, // text character information

	// layout of the cells
	charColumns:                i32, // width of the viewer in columns
	charRows:                   i32, // height of the viewer in rows
	fieldHeights:               [dynamic]i32, // an array containing the height of each row of fields being displayed
	fieldWidths:                [dynamic]i32, // an array containing the width of each column of fields being displayed

	//loaded data
	fileRows:                   [dynamic]i32, // an array containing the width of each column of cells being displayed
	fileFields:                 [dynamic]i32, // an array containing the width of each column of cells being displayed
	charsToRender:              [dynamic]rune, // an array containing the width of each column of cells being displayed

	// to render
	renderHeader:               bool,
	currentFileRow:             i32,

	//this bool controls the whole file loading system
	fileLoadingUnderway:        bool,

	// rune count thread
	runeCountNeedsStarted:      bool,
	runeCountSuccess:           bool,
	runeCountThread:            ^thread.Thread,
	runeCountThreadActive:      bool,
	runeCountThreadComplete:    bool,
	fileNumRunes:               i32,
	fileCurrentPath:            string,

	// file loader thread
	runeArrayNeedsInitialised:  bool, // used to kick off rune array initialisation
	fileLoadNeedsStarted:       bool, // used to begin the thread to load the current file
	fileProcessingNeedsStarted: bool, // used to begin the column and row count proc
	fileRunes:                  []rune, // the loaded file
	fileLoadSuccess:            bool, // were there any errors in the file load thread
	fileLoadThread:             ^thread.Thread,
	fileLoadThreadActive:       bool,
	fileLoadThreadComplete:     bool,
	// fileCurrentPath:         string, used from above
}


Footer :: struct {
	columns:    i32, // width in columns
	chars:      [1000]rune,
	rune_index: i32,
	font:       rl.Font,
	fontSize:   f32,
	charBlock:  CharacterBlock,
}
