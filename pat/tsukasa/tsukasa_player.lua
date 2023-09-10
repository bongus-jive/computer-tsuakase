local t = math.random(120, 360)

function init()
  script.setUpdateDelta(60)
end

function update()
  t = t - 1
  if t > 0 then return end

  t = math.random(120, 360);

  if (math.random() < 0.2) then
    player.interact("ScriptPane", "/pat/tsukasa/tsukasa.config");
  end
end