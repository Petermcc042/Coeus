idea loop over the file once at the start to pull meta data.
the idea is we don't want to store rows in different arrays but instead index into one array efficiently.
so loop over and store the character index after '/n' as the start of a row. 
Count the number of rows etc. 
So when implementing scrolling the rendering can just skip all characters till the start of a row.
we can also pull number of columns here.
then once the file is loaded on a background thread we can start running the extra meta data calculations.
for each row look at the data and rank it based on a standard sorting algorithms. If it is numerical work out the correct rank for each row and then store it alongside the row numbers array.
