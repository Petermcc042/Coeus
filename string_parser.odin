package main

import "core:fmt"
import "core:slice"
import "core:strconv"
import "core:unicode/utf8"


CellInfo :: struct {
	containsDecimal: bool,
}

checkColumns :: proc(view: ^CellsView) {

	view.fileFieldsTypes = make([]FieldType, len(view.fieldRenderWidths))
	slice.fill(view.fileFieldsTypes, FieldType.String)

	fieldArray: [100]rune = {} // contains the runes for a fields cell
	fieldRuneIndex := 0 // contains the running count of the number of runes in a fields cell
	inQuotes := false
	startChecking := false
	currentFieldIndex := 0
	info: CellInfo = {
		containsDecimal = false,
	}
	rowLoopCount := 0

	for rune in view.fileRunes {
		//fmt.printfln("Rune: %r | Codepoint: %d", rune, int(rune))
		//fmt.printfln("Rune: %r | Field Index: %d", rune, currentFieldIndex)

		if rune == '\r' {
			continue
		}

		if (rune == ',' && inQuotes == false) || rune == '\n' {

			if rune == '\n' {
				startChecking = true
				rowLoopCount += 1
			}

			if !startChecking {continue}

			if rowLoopCount == 1 {
				view.fileFieldsTypes[currentFieldIndex] = checkCellFormat(
					fieldArray[:fieldRuneIndex],
					info,
				)
			} else {
				tempType := checkCellFormat(fieldArray[:fieldRuneIndex], info)
				if tempType != view.fileFieldsTypes[currentFieldIndex] {
					view.fileFieldsTypes[currentFieldIndex] = FieldType.String
				}
			}

			// reset for next field
			fieldArray = {}
			fieldRuneIndex = 0
			info = {
				containsDecimal = false,
			}

			if rune == '\n' {
				currentFieldIndex = 0
			} else {
				currentFieldIndex += 1
			}

			continue
		}

		if rune == '.' {
			info.containsDecimal = true
		}


		if rune == '"' {
			if inQuotes {
				inQuotes = false
			} else {
				inQuotes = true
			}
		}

		fieldArray[fieldRuneIndex] = rune
		fieldRuneIndex += 1
	}

	fmt.println(view.fileFieldsTypes)
}

checkCellFormat :: proc(runes: []rune, info: CellInfo) -> FieldType {
	if len(runes) == 0 do return FieldType.String
	s := utf8.runes_to_string(runes, context.temp_allocator)
	if info.containsDecimal {
		floater, ok := strconv.parse_f64(s)
		if ok {
			//fmt.println("Float: ", s, ":", floater, ":", ok)
			return FieldType.Float
		}
	}

	inter, ok := strconv.parse_i64(s)
	if ok {
		//fmt.println("Int: ", s, ":", inter, ":", ok)
		return FieldType.Int
	}

	//fmt.println("String: ", s, ":", s, ":", true)
	return FieldType.String
}


rankFields :: proc(view: ^CellsView) {

}
