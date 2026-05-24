## Sizing of columns
this should be easy the only tough bit is learning how to work with on mouse down and mouse exit to determine drag distance.
perhaps in loading a file we should also store the max character width of a column.
If it is less than the default min size of the field we could set the field width to that instead.

## Header Row Recognition


## Loaded Meta Data For Sorting
idea loop over the file once at the start to pull meta data.
once the file is loaded on a background thread we can start running the extra meta data calculations.
for each row look at the data and rank it based on a standard sorting algorithms. 
If it is numerical work out the correct rank for each row and then store it alongside the row numbers array.

## search

## filter

## Render Blocks of text 
currently the code renders every single character as an individual draw call. 
As we loop over the characters required in the frame they could be added to one array of size (width * height)
from here as long as there are '\n' characters we can pass a whole array to rl.DrawTextEx()
This should cut it down to one draw call.
Not sure how we convert the array of runes to strings to do this
