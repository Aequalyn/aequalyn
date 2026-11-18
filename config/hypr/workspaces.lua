---------------------------------------------------------------------- workspaces
-- Reserve 10 numbered workspaces per monitor with stable global ids
-- (1-10 on the first monitor, 11-20 on the second, ...). `persistent` keeps
-- empty slots alive: Hyprland otherwise destroys them, which shifts the
-- per-monitor positions that `r~N` and the bar's pills both use.
do
  local mons = hl.get_monitors()
  table.sort(mons, function(a, b) return a.id < b.id end)
  for idx, mon in ipairs(mons) do
    local base = (idx - 1) * 10
    for n = 1, 10 do
      hl.workspace_rule({ workspace = tostring(base + n), monitor = mon.name, persistent = true })
    end
  end
end

