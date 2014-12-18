# Extract and prepare sounds
#
# Design:  Jennifer Cabrelli, Jose Joaquin Atria
# Coding:  Jose Joaquin Atria
#
# Version: 0.0.1
#
# This script is free software: you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation, either version 3 of
# the License, or (at your option) any later version.
#
# A copy of the GNU General Public License is available at
# <http://www.gnu.org/licenses/>.

form Extract and prepare sounds...
  positive Tier 1
  positive Normal_intensity_(dB) 70
  sentence Extraction_regex [aeiou]
  positive Ramp_length_(s) 0.015
  sentence Save_to
endform

include ../../plugin_jjatools/procedures/check_directory.proc
include ../../plugin_jjatools/procedures/selection.proc
jjatools$ = preferencesDirectory$ + "/plugin_jjatools/"

interval_padding = 0

sound = if numberOfSelected("Sound") then
  ... selected("Sound") else 0 fi
textgrid = if numberOfSelected("TextGrid") then
  ... selected("TextGrid") else 0 fi
longsound = if numberOfSelected("LongSound") then
  ... selected("LongSound") else 0 fi

@checkDirectory(save_to$, "Save extracted sounds to...")
save_to$ = checkDirectory.name$

if textgrid and (sound or longsound)
  selectObject: textgrid
  textgrid_name$ = selected$("TextGrid")
  interval_tier = Is interval tier: tier
  if interval_tier

    if sound
      selectObject: textgrid, sound
      # Move boundaries to zero-crossings
      runScript: jjatools$ + "textgrid/move_to_zero_crossings.praat",
        ... tier,
        ... 0,
        ... "yes"
    endif

    # Extract labeled intervals
    runScript: jjatools$ + "textgrid/extract_labels.praat",
      ... tier,
      ... interval_padding,
      ... "no",
      ... extraction_regex$,
      ... "yes",
      ... "Use script replacements"

    # By default, extracted Sounds have TextGrid name in their name
    # We remove this <- is this a good choice?
    @saveSelection()
    for i to saveSelection.n
      selectObject: saveSelection.id[i]
      part_name$ = selected$("Sound")
      part_name$ = replace$(part_name$, textgrid_name$ + "_", "", 0)
      Rename: part_name$
    endfor
    @restoreSelection()

    # Ramp beginning and ends of sounds
    if ramp_length
      # TODO
    endif

    # Normalize to specified mean intensity (RMS)
    runScript: jjatools$ + "sound/rms_normalize.praat", normal_intensity,
      ... "no", "yes", "no"

    # Save extracted Sounds to disk
    runScript: jjatools$ + "management/save_all.praat", save_to$, 1

    # Remove from list
    Remove
  endif

  removeObject: textgrid, if sound then sound else longsound fi
endif
