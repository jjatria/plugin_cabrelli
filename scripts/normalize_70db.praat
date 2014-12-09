## scale intensity (energy) with output - BCLT1.praat
## Created by Mark Antoniou
## C 2010 Northwestern University

##What does this script do?
##Reads in sound files.
##Outputs duration, original intensity, and new intensity measurements.
##Scales the entire soundfile so that the vowel's intensity will now equal dB_target.

#Specify the directory where the oriignal files are located, where the scaled files should be created, and the target dB value.
form Enter directory and search string
#Be sure not to forget the slash (Windows: backslash, OSX: forward slash) at the end of the directory name.
	sentence directory /Users/jennifer/Desktop/Separate audio files/
	sentence outDirectory /Users/jennifer/Desktop/normalized/
	sentence filetype .wav
	integer dB_target 70.00
	sentence outFile measurementsBCLT1
endform

#Create measurements file
fileappend 'outDirectory$''outFile$'.txt filename,
           ...duration,original_dB,scaled_dB,
           ...'newline$'
		   
#Loop for all files  
Create Strings as file list... fileList 'directory$'*'filetype$'
number_of_files = Get number of strings
for soundfilenumber from 1 to number_of_files
   
    #Read in sound file and textgrid
    select Strings fileList
    current_file$ = Get string... soundfilenumber
    dotInd = rindex(current_file$, ".")
    fileNoextension$ = left$(current_file$, dotInd - 1)
    Read from file... 'directory$''current_file$'
    object_name$ = selected$ ("Sound")

    #Get duration and intensity (dB) before scaling
    select Sound 'object_name$'
    original_duration = Get total duration
    original_dB = Get intensity (dB)
	
	#Scale the entire sound object
    Scale intensity... 70.00

    #Get scaled intensity
    scaled_dB = Get intensity (dB)
	
	#Save the newly scaled soundfile
    Save as WAV file... 'outDirectory$''object_name$''filetype$'

		  	fileappend 'outDirectory$''outFile$'.txt 'object_name$',
	          	 ...'original_duration','original_dB','scaled_dB',
	          	 ...'newline$'
endfor

#Empty Praat Objects window
select all
Remove

#Let the user know that it's all over
printline ------------------------------------------------
print All files have been scaled.
printline This is where you'll find them:
printline 'outDirectory$'
