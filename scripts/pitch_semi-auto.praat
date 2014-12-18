# Semi-auto Pitch object wizard
#
# This script is heavily inspired from Dan McCloy's Semi-auto Pitch Extractor,
# although it has been almost entirely rewritten to make use of the new syntax
# as well as the object-cycling features implemented in JJATools.
#
# Provided with a directory with sound files, the script will loop through each
# one and provide an interface to adjust the pitch detection parameters used by
# Praat. Optionally, the user may choose to open an accompanying TextGrid
# annotation to facilitate navigation.
#
# Unlike McCloy's original script, this one is not designed to be run on long
# files, and the ideal sound it will have to deal with will contain a single
# utterance. The main effect this design difference has (and the main difference
# these two scripts have) is that this one does not deal with zoom levels at
# all, leaving that to the user.
#
# Another difference is the approach taken for the manual editing of Pitch
# objects. In the case of this script, this is done by providing the user with
# the chance to enter the Pitch editor for the current Sound object, using the
# parameters that are chosen at that time. As an added feature, these parameters
# (specifically, pitch floor and ceiling) can be automatically estimated from
# the current utterance by means of Hirst and de Looze's two-pass
# approach [1,2].
#
# This script is part of the Cabrelli plugin (this is a working title).
#
# Version 0.0.1 - first working version
# Date: December 17, 2014
# Author: José Joaquín Atria
#
# [1] Hirst, 2011. "The analysis by synthesis [...]", JoSS 1(1): 55-83
# [2] De Looze and Hirst, 2008. "Detecting changes in key [...]", Speech Prosody
#
# This script is free software: you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation, either version 3 of
# the License, or (at your option) any later version.
#
# A copy of the GNU General Public License is available at
# <http://www.gnu.org/licenses/>.

include ../../plugin_jjatools/procedures/check_directory.proc
include ../../plugin_jjatools/procedures/pitch_two-pass.proc
jjatools$ = "../../plugin_jjatools/"

form Semi-auto pitch detection...
  sentence Sound_directory
  sentence TextGrid_directory
  sentence Output_directory
  boolean  Use_TextGrids 0
  integer  Start_from_file 1 (=0 for first without Pitch)
  real     left_Default_pitch_range_(Hz)  75
  real     right_Default_pitch_range_(Hz) 600
  comment  Set either to 0 for automatic per-utterance estimation
endform

# Set default values for floor and ceiling
default.pitch_floor   = left_Default_pitch_range
default.pitch_ceiling = right_Default_pitch_range

# Use GUI for sound directory selection if not manually provided
@checkDirectory(sound_directory$, "Read Sounds from...")
sound_path$ = checkDirectory.name$

# Generate a sound list using full paths
sound_list = Create Strings as file list: "sounds",
  ... sound_path$ + "*wav"
runScript: jjatools$ + "strings/replace_strings.praat",
  ... "^(.*)", sound_path$ + "\1", 1
sound_full_list = Rename: "sounds_fullpath"

# If we are using TextGrids, process them as well
if use_TextGrids
  @checkDirectory(textGrid_directory$, "Read TextGrids from...")
  textgrid_path$ = checkDirectory.name$

  # Generate an annotation list using full paths
  textgrid_list = Create Strings as file list: "textgrids",
    ... textgrid_path$ + "*TextGrid"
  runScript: jjatools$ + "strings/replace_strings.praat",
    ... "^(.*)", textgrid_path$ + "\1", 1
  # removeObject: textgrid_list
  textgrid_full_list = Rename: "textgrids_fullpath"

  # Generate an aggregated full-path list for Sounds and TextGrids
  selectObject: sound_full_list, textgrid_full_list
  files = Append
  removeObject: sound_full_list, textgrid_full_list
else
  # If we are not using TextGrids, the file list will only have sounds
  files = sound_full_list
endif

# Provide a GUI selector for the output directory
@checkDirectory(output_directory$, "Save Pitch objects to...")
pitch_path$ = checkDirectory.name$

# Read existing Pitch objects from that directory. This will later be used to
# check whether a specific Sound has a Pitch object associated with it
pitch_list = Create Strings as file list: "pitchs",
  ... pitch_path$ + "*Pitch"

# Initialise the object list, which will keep information about processed files
object_list = Create Table with column names: "object_list", 0,
  ... "name floor ceiling pitch notes"

# The user may choose to start from whichever sound does not have a Pitch object
# associated with it. In that case, we loop through the sounds to find which one
# that is
if !start_from_file
  i = 0
  selectObject: sound_list
  total_sounds = Get number of strings
  repeat
    i += 1
    name$ = Get string: i
    found = !fileReadable(pitch_path$ + name$ - "wav" + "Pitch")
  until i > total_sounds or found
  if !found
    # If all sound files have a Pitch object, then no work is needed, and we can
    # exit
    exitScript: "All Sound objects have a Pitch object"
  else
    # If we found the appropriate file, then use that as a starting point
    start_from_file = i
  endif
endif

removeObject: sound_list
if use_TextGrids
  removeObject: textgrid_list
endif

viewEach.start_from = start_from_file

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
  selectObject: object_list
  .exists = Search column: "name", viewEach.base_name$
  if !.exists
    local.pitch_floor   = default.pitch_floor
    local.pitch_ceiling = default.pitch_ceiling

    if !local.pitch_floor or !local.pitch_ceiling
      @twoPass(viewEach.base)
    endif

    selectObject: object_list
    Append row
    Set string value:  Object_'object_list'.nrow, "name",    viewEach.base_name$
  else
    .row = .exists
    local.pitch_floor   = Object_'object_list'[.row, "floor"]
    local.pitch_ceiling = Object_'object_list'[.row, "ceiling"]
  endif

  @pitchExists(viewEach.base_name$ + ".Pitch")
  local.has_pitch = pitchExists.return
endproc

# Executes at the beginning of the editor window, for each iteration
procedure viewEach_atBeginEditor ()
  Show analyses: "yes", "yes", "no", "no", "no", 10
  Spectrogram settings: 0, 2000, 0.025, 50
  Advanced spectrogram settings: 1000, 250,
    ... "Fourier", "Gaussian", "yes", 100, 6, 0
  Pitch settings: local.pitch_floor, local.pitch_ceiling,
    ... "Hertz", "autocorrelation", "automatic"
  Advanced pitch settings: 0, 0, "no", 15, 0.03, 0.45, 0.01, 0.35, 0.14
endproc

# Defines the pause that occurs at each iteration
# This is where most of the logic for this script is defined.
procedure viewEach_pause ()
  label PAUSE_START
  repeat
    selectObject: object_list
    .object_row = Search column: "name", viewEach.base_name$

    if !local.has_pitch and (!local.pitch_floor or !local.pitch_ceiling)
      @twoPass(viewEach.base)
    endif

    beginPause: "Adjust pitch analysis settings"
    comment: "File " + viewEach.base_name$ + " " +
      ... "(" + string$(viewEach.i) + " of " + string$(viewEach.n) + ")"
    if local.has_pitch
      comment: "There is already a Pitch object for this file. " +
        ... "Press Edit to view."
    else
      comment: "You can change the pitch settings " +
        ... "if the pitch track doesn't look right."
    endif
    real: "Pitch_floor", local.pitch_floor
    real: "Pitch_ceiling", local.pitch_ceiling
    boolean: "Set as default", 0
    sentence: "Notes", ""
    if local.has_pitch
      comment: "Press Reset to ignore existing Pitch object"
    endif

    .stop = 1
    if viewEach.i > 1
      .button = endPause: "Stop", "<",
        ... if local.has_pitch then "Reset" else "Redraw" fi, "Edit",
        ... if viewEach.i = viewEach.n then "Finish" else ">" fi, 3, 1
      .back       = 2
      .redraw     = 3
      .edit_pitch = 4
      .forward    = 5
    else
      .button = endPause: "Stop",
        ... if local.has_pitch then "Reset" else "Redraw" fi, "Edit",
        ... if viewEach.i = viewEach.n then "Finish" else ">" fi, 2, 1
      .back       = 0
      .redraw     = 2
      .edit_pitch = 3
      .forward    = 4
    endif

    if .button != .stop
      local.pitch_floor   = pitch_floor
      local.pitch_ceiling = pitch_ceiling

      if set_as_default
        default.pitch_floor   = local.pitch_floor
        default.pitch_ceiling = local.pitch_ceiling
      endif

      if !local.pitch_floor or !local.pitch_ceiling
        @twoPass(viewEach.base)
      endif

      if .button = .redraw
        local.has_pitch = 0
        editor 'viewEach.editor_name$'
          Pitch settings: local.pitch_floor, local.pitch_ceiling,
            ... "Hertz", "cross-correlation", "automatic"
        endeditor
      endif
    endif

  until .button != .redraw

  if .button != .stop
    selectObject: object_list
    Set numeric value: .object_row, "floor",   local.pitch_floor
    Set numeric value: .object_row, "ceiling", local.pitch_ceiling
    Set string value:  .object_row, "notes",   notes$

    .pitch = undefined
    if !local.has_pitch and .button = .forward
      selectObject: viewEach.base
      .pitch = To Pitch: 0, local.pitch_floor, local.pitch_ceiling
    endif

    if .button = .edit_pitch
      if local.has_pitch
        .pitch = Read from file: pitch_path$ + viewEach.base_name$ + ".Pitch"
      endif
      selectObject: .pitch
      .pitch_name$ = selected$()
      View & Edit
      beginPause: "Edit Pitch object"
      comment: "Press OK to accept and continue, or Cancel to go back"
      .pitch_button = endPause: "Cancel", "OK", 2, 1
      if .pitch_button = 1
        nocheck editor 'pitch_name$'
          nocheck Close
        nocheck endeditor
        selectObject: .pitch
        Remove
        goto PAUSE_START
      else
        .button = .forward
      endif
    endif

    if .button = .forward and .pitch != undefined
      selectObject: .pitch
      .pitch_name$ = selected$("Pitch")
      .pitch_filename$ = .pitch_name$ + ".Pitch"
      if fileReadable(pitch_path$ + .pitch_filename$)
        beginPause: "File exists. Overwrite?"
        .overwrite = endPause: "No", "Yes", 1, 1
        .overwrite -= 1
      else
        .overwrite = 1
      endif
      if .overwrite
        Save as text file: pitch_path$ + .pitch_filename$
      endif
      Remove

      @pitchExists(.pitch_filename$)
      if !pitchExists.return
        selectObject: pitch_list
        Insert string: 1, .pitch_filename$
      endif

      selectObject: object_list
      Set string value: .object_row, "pitch", .pitch_name$
    endif
  endif

  # The viewEach() procedure in JJATools expects a .next variable with the item
  # to be shown next. This variable can have one of three possible values:
  #   * -1, to go to the previous object
  #   * +1, to go to the next object
  #   *  0, to exit
  if .button = .stop
    # Pressed stop
    .next = 0
  elsif .button = .back
    # Pressed back
    .next = -1
  elsif .button = .forward
    # Pressed forward
    .next = if viewEach.i = viewEach.n then 0 else 1 fi
  endif
endproc

# Include the main procedures. Local overrides must be defined before this line
include ../../plugin_jjatools/procedures/view_each.from_disk.proc

# Call the main procedure
@viewEachFromDisk(files, 1)

# Clean up.
removeObject: object_list, pitch_list

# Local procedures
# These procedures are only used for this script

# Estimate pitch floor and ceiling values from utterance
procedure twoPass (.id)
  .info$ = nocheck Editor info
  if .info$ != ""
    .editor_name$ = extractLine$(.info$, "Editor name: ")
    .editor_name$ = extractLine$(.info$, ". ")
    endeditor
  endif
  selectObject: .id
  @pitchTwoPass(0.75, 1.5)
  Remove
  local.pitch_floor   = pitchTwoPass.floor
  local.pitch_ceiling = pitchTwoPass.ceiling
  if .info$ != ""
    editor '.editor_name$'
  endif
endproc

# Check whether a Pitch object with that name exists
procedure pitchExists (.name$)
  selectObject: pitch_list
  Sort
  .words = To WordList
  .return = Has word: .name$
  removeObject: .words
endproc
