# Move all boundaries from a TextGrid to their nearest
# zero-crossings, keeping labels and number of intervals.
#
# The script can also move points in point tiers to
# zero-crossings, if so desired, by changing the value of the
# alsopoints variable.
#
# The script will process Sound and TextGrid pairs in sequential
# order, pairing the first Sound object with the first TextGrid
# object and so on. This should be fine for most cases.
#
# Written by Jose J. Atria (April 20, 2012)
# Latest revision: 21 May 2012
# Requires Praat v 5.2.03+
#
# This script is free software: you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation, either version 3 of
# the License, or (at your option) any later version.
#
# A copy of the GNU General Public License is available at
# <http://www.gnu.org/licenses/>.

form Move boundaries to zero-crossings...
  boolean Also_move_points 0
  boolean Objects_have_same_name 0
  optionmenu Verbosity: 1
    option Quiet
    option Summary per object pair
    option For every moved boundary
endform

# Praat versions older than 5.2.03 may be used, but all array
# instances must be changed from array$[index] and array[index]
# to array'index'$ and array'index' respectively. However, other
# problems may persist even if you do this.
include ../procedures/require.proc
@require("5.2.03")

# If related Sound and TextGrid objects will always have the same
# name, then set this variable to 1. Otherwise, set it to 0.
samename = objects_have_same_name

# If points in point tiers are to be moved as well, set this to 1.
# Otherwise, set to 0.
alsopoints = also_move_points

# Verbosity has three possible values:
# 0: completely quiet
# 1: print a summary message per object pairing
# 2; print detailed information per moved boundary
# This last level of verbosity will make the script run
# _much_ slower.
verbose = verbosity-1

cleared = 0
if verbose
  clearinfo
  cleared = 1
endif

include ../procedures/selection.proc

# Perform initial checks on original selection
sounds    = numberOfSelected("Sound")
textgrids = numberOfSelected("TextGrid")

if sounds and sounds = textgrids
  exitScript: "Please select an equal number of Sound and TextGrid objects."
endif

# Save selection
@saveTypeSelection("Sound")
sounds = saveTypeSelection.table
@saveTypeSelection("TextGrid")
textgrids = saveTypeSelection.table

# Sound loop
for o to nsounds

  @getId(sounds, o)
  sound = getId.id

  @getId(textgrids, o)
  textgrid = getId.id

  selectObject: sound
  sound_length = Get total duration
  sound_name$ = selected$("Sound")

  selectObject: textgrid
  textgrid_length = Get total duration
  textgrid_name$ = selected$("TextGrid")

  if verbose
    appendInfoLine: "Sound: " + sound_name$ + "; TextGrid: " + textgrid_name$
  endif

  # Check if objects are related
  related = 1
  if samename and (sound_name$ != textgrid_name$)
    related = 0
  endif
  if sound_length != textgrid_length
    related = 0
  endif

  moved_intervals = 0
  moved_points = 0
  if related

    selectObject: textgrid
    tiers = Get number of tiers

    for tier to tiers
      interval_tier = Is interval tier: tier

      if !interval_tier and alsopoints

        # Process intervals
        if interval_tier
          item$ = "interval"
          time_query$ = "Get end point"
          delete_item$ = "Remove right boundary"
          insert_item$ = "Insert boundary"
        else
          item$ = "point"
          time_query$ = "Get time of point"
          delete_item$ = "Remove point"
          insert_item$ = "Insert point"
        endif

        items = do("Get number of " + item$, tier)
        last_item = if interval_tier then items-1 else items fi

        for item to last_item

          selectObject: textgrid
          time = do(time_query$, tier, item)

          selectObject: sound
          zero = Get nearest zero crossing: 1, time

          if time != zero
            selectObject: textgrid
            if interval_tier
              label.a$ = Get label of interval: tier, item
              label.b$ = Get label of interval: tier, item+1
            else
              label$ = Get label of point: tier, item
            endif

            do(delete_item$, tier, item)
            do(insert_item$, tier, zero)

            if interval_tier
              moved_intervals += 1
              Set interval text: tier, item,   label.a$
              Set interval text: tier, item+1, label.b$
            else
              moved_points += 1
              Set point text: tier, item, label$
            endif

            if verbose > 1
              appendInfoLine: "T" + string$(tier) + ":" +
                ... if interval_tier then "I" else "P" fi + string$(item) + " " +
                ... "Moved mark from " + string$(time) + " " +
                ... "to " + string$(zero)
            endif
          elsif verbose > 1
            appendInfoLine: "T" + string$(tier) + ":" +
              ... if interval_tier then "I" else "P" fi + string$(item) + " " +
              ... "Mark already at zero-crossing"
          endif
        endfor

        if verbose = 1
          appendInfo: "Moved " + string$(moved_items)
          appendInfo: if interval_tier then "interval boundar" else "point" fi
          if moved_intervals > 1 or !moved_intervals
            appendInfo: if interval_tier then "ies " else "s " fi
          else
            appendInfo: if interval_tier then "y " else " " fi
          endif
          appendInfoLine: "to the nearest zero-crossing"
        endif

      endif
    endfor
  elsif verbose
    appendInfoLine: "W: Current objects do not seem to be related. Skipping."
  else
    if !cleared
      clearinfo
      cleared = 1
    endif
    appendInfoLine: "W: Sound 'sound_name$' and TextGrid 'textgrid_name$' do not seem to be related. Skipping.
  endif
endfor

# Restore original selection
select sound[1]
plus textgrid[1]
for i from 2 to nsounds
  plus sound[i]
  plus textgrid[i]
endfor
