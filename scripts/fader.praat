# Fade sound in and out
#
# Author: José Joaquín Atria
#
# This script is free software: you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation, either version 3 of
# the License, or (at your option) any later version.
#
# A copy of the GNU General Public License is available at
# <http://www.gnu.org/licenses/>.

form Fader...
  real Fade_in_length_(s) 0.075
  real Fade_out_length_(s) 0.075
  optionmenu Method: 1
    option Linear
    option Cosine
endform

in = fade_in_length
out = fade_out_length

n = numberOfSelected("Sound")
for i to n
  sound[i] = selected(i)
endfor
for i to n
  select sound[i]
  # from http://www.holgermitterer.eu/HM/fade_in_out_cos_square.praat
  if in
    if method = 1
      Formula... if x < 'in' then self * (1- (cos(0.5 * pi * (x / 'in'))^2))  else self fi
    else
      Formula... if x < 'in' then self * (x / 'in') else self fi
    endif
  endif
  if out
    finish = Get end time
    if method = 1
      Formula... if (x > ('finish' - 'out')) then self * (1- (cos((0.5 * pi * (( 'finish' - x ) / 'out')))^2)) else self fi
    else
      Formula... if (x > ('finish' - 'out')) then self * (('finish'- x) / 'out') else self fi
    endif
  endif
endfor
