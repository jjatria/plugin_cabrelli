# Semi-auto Formant object wizard
#
# This script is heavily inspired from Dan McCloy's Semi-auto Formant Tracker,
# although it has been almost entirely rewritten to make use of the new syntax
# as well as the object-cycling features implemented in JJATools.
#
# Provided with a directory with sound files, the script will loop through each
# one and provide an interface to adjust the formant tracker parameters used by
# Praat. The user may choose to open an accompanying TextGrid annotation to
# facilitate navigation, and this will more likely be the most common use
# scenario.
#
# If provided with annotations, the script will extract the relevant intervals
# (as matched using regular expressions) and provide measurements for them. The
# wizard allows for easy navigation not only through each sound file (using the
# "<<" and ">>" buttons) but also through the relevant intervals (using the
# "<" and ">" buttons, if any exist).
#
# Results from the analysis are stored in a Table object. Saving this to disk is
# left to the user.
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

include ../../plugin_jjatools/procedures/check_directory.proc
jjatools$ = "../../plugin_jjatools/"

form Semi-auto formant detection...
  sentence Sound_directory
  sentence TextGrid_directory
  integer  TextGrid_tier 1 (=0 to ignore TextGrids)
  sentence Label_regex [aeiou]
  integer  Measures_per_interval 3 (=0 for average)
  positive Start_from_file 1
  real     Max_formant_(Hz) 5500
  real     Number_of_formants 5
  real     Preemphasis_from_(Hz) 50
  positive Window_length 0.025
  positive Dynamic_range 30
endform

# Set default values
default.max_formant       = max_formant
default.total_formants    = number_of_formants
default.measured_formants = 3
default.dynamic_range     = dynamic_range
default.window_length     = window_length
default.preemphasis       = preemphasis_from
default.tier              = textGrid_tier
default.regex$            = label_regex$
default.measures          = measures_per_interval
default.dot_size          = 1

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
if default.tier
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

# Initialise the object list, which will keep information about processed files
object_list = Create Table with column names: "object_list", 0,
  ... "name max_formant total_formants preemphasis window_length"

# Initialise the output table
output_columns$ = "name file_name label percent time "
for f to default.measured_formants
  output_columns$ = output_columns$ + "f" + string$(f) + " "
endfor
output_columns$ = output_columns$ +
  ... "max_formant preemphasis window_length total_formants notes"
output = Create Table with column names: "formant_output", 0, output_columns$

removeObject: sound_list
if default.tier
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
  local.formant = 0
  local.current_interval = 0
  if default.tier
    local.full_textgrid = selected("TextGrid")
    selectObject: local.full_textgrid
    viewEach.pair = Extract one tier: default.tier
    Rename: viewEach.pair_name$

    @findIntervals()
    valid_intervals = findIntervals.table

    if default.measures
      for .i to default.measured_formants
        Insert point tier: 2, "F" + string$(.i)
      endfor
      @insertTextGridPoints()
    else
      for .i to default.measured_formants
        Insert interval tier: 2, "F" + string$(.i)
      endfor
      @insertTextGridIntervals()
    endif
  endif

  selectObject: object_list
  .exists = Search column: "name", viewEach.base_name$
  if !.exists
    local.max_formant    = default.max_formant
    local.total_formants = default.total_formants
    local.preemphasis    = default.preemphasis
    local.window_length  = default.window_length

    selectObject: object_list
    Append row
    Set string value:  Object_'object_list'.nrow, "name",    viewEach.base_name$
  else
    .row = .exists
    local.max_formant    = Object_'object_list'[.row, "max_formant"]
    local.total_formants = Object_'object_list'[.row, "total_formants"]
    local.preemphasis    = Object_'object_list'[.row, "preemphasis"]
    local.window_length  = Object_'object_list'[.row, "window_length"]
  endif

  viewEach_pause.button = undefined
  @makeFormant()
endproc

# Executes at the beginning of the editor window, for each iteration
procedure viewEach_atBeginEditor ()
  Show analyses: "yes", "yes", "no", "yes", "no", 10
  Spectrogram settings: 0, 5000, 0.005, 50
  Advanced spectrogram settings: 1000, 250,
    ... "Fourier", "Gaussian", "yes", 100, 6, 0
  Formant settings: default.max_formant, default.total_formants,
    ... default.window_length, default.dynamic_range, default.dot_size
  Advanced formant settings: "Burg", default.preemphasis
endproc

# Defines the pause that occurs at each iteration
# This is where most of the logic for this script is defined.
procedure viewEach_pause ()
  label PAUSE_START
  .interval = 0
  .intervals = if default.tier then Object_'valid_intervals'.nrow else 0 fi
  repeat
    if .interval
      editor 'viewEach.editor_name$'
        Zoom: Object_'valid_intervals'[.interval, "start"],
          ... Object_'valid_intervals'[.interval, "end"]
      endeditor
    else
      if .button != undefined
        @makeFormant()
      endif
    endif

    selectObject: object_list
    .object_row = Search column: "name", viewEach.base_name$

    beginPause: "Adjust formant tracker settings"
    comment: "File " + viewEach.base_name$ + " " +
      ... "(" + string$(viewEach.i) + " of " + string$(viewEach.n) + ")" +
      ... if default.tier and .interval then
        ... "; Interval " + string$(.interval) + " of " + string$(.intervals)
        ... else "" fi
    comment: "Adjusts formant settings if the formant track doesn't look right."
    integer: "Max_formant", local.max_formant
    integer: "Total_formants", local.total_formants
    boolean: "Set as default", 0
    sentence: "Notes", ""

    .stop = 1
    .back$          = if viewEach.i > 1 then """""<<"""", " else "" fi
    .prev_interval$ = if default.tier   then """""<"""", "  else "" fi
    .next_interval$ = if default.tier   then """"">"""", "  else "" fi
    .forward$       = if viewEach.i = viewEach.n then
      ... """""Finish""""" else """"">>""""" fi
    .buttons$ = """Stop"", '.back$' '.prev_interval$' ""Redraw"", '.next_interval$' '.forward$'"

    .stop          = 1
    .back          = 0
    .prev_interval = 0
    .redraw        = 1
    .next_interval = 0
    .forward       = 1
    if default.tier
      .prev_interval = 1
      .next_interval = 1
    endif
    if viewEach.i > 1
      .back = 1
    endif

    .button_counter = 1
    if .back
      .button_counter += 1
      .back = .button_counter
    endif
    if .prev_interval
      .button_counter += 1
      .prev_interval = .button_counter
    endif
    .button_counter += 1
    .redraw = .button_counter
    if .next_interval
      .button_counter += 1
      .next_interval = .button_counter
    endif
    .button_counter += 1
    .forward = .button_counter

    .button = endPause: '.buttons$', 1, 1

    if .button != .stop
      local.max_formant    = max_formant
      local.total_formants = total_formants
      local.notes$ = notes$

      if set_as_default
        default.max_formant    = local.max_formant
        default.total_formants = local.total_formants
      endif

      if .button = .redraw
        editor 'viewEach.editor_name$'
          Formant settings: local.max_formant, local.total_formants,
            ... local.window_length, default.dynamic_range, default.dot_size
        endeditor
        .interval = 0
      elsif .button = .next_interval or .button = .prev_interval
        .interval += if .button = .next_interval then 1 else -1 fi
        .interval = .interval mod (.intervals + 1)
        if !.interval
          .interval += if .button = .next_interval then 1 else -1 fi
        endif
        .interval = if .interval < 0 then
          ... .intervals else .interval fi
        .button = .redraw
      endif
    endif

  until .button != .redraw

  if .button != .stop
    selectObject: object_list
    Set numeric value: .object_row, "max_formant",    local.max_formant
    Set numeric value: .object_row, "total_formants", local.total_formants
    Set numeric value: .object_row, "window_length",  local.window_length
    Set numeric value: .object_row, "preemphasis",    local.preemphasis
#     Set string value:  .object_row, "notes",          notes$
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
    @getMeasures(1)
    .next = if viewEach.i = viewEach.n then 0 else 1 fi
  endif
endproc

procedure viewEach_atEndIteration ()
  removeObject: local.formant
  if default.tier
    removeObject: viewEach.pair, valid_intervals
  endif
endproc

include ../../plugin_jjatools/procedures/view_each.from_disk.proc

# Call the main procedure
@viewEachFromDisk(files, 1)

# Clean up.
removeObject: object_list

# Local procedures
# These procedures are only used for this script

procedure getMeasures (.output)
  nocheck editor 'viewEach.editor_name$'
    @inEditor()
    nocheck Close
  nocheck editor

  selectObject: viewEach.pair
  .tiers = Get number of tiers

  if default.tier
    for .r to Object_'valid_intervals'.nrow
      .start    = Object_'valid_intervals'[.r, "start"]
      .end      = Object_'valid_intervals'[.r, "end"]
      .length   = .end - .start

      selectObject: viewEach.pair
      if default.measures
        .first_point = Get high index from time: 2, .start
        .step = (.end - .start) / (default.measures + 1)
        for .m to default.measures
          .time = .start + (.step * .m)
          .point = .first_point + .m - 1
          for .f to default.measured_formants
            selectObject: viewEach.pair
            .tier = .tiers - (.f - 1)
            .interval = Get interval at time: .tier, .start + (.length / 2)
            .label$ = Get label of interval: 1, .interval
            selectObject: local.formant
            .value = Get value at time: .f, .time, "Hertz", "Linear"
            if .output
              @writeOutput: viewEach.base_name$,
                ... sound_path$ + viewEach.base_name$ + ".wav",
                ... .label$, (.m / default.measures) * 100, .time,
                ... .f, .value)
            else
              selectObject: viewEach.pair
              Set point text: .tier, .point, fixed$(.value, 0)
            endif
          endfor
        endfor
      else
        for .f to default.measured_formants
          selectObject: viewEach.pair
          .tier = .tiers - (.f - 1)
          .interval = Get interval at time: .tier, .start + (.length / 2)
          .label$ = Get label of interval: 1, .interval
          selectObject: local.formant
          .value = Get mean: .f, .start, .end, "Hertz"
          if .output
            @writeOutput: viewEach.base_name$,
              ... sound_path$ + viewEach.base_name$ + ".wav",
              ... .label$, 0, 0, .f, .value)
          else
            selectObject: viewEach.pair
            Set interval text: .tier, .interval, fixed$(.value, 0)
          endif
        endfor
      endif
    endfor
  endif
  if inEditor.return
    selectObject: viewEach.base
    if default.tier
      plusObject: viewEach.pair
    endif
    View & Edit
  endif
endproc

procedure insertTextGridPoints ()
  .tiers = Get number of tiers

  for .r to Object_'valid_intervals'.nrow
    .i = Object_'valid_intervals'[.r, "interval"]
    .start = Object_'valid_intervals'[.r, "start"]
    .end   = Object_'valid_intervals'[.r, "end"]
    if default.measures
      .step = (.end - .start) / (default.measures + 1)
      for .m to default.measures
        .time = .start + (.step * .m)
        for .f to default.measured_formants
          .tier = .tiers - (.f - 1)
          Insert point: .tier, .time, ""
        endfor
      endfor
    endif
  endfor
endproc

procedure insertTextGridIntervals ()
  .tiers = Get number of tiers

  for .r to Object_'valid_intervals'.nrow
    .interval = Object_'valid_intervals'[.r, "interval"]
    .start    = Object_'valid_intervals'[.r, "start"]
    .end      = Object_'valid_intervals'[.r, "end"]
    for .f to default.measured_formants
      .tier = .tiers - (.f - 1)
      nocheck Insert boundary: .tier, .start
      nocheck Insert boundary: .tier, .end
    endfor
  endfor
endproc

procedure findIntervals ()
  .table = Create Table with column names: "valid_intervals", 0,
    ... "interval start end"
  selectObject: viewEach.pair
  .intervals = Get number of intervals: 1
  for .i to .intervals
    selectObject: viewEach.pair
    .label$ = Get label of interval: 1, .i
    if index_regex(.label$, default.regex$)
      .start = Get start point: 1, .i
      .end   = Get end point: 1, .i
      selectObject: .table
      Append row
      Set numeric value: Object_'.table'.nrow, "interval", .i
      Set numeric value: Object_'.table'.nrow, "start",    .start
      Set numeric value: Object_'.table'.nrow, "end",      .end
    endif
  endfor
endproc

procedure makeFormant ()
  if local.formant
    removeObject: local.formant
  endif
  selectObject: viewEach.base
  local.formant = To Formant (burg): 0,
    ... local.total_formants, local.max_formant,
    ... local.window_length,  local.preemphasis

  if default.tier
    @getMeasures(0)
  endif
endproc

procedure writeOutput (.name$, .filename$, .label$, .percent, .time, .formant, .value)
  selectObject: output
  Append row
  .row = Object_'output'.nrow
  Set string value:  .row, "name",          .name$
  Set string value:  .row, "file_name",     .filename$
  Set string value:  .row, "label",         .label$
  Set string value:  .row, "percent",        fixed$(.percent, 0)
  Set numeric value: .row, "time",          .time
  Set numeric value: .row, "max_formant",    local.max_formant
  Set numeric value: .row, "total_formants", local.total_formants
  Set numeric value: .row, "preemphasis",    local.preemphasis
  Set numeric value: .row, "window_length",  local.window_length
  Set string value:  .row, "notes",          local.notes$
  Set string value:  .row, "f" + string$(.formant),
    ... if .value != undefined then fixed$(.value, 2) else "NA" fi
endproc
