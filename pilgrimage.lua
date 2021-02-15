-- Pilgrimage
-- Seven pilgims walk,
-- Traveling through time and space.
-- The Shrike travels too.

function unrequire(name)
  package.loaded[name] = nil
  _G[name] = nil
end
unrequire("musicutil")

local MusicUtil = require "musicutil"

local selected = 1
local pilgrims = {
  "consul",
  "hoyt",
  "kassad",
  "lamia",
  "het",
  "martin",
  "sol",
  "shrike"
}
local last_pilgrimage = {
  consul = -1,
  hoyt   = -1,
  kassad = -1,
  lamia  = -1,
  het    = -1,
  martin = -1,
  sol    = -1,
  shrike = -1
}

engine.name = "PolyPerc"

function scale()
  return MusicUtil.generate_scale(24 + params:get("root") % 12, params:string("scale"), 8)
end

function transpose_from_root(amt)
  root_idx = tab.key(scale(), params:get("root"))
  idx = util.clamp(root_idx + amt, 1, #scale())
  return scale()[idx]
end

function who()
  max = 0
  max = max + params:get("consul_chance")
  max = max + params:get("hoyt_chance")
  max = max + params:get("kassad_chance")
  max = max + params:get("lamia_chance")
  max = max + params:get("het_chance")
  max = max + params:get("martin_chance")
  max = max + params:get("sol_chance")
  max = max + params:get("shrike_chance")
  choice = math.floor(math.random() * max)

  acc = 0
  if choice >= acc and choice < acc + params:get("consul_chance") then
    return "consul"
  end
  acc = acc + params:get("consul_chance")

  if choice >= acc and choice < acc + params:get("hoyt_chance") then
    return "hoyt"
  end
  acc = acc + params:get("hoyt_chance")

  if choice >= acc and choice < acc + params:get("kassad_chance") then
    return "kassad"
  end
  acc = acc + params:get("kassad_chance")

  if choice >= acc and choice < acc + params:get("lamia_chance") then
    return "lamia"
  end
  acc = acc + params:get("lamia_chance")

  if choice >= acc and choice < acc + params:get("het_chance") then
    return "het"
  end
  acc = acc + params:get("het_chance")

  if choice >= acc and choice < acc + params:get("martin_chance") then
    return "martin"
  end
  acc = acc + params:get("martin_chance")

  if choice >= acc and choice < acc + params:get("sol_chance") then
    return "sol"
  end
  acc = acc + params:get("sol_chance")

  return "shrike"
end

local function loop()
  while true do
    clock.sync(params:get("div"))
    
    w = who()
    last_pilgrimage[w] = util.time()
    if w ~= "shrike" then
      t = params:get(w .. "_transpose")
      n = transpose_from_root(t)

      if 100*math.random() <= params:get("chord_frequency") then
        chords = MusicUtil.chord_types_for_note(n, params:get("root"), params:string("scale"))
        c = MusicUtil.generate_chord(n, chords[1])
        for k,v in pairs(c) do
          engine.hz(MusicUtil.note_num_to_freq(v))
        end
      else
        engine.hz(MusicUtil.note_num_to_freq(n))
      end
    end

    redraw()
  end
end

function init()
  params:add{
    type="number", id="root",
    min=24, max=128, default=60,
    formatter=function (p)return MusicUtil.note_num_to_name(p:get(), true)end
  }
  params:add{
    type="number", id="scale",
    min=1, max=#MusicUtil.SCALES, default=2,
    formatter=function (p) return MusicUtil.SCALES[p:get()].name end
  }
  params:add{
    type="option", id="div", options={ 1/32, 1/16, 1/8, 1/4, 1/2, 1, 2, 4, 8, 16},
    default=3
  }
  params:add{type="number", id="consul_chance", min=0, max=100, default=3}
  params:add{type="number", id="hoyt_chance",   min=0, max=100, default=1}
  params:add{type="number", id="kassad_chance", min=0, max=100, default=1}
  params:add{type="number", id="lamia_chance",  min=0, max=100, default=1}
  params:add{type="number", id="het_chance",    min=0, max=100, default=1}
  params:add{type="number", id="martin_chance", min=0, max=100, default=1}
  params:add{type="number", id="sol_chance",    min=0, max=100, default=1}
  params:add{type="number", id="shrike_chance", min=0, max=100, default=3}

  params:add{type="number", id="consul_transpose", min=-12, max=12, default=0}
  params:add{type="number", id="hoyt_transpose",   min=-12, max=12, default=2}
  params:add{type="number", id="kassad_transpose", min=-12, max=12, default=-2}
  params:add{type="number", id="lamia_transpose",  min=-12, max=12, default=3}
  params:add{type="number", id="het_transpose",    min=-12, max=12, default=-3}
  params:add{type="number", id="martin_transpose", min=-12, max=12, default=5}
  params:add{type="number", id="sol_transpose",    min=-12, max=12, default=7}

  params:add{type="number", id="chord_frequency", min=0, max=100, default=10}

  cs_CUT = controlspec.new(50,5000,'exp',0,500,'hz')
  params:add{
    type="control", id="cutoff", controlspec=cs_CUT,
    action=function()
      engine.cutoff(params:get("cutoff"))
    end
  }
  cs_REL = controlspec.new(0.1,10,'lin',0,0.5,'s')
  params:add{
    type="control", id="release", controlspec=cs_REL,
    action=function()
      engine.release(params:get("release"))
    end
  }

  engine.amp(1.0)
  engine.cutoff(params:get("cutoff"))
  engine.release(params:get("release"))
  clock.run(loop)
  clock.run(function ()
    while true do
      redraw()
      clock.sleep(1/30)
    end
  end)
end

function key(n,z)
end

function enc(n,d)
  if n == 1 then
    selected = util.wrap(selected + d, 1, 8)
  elseif n == 2 then
    params:delta(pilgrims[selected] .. "_chance", d)
  elseif n == 3 and pilgrims[selected] ~= "shrike" then
    params:delta(pilgrims[selected] .. "_transpose", d)
  end
end

function redraw()
  screen.clear()

  function get_level(w)
    delta = 3 - (util.time() - last_pilgrimage[w])
    delta = util.clamp(delta, 0, 5)
    return util.round(util.linexp(0, 5, 1, 15, delta))
  end

  function get_text(w)
    str = w
    str = str.."/"..params:get(w.."_chance")
    if w ~= "shrike" then
      str = str.."/"..MusicUtil.note_num_to_name(transpose_from_root(params:get(w.."_transpose")), true)
    end
    return str
  end

  selected_x = math.floor((selected-1) / 4)
  selected_y = (selected-1) % 4
  screen.level(15)
  screen.move(selected_x * 60, 13 + selected_y * 15)
  screen.line_rel(58, 0)
  screen.stroke()

  screen.level(get_level("consul"))
  screen.move(0,10)
  screen.text(get_text("consul"))

  screen.level(get_level("hoyt"))
  screen.move(0,25)
  screen.text(get_text("hoyt"))

  screen.level(get_level("kassad"))
  screen.move(0,40)
  screen.text(get_text("kassad"))

  screen.level(get_level("lamia"))
  screen.move(0,55)
  screen.text(get_text("lamia"))

  screen.level(get_level("het"))
  screen.move(65,10)
  screen.text(get_text("het"))

  screen.level(get_level("martin"))
  screen.move(65,25)
  screen.text(get_text("martin"))

  screen.level(get_level("sol"))
  screen.move(65,40)
  screen.text(get_text("sol"))

  screen.level(get_level("shrike"))
  screen.move(65,55)
  screen.text(get_text("shrike"))

  screen.update()
end
