# Floating workspaces

Floating is an Aequalyn arrangement, not a Hyprland layout name. The generated
`workspace-layouts.lua` therefore never contains `layout = "floating"`; it calls
the guarded `_G.aequalyn_floating` shim instead. The compositor keeps its normal
tiled layout underneath, so bad or stale rules cannot stop the session loading.

Windows on a Floating workspace become ordinary Hyprland floating windows. They
are tagged as managed by Aequalyn, so leaving the workspace restores their old
state; windows the user floated by hand are left alone. If the compositor's
window-tagging API is unavailable, the module does nothing.

Decorations are optional. When `~/.local/lib/aequalyn/hyprbars.so` exists and
loads, floating windows get a titlebar with minimize, maximize and close
buttons: green with `_` for minimize, yellow with a square for maximize, and red
for close. A missing plugin, an older Hyprland, or
`AEQUALYN_NO_FLOAT_DECORATIONS=1` simply leaves decorations off — none of them
prevents the shell or compositor from starting.

Floating windows size themselves by their edges and corners: hovering near an
edge shows the resize cursor and dragging resizes the window. The module enables
Hyprland's border-resize with a widened grab area so the corners are easy to
catch.

A newly opened window on a Floating workspace is sized to half of the monitor's
logical resolution. The monitor's live scale and reserved edges are used, and
the decorated titlebar is counted inside that half, so the whole window starts
at half the screen instead of only its client area. The window is sized once on
open; later manual resizes are left alone.

The snap flyout is a shell plugin. Leave the pointer in the top edge strip for a
moment and it opens; dragging a floating window up to the same strip also opens
it, and `Super + G` remains a manual alternative. Every layout is offered in a
single row; clicking one switches the same popup to a larger chooser for that
layout's areas. Click the area you want and the focused window is snapped there,
with the other floating windows on that workspace filling the remaining areas.
Clicking outside the flyout dismisses it without changing anything.

The strip starts just below any bar or dock on the top edge; with those panels
elsewhere it starts at the monitor's top edge. Hyprland's reserved top edge
includes every exclusive layer there, so a bar and dock stacked together move
the trigger down as one. No window needs to be dragged or pushed off screen.
After a snap or cancel the flyout stays closed through the short cooldown that
covers the window move, then re-arms once the pointer has left the strip. The
area under the pointer when the flyout opened is preselected, and the final
window geometry is derived from the monitor's current resolution, converted from
physical to logical pixels with the live scale, so the placed window fills
exactly the area shown in the flyout.

Zones are laid out inside the monitor's usable area, using its live `reserved`
edges, so the bar is avoided wherever it sits (top, bottom, left or right). The
titlebar is drawn above the geometry reported for the client, so its height is
reserved inside each zone; the whole decorated window fits the highlighted
rectangle instead of spilling over it.

The last snap is remembered. Moving the bar to a different edge changes the
monitor's reserved sides, and the snapped windows are re-placed into the same
arrangement and zone automatically, so they stay inside the new usable area.
Changing bar settings never clears the per-workspace layout assignments.

The migration `migrations/20261121-1.sh` repairs stale generated rules, adds
Floating once to an explicit `Super + L` cycle, and adds the `Super + G` key to
existing installs without overwriting a user's own binding.
