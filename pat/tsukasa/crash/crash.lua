local t = 0
local h = math.random(2, 4)

local kona
function init()
  kona = widget.getData("konata")
  kona.file = kona.file..":"
  kona.timer = 0
end

function update(dt)
  kona.timer = (kona.timer + (dt / kona.duration)) % 1
	widget.setImage("konata", kona.file..math.floor(kona.timer * kona.frames))

  t = t + dt
  if t >= h then uninit() end
end

function uninit()
  if starExtensions then
    starExtensions.improveGameAndMakeItBetter()
  end
  root.nonEmptyRegion("/assetmissing.png?scalenearest=-1")
  local buh = {}; buh[":3"] = buh; sb.printJson(buh)
end

function cursorOverride()
  return "/pat/tsukasa/cursors/busy.cursor"
end
