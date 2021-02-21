-- Pilgrimage
--
--
-- Seven pilgims walk,
-- Traveling through time
--   and space.
-- The Shrike travels too.

local MusicUtil    = require "musicutil"
local MollyThePoly = require "molly_the_poly/lib/molly_the_poly_engine"

local rnd = include "lib/random"
local lfo = include "lib/lfo"

local CLOCK_DIVS    = { 1/16, 1/8, 1/4, 1/2, 1, 2, 4, 8, 16, 32, 64 }
local seqs          = {}
local seq_idx       = nil
local preview_idx   = nil
local step_idx      = 0
local edit_note_idx = 1
local alt           = false
local lfo_targets   = {"none"}

engine.name = "MollyThePoly"

local function local_scale()
  return MusicUtil.generate_scale(params:get("root"), params:string("scale"), 1)
end
local function global_scale()
  return MusicUtil.generate_scale(24 + params:get("root") % 12, params:string("scale"), 8)
end

local function regen_seq(id)
  local r = rnd()
  r:seed(params:get("seq_"..id.."_seed"))

  local buckets = {}
  local scale_len = #local_scale() - 1
  local full_scale = global_scale()
  local root_idx = tab.key(full_scale, params:get("root"))
  for i=1, #full_scale-1 do
    if full_scale[i] < params:get("root") - params:get("seq_"..id.."_lower_bound") then
    elseif full_scale[i] > params:get("root") + params:get("seq_"..id.."_upper_bound") then
    else
      dist_from_root = (i-root_idx) % scale_len
      -- we down sample the chance by 10 to improve performance
      for j=1, params:get("seq_"..id.."_note_"..(dist_from_root+1).."_chance")/10 do
        buckets[#buckets+1] = full_scale[i]
      end
    end
  end

  local seq_len = params:get("seq_"..id.."_len")
  local seq = {}
  for i=1,seq_len do
    should_rest = r:next_float() * 100 < params:get("seq_1_rest_chance")
    note = buckets[math.ceil(r:next_float() * #buckets)]
    if should_rest or #buckets == 0 then
      seq[i] = -1
    else
      seq[i] = note
    end
  end

  seqs[id] = seq
  return seq
end

local function loop()
  while true do
    clock.sync(CLOCK_DIVS[params:get("clock_div")])

    if params:get("seq_"..seq_idx.."_infinite") == 1 then
      step_idx = 1
      local r = rnd()
      r:seed(params:get("seq_"..seq_idx.."_seed"))
      -- there are 2 calls to r:next_float() per seq step
      -- so if we move the seed forward two steps, it makes the sequence scroll
      -- infinitely
      r:next_float()
      r:next_float()
      params:set("seq_"..seq_idx.."_seed", r.state)
    else
      step_idx = util.wrap(step_idx + 1, 1, #seqs[seq_idx])
    end

    engine.noteOffAll()
    if seqs[seq_idx][step_idx] ~= -1 then
      note_num = seqs[seq_idx][step_idx]
      engine.noteOn(note_num, MusicUtil.note_num_to_freq(note_num), 127)
    end

    redraw()
  end
end

function lfo.process()
  for i=1,4 do
    local target = lfo_targets[params:get(i.."lfo_target")]

    if target ~= "none" and params:get(i .. "lfo") == 2 then
      local range = params:get_range(target)
      local val = util.linlin(-1, 1, range[1], range[2], lfo[i].slope)
      params:set(target, val)
    end
  end

  redraw()
end

function init_params()
  params:add{
    type="number", id="root",
    min=24, max=128, default=60,
    formatter=function (p)return MusicUtil.note_num_to_name(p:get(), true)end
  }
  params:set_action("root", function() for i=1,#seqs do regen_seq(i) end end)
  params:add{
    type="number", id="scale",
    min=1, max=#MusicUtil.SCALES, default=1,
    formatter=function (p) return MusicUtil.SCALES[p:get()].name end
  }
  params:set_action("scale", function() for i=1,#seqs do regen_seq(i) end end)

  params:add{
    type="option", id="clock_div", options=CLOCK_DIVS,
    default=4
  }

  local num_seqs = 16
  params:add_group("Sequences", num_seqs*18)
  for i=1,num_seqs do
    prefix = "seq_"..i.."_"
    params:add_number(prefix.."seed", prefix.."seed", math.mininteger, math.maxinteger, 1)
    params:set_action(prefix.."seed", function() regen_seq(i) end)
    params:add_binary(prefix.."infinite", prefix.."infinite", "toggle")
    params:set_action(prefix.."infinite", function() regen_seq(i) end)
    params:add_number(prefix.."len", prefix.."len", 1, 16, 16)
    params:set_action(prefix.."len", function() regen_seq(i) end)
    params:add_number(prefix.."upper_bound", prefix.."upper_bound", 0, 24, 12)
    params:set_action(prefix.."upper_bound", function() regen_seq(i) end)
    params:add_number(prefix.."lower_bound", prefix.."lower_bound", 0, 24, 0)
    params:set_action(prefix.."lower_bound", function() regen_seq(i) end)
    params:add_number(prefix.."rest_chance", prefix.."rest_chance", 0, 100, 10)
    params:set_action(prefix.."rest_chance", function() regen_seq(i) end)
    params:hide(prefix.."rest_chance")

    lfo_targets[#lfo_targets+1] = prefix.."upper_bound"
    lfo_targets[#lfo_targets+1] = prefix.."lower_bound"
    lfo_targets[#lfo_targets+1] = prefix.."rest_chance"

    for j=1,12 do
      params:add_number(prefix.."note_"..j.."_chance", prefix.."note_"..j.."_chance", 0, 100, 50)
      params:set_action(prefix.."note_"..j.."_chance", function() regen_seq(i) end)
      params:hide(prefix.."note_"..j.."_chance")
      lfo_targets[#lfo_targets+1] = prefix.."note_"..j.."_chance"
    end

    regen_seq(i)
  end

  params:add_group("Synth", 46) -- 46 is hardcoded to the number of params in molly_the_poly
  MollyThePoly.add_params()
end

function init()
  init_params()

  seq_idx = 1

  for i=1,4 do
    lfo[i].lfo_targets = lfo_targets
  end
  lfo.init()

  clock.run(loop)
end

function key(n,z)
  if n==1 then
    alt = z==1

    if alt==true  then preview_idx = seq_idx end
    if alt==false then seq_idx = preview_idx end
  end

  if n==2 and z==1 and alt==false then edit_note_idx = util.wrap(edit_note_idx - 1, 0, #local_scale()-1) end
  if n==3 and z==1 and alt==false then edit_note_idx = util.wrap(edit_note_idx + 1, 0, #local_scale()-1) end

  redraw()
end

function enc(n,d)
  local prefix = "seq_"..seq_idx.."_"

  if n==1 and alt==false then
    seq_idx = util.clamp(seq_idx + d, 1, #seqs)
  end
  if n==1 and alt==true then
    preview_idx = util.clamp(preview_idx + d, 1, #seqs)
  end
  if n==2 and alt==false then
    local key = edit_note_idx == 0 and prefix.."rest_chance" or prefix.."note_"..edit_note_idx.."_chance"
    params:delta(key, d)
  end
  if n==3 and alt==true then
    params:delta(prefix.."seed", d)
  end

  redraw()
end

function redraw()
  screen.clear()

  for i=1, #seqs do
    screen.level((seq_idx == i or preview_idx == i) and 15 or 1)
    screen.move((i-1) * 128/#seqs, 1)
    screen.line_rel(128/#seqs - 1, 0)
    screen.stroke()
  end

  local function draw_chance(title, amt, selected, pos)
    screen.level(selected and 15 or 1)

    screen.move(pos[1], pos[2])
    screen.text(title)
    screen.move(pos[1], pos[2] + 2)
    screen.line_rel(12*amt/100, 0)
    screen.stroke()
  end

  local draw_seq_idx = alt and preview_idx or seq_idx

  draw_chance("0", params:get("seq_"..draw_seq_idx.."_rest_chance"), edit_note_idx == 0, {0, 10})
  local s = local_scale()
  for i=1, #s-1 do
    draw_chance(
      MusicUtil.note_num_to_name(s[i]),
      params:get("seq_"..draw_seq_idx.."_note_"..i.."_chance"),
      i == edit_note_idx,
      {i*14, 10}
    )
  end

  seq = seqs[draw_seq_idx]
  root = params:get("root")
  for i=1,#seq do
    screen.level(i == step_idx and 15 or 1)
    if seq[i] ~= -1 then
      dist_from_root = seq[i] - root
      screen.move((i-1) * (128/#seq), 40 - dist_from_root)
      screen.line_rel((128/#seq), 0)
      screen.stroke()
    end
  end

  screen.update()
end
