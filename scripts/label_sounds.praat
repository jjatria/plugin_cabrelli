# Semi-auto sound labeler
#
# This is the skeleton of a sound labeler script, so far mostly copied
# from the Formant maker.
#
# This script is part of the Cabrelli plugin (this is a working title).
#
# Version 0.0.1 - first working version
# Date: December 17, 2014
# Author: José Joaquín Atria
#
# This script is free software: you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation, either version 3 of
# the License, or (at your option) any later version.
#
# A copy of the GNU General Public License is available at
# <http://www.gnu.org/licenses/>.

clearinfo

include ../../plugin_jjatools/procedures/find_in_strings.proc
include ../../plugin_jjatools/procedures/check_directory.proc
jjatools$ = "../../plugin_jjatools/"

form Semi-auto sound labeler...
  sentence Input_path
  sentence Output_path
  sentence Interval_tiers Mary John
  sentence Point_tiers bell
endform

# Use GUI for sound directory selection if not manually provided
@checkDirectory(input_path$, "Read Sounds from...")
input_path$ = checkDirectory.name$

runScript: jjatools$ + "strings/file_list_full_path.praat", 
  ... "sounds_fullpath", input_path$, "*wav", 1
sound_list      = selected(1)
sound_full_list = selected(2)
selectObject: sound_list
Rename: "sounds"
total_sounds = Get number of strings

# Use GUI for output directory selection if not manually provided
@checkDirectory(output_path$, "Save TextGrids to...")
output_path$ = checkDirectory.name$

textgrid_list = Create Strings as file list: "textgrids",
  ... output_path$ + "*TextGrid"
total_textgrids = Get number of strings

if total_textgrids
  beginPause: "TextGrids found"
  comment: "The output directory already contains some TextGrids"
  comment: "Do you want to continue from the first unpaired Sound?"
  button = endPause: "Cancel", "Continue", "From start", 2, 1
  if button = 1
    @cleanUp()
    exit
  elsif button = 2
    @findFirstUnpaired()
  elsif button = 3
    viewEach.from_start = 1
  endif
endif

# Procedure overrides
#
# The object cycling features in JJATools provide hooks to specify code to be
# executed at specific points during each iteration. In order to inject that
# code, specific procedures have to be locally defined before we include the
# main procedure definitions.
#
# Some internal variables are used (they start with "viewEach", but care must be
# used not to modify them, which might have unexpected results.

# Executes at the beginning of each iteration
procedure viewEach_atBeginIteration ()
  if textgrid_list
    selectObject: textgrid_list
    @findInStrings(viewEach.base_name$ + ".TextGrid", 0)
    if findInStrings.return
      viewEach.pair = Read from file: output_path$ +
        ... viewEach.base_name$ + ".TextGrid"
    else
      selectObject: viewEach.base
      viewEach.pair = To TextGrid: interval_tiers$ + " " + point_tiers$,
        ... point_tiers$
    endif
  endif

  selectObject: viewEach.pair
  viewEach.pair_type$   = extractWord$(selected$(), "")
  viewEach.pair_name$   = selected$(viewEach.pair_type$)
  viewEach.editor_name$ = selected$()
  selectObject: viewEach.base, viewEach.pair
endproc

# Executes at the beginning of the editor window, for each iteration
# procedure viewEach_atBeginEditor ()
# endproc

# Defines the pause that occurs at each iteration
# This is where most of the logic for this script is defined.
# procedure viewEach_pause ()
# endproc

procedure viewEach_atEndEditor ()
  endeditor

  if !variableExists(".button")
    .button = undefined
  endif

  selectObject: viewEach.pair
  .filename$ = viewEach.pair_name$ + ".TextGrid"

  if !viewEach_pause.next
    Remove
  endif

  if numberOfSelected("TextGrid")
    ... and fileReadable(output_path$ + .filename$)

    if .button = undefined
      beginPause: .filename$ + " exists: Overwrite?"
      boolean: "Apply to all", 0
      .button = endPause: "Stop", "Discard", "Overwrite", 2, 1
    endif

    if .button = 1
      Remove
      viewEach_pause.next = 0
    elsif .button = 2
      Remove
    endif

    if !apply_to_all
      .button = undefined
    endif
  endif

  if numberOfSelected("TextGrid")
    selectObject: viewEach.pair
    Save as text file: output_path$ + .filename$
    Remove
    selectObject: textgrid_list
    @findInStrings(.filename$, 0)
    if !findInStrings.return
      Insert string: 1, .filename$
    endif
  endif

  nocheck editor 'viewEach.editor_name$'
    nocheck Close
  nocheck endeditor
endproc

include ../../plugin_jjatools/procedures/view_each.from_disk.proc

# Call the main procedure
@viewEachFromDisk(sound_full_list, 1)

# Clean up.
@cleanUp()

# Local procedures
# These procedures are only used for this script

procedure cleanUp ()
  nocheck removeObject: sound_list
  nocheck removeObject: textgrid_list
endproc

procedure findFirstUnpaired ()
  .i = 0

  repeat
    .i += 1
    selectObject: sound_list
    .name$ = Get string: .i
    selectObject: textgrid_list
    @findInStrings(.name$ - "wav" + "TextGrid" , 0)
    .exists = findInStrings.return
  until .i = total_sounds or !.exists

  if .exists
    @cleanUp()
    exitScript: "No unpaired Sound objects." + newline$
  else
    viewEach.start_from = .i
  endif
endproc
