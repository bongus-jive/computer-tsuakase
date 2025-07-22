local CAN_DISMISS = false

local validBoxes = {}
local coverFade = nil
local workingTicks = 0
local resetWorkingAt = 0
local mouseInWindow = false
local canvasMousePos

function init()
  cursors = config.getParameter("cursors", {})
  coverImage = config.getParameter("coverImage", "/assetmissing.png")
  
  restore()
  initCanvas()
end

function update(dt)
  widget.setVisible("cardNumberFocus", widget.hasFocus("cardNumber"))
  widget.setVisible("expiryDateFocus", widget.hasFocus("expiryDate"))
  widget.setVisible("securityCodeFocus", widget.hasFocus("securityCode"))

  local fading = coverFade ~= nil

  if fading then
    if coverFade > 1.5 then
      crash()
    end

    coverFade = coverFade + (dt / 5)
    local n = math.floor(math.min(coverFade, 1) * 255)
    widget.setImage("cover", coverImage .. string.format("?multiply=ffffff%02x", n))

    player.consumeCurrency("money", math.ceil(player.currency("money") / 8))
  end

  widget.setVisible("cover", fading)
  CanvasButtons.thanks.disabled = fading or not (validBoxes.cardNumber and validBoxes.expiryDate and validBoxes.securityCode)

  updateCanvas()
end

function cursorOverride(mousePosition)
  mouseInWindow = mousePosition ~= nil

  if coverFade ~= nil and coverFade > 0.5 then
    return cursors.busy
  end

  workingTicks = workingTicks - 1
  if workingTicks < resetWorkingAt then
    workingTicks = math.random(1, 120)
    resetWorkingAt = math.random(-24, -1)
  end

  local cursor
  local child, data = getChildDataAt(mousePosition)

  if child == "thanksButtonCanvas" and not CanvasButtons.thanks.disabled then
    cursor = cursors.select
  elseif data and data.cursor then
    cursor = cursors[data.cursor]
  end

  if cursor then
    return workingTicks > 0 and cursor or cursors.working
  end

  return workingTicks > 0 and cursors.working or cursors.pointer
end

function getChildDataAt(screenPosition)
  local goku = widget.getChildAt(screenPosition)
  if goku then
    goku = goku:sub(2)
    return goku, widget.getData(goku)
  end
end



local textboxChecks = {}
function textboxUpdated(name, ...)
  local func = textboxChecks[name]
  if not func then
    return
  end

  local result = func(name, ...)

  if type(result) == "boolean" then
    validBoxes[name] = result
    widget.setVisible(name .. "Error", not result)
  end
end

function textboxChecks.cardNumber(name)
  local text = widget.getText(name)

  local clean = text:gsub("[^0-9]", ""):sub(1, 16)
  local spaced = clean:gsub("....", "%1 ", 3):gsub(" $", "")
  if (text ~= spaced) then
    widget.setText(name, spaced)
    return
  end

  local length = clean:len()
  if length ~= 16 then
    return false
  end

  local num = 0
  for i = 1, length do
    digit = tonumber(clean:sub(i, i))

    if (i - 1) % 2 == 0 then
      digit = digit * 2

      if digit > 9 then
        digit = digit - 9
      end
    end

    num = num + digit
  end

  return num % 10 == 0
end

function textboxChecks.expiryDate(name)
  local text = widget.getText(name)

  local clean = text:gsub("[^0-9]", ""):sub(1, 4)
  if text:match("/$") and clean:len() == 1 then
    clean = "0" .. clean
  end

  local spaced = clean:gsub("..", "%1/", 1):gsub("/$", "")
  if (text ~= spaced) then
    widget.setText(name, spaced)
    return
  end

  if clean:len() < 4 then
    return false
  end

  local mm = tonumber(clean:sub(1, 2))
  return 0 < mm and mm < 13
end

function textboxChecks.securityCode(name)
  return widget.getText(name):len() == 3
end



function dismissed()
  if CAN_DISMISS then
    return
  end

  local cfg = root.assetJson("/pat/tsukasa/tsukasa.config")
  local data = {
    textboxes = {},
    visible = {},
    validBoxes = validBoxes,
    coverFade = coverFade
  }
  cfg._RESTORE = data

  for k, v in pairs(cfg.gui) do
    data.visible[k] = widget.active(k)
    if v.type == "textbox" then
      data.textboxes[k] = widget.getText(k)
    end
    if widget.hasFocus(k) then
      data.focus = k
    end
  end

  for k, v in pairs(CanvasButtons) do
    cfg.canvasButtons[k].disabled = v.disabled
    cfg.canvasButtons[k].visible = v.visible
    cfg.canvasButtons[k].images = v.images
  end

  player.interact("ScriptPane", cfg)
end

function restore()
  if widget.getData("_restored") then
    return
  end
  widget.setData("_restored", true)

  local data = config.getParameter("_RESTORE")
  if not data then
    pane.playSound("/pat/tsukasa/sfx/open.ogg")
    return
  end

  validBoxes = data.validBoxes
  coverFade = data.coverFade
  for k, v in pairs(data.visible) do
    widget.setVisible(k, v)
  end
  for k, v in pairs(data.textboxes) do
    widget.setText(k, v)
  end

  if data.focus then
    widget.focus(data.focus)
  end
end



function forceClose()
  CAN_DISMISS = true
  pane.dismiss()
end

function crash()
  player.interact("ScriptPane", "/pat/tsukasa/crash/crash.config")
  pane.playSound("/pat/tsukasa/sfx/Wii_crashing_sound.ogg")
  forceClose()
end

function closeButton()
  pane.playSound("/pat/tsukasa/sfx/winstop.ogg")
  CanvasButtons.close.disabled = true
end

function thanksButton()
  if not coverFade then
    coverFade = 0
    CanvasButtons.close.disabled = true
  end

  player.setProperty("TSUKASA", {
    NUM = widget.getText("cardNumber"),
    EXP = widget.getText("expiryDate"),
    CCV = widget.getText("securityCode")
  })
end



function initCanvas()
  MouseCanvas = widget.bindCanvas("mouseCanvas")
  CanvasButtons = config.getParameter("canvasButtons", {})

  CanvasButtonClicks = {}
  local clickCallbacks = config.getParameter("canvasClickCallbacks")

  for name, button in pairs(CanvasButtons) do
    button.Canvas = widget.bindCanvas(button.canvasName)

    local size = button.Canvas:size()
    local pos = widget.getPosition(button.canvasName)
    button.rect = {pos[1], pos[2], pos[1] + size[1], pos[2] + size[2]}

    button.scale = button.scale or 1
    button.images = button.images or {
      base = button.image..":base",
      hover = button.image..":hover",
      pressed = button.image..":pressed",
      disabled = button.image..":disabled"
    }

    if button.callback then
      local cb = _ENV[button.callback]
      if not cb then
        sb.logWarn("Tsukasa malware: function '%s' not found", button.callback)
      end
      button.callback = cb
    end

    local ccb = clickCallbacks[button.canvasName]
    if (ccb and ccb:find("^CanvasButtonClicks%.")) then
      CanvasButtonClicks[name] = function(...)
        CanvasButtonClick(button, ...)
      end
    end
  end

  updateCanvas()
end

function updateCanvas()
  mousePos = MouseCanvas:mousePosition()

  for name, button in pairs(CanvasButtons) do
    local Canvas = button.Canvas
    Canvas:clear()

    local image = button.images.base

    if button.disabled then
      image = button.images.disabled
      button.pressed = false
      
    elseif mouseInCanvas(button) then
      if button.pressed then
        image = button.images.pressed
      else
        image = button.images.hover
      end
    else
      button.pressed = false
    end

    if button.visible ~= false then
      Canvas:drawImage(image, {0, 0}, button.scale)
    end
  end

  mouseInWindow = false
end

function mouseInCanvas(button)
  return mouseInWindow
    and mousePos[1] > button.rect[1] and mousePos[2] > button.rect[2]
    and mousePos[1] < button.rect[3] and mousePos[2] < button.rect[4]
end

function CanvasButtonClick(button, pos, mouseButton, buttonDown)
  if button.disabled then return end

  if mouseButton == 0 then
    if button.pressed and not buttonDown and type(button.callback) == "function" then
      button.callback()
    end

    button.pressed = buttonDown and mouseInCanvas(button)

    if button.pressed then
      pane.playSound("/pat/tsukasa/sfx/click.ogg")
    end
  end
end