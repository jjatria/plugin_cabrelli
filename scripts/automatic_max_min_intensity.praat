form intensity.praat
	comment Directory where the sound files are located:
	sentence Path /Users/YOURNAME/Desktop/stops/
	comment Directory where you want to keep your output excel:
	sentence File /Users/YOURNAME/Desktop/stops/
	comment Name of dataset:
	sentence Filename intensitydifference
endform

directory$=path$
fileappend 'file$'/'filename$'_output.xls Filename'tab$'Duration of Consonant'tab$'Intensity Difference'tab$''newline$'
Create Strings as file list... list 'directory$'/*.wav
numberOfFiles = Get number of strings
for ifile to numberOfFiles
   select Strings list
   fileName$ = Get string... ifile
   Read from file... 'directory$'/'fileName$'
   fileName$ = selected$("Sound")
   Read from file... 'directory$'/TextGrid/'fileName$'.TextGrid
   	select Sound 'fileName$'
	  	plus TextGrid 'fileName$'
	Clone time domain
Read from file... 'directory$'/TextGrid/'fileName$'.TextGrid
    n = Get number of intervals... 1
	for i from 1 to n
	select TextGrid 'fileName$'
	label$=Get label of interval... 1 i
	if label$ <> ""
	cons_start=Get starting point... 1 i
	cons_end=Get end point... 1 i
	vowel_start=Get starting point... 1 i+1
	vowel_end=Get end point... 1 i+1
	select Sound 'fileName$'
	To Intensity... 100 0 yes
	min_cons = Get minimum... cons_start cons_end None
	max_vowel = Get maximum... vowel_start vowel_end None
	#print 'min_cons' 'newline$' 'max_vowel' 'newline$''vowel_start''newline$''vowel_end''newline$'
	intDiff = max_vowel - min_cons
	duration = (cons_end - cons_start)*1000
	fileappend 'file$'/'filename$'_output.xls 'fileName$''tab$''duration:3''tab$''intDiff:3''tab$''newline$'
endif
endfor

select all
minus Strings list
Remove

endfor
select Strings list
Remove
exit The analysis of 'filename$' is now complete, please check your Excel file in the directory 'file$'
endform
