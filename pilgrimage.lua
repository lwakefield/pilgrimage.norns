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

local CLOCK_DIVS    = { 1/64, 1/32, 1/16, 1/8, 1/4, 1/2, 1, 2, 4, 8, 16, 32, 64 }
local seqs          = {}
local seq_idx       = nil
local preview_idx   = nil
local step_idx      = 0
local edit_note_idx = 1
local alt           = false

engine.name = "MollyThePoly"

function choose_from_buckets (buckets, rand)
  local max = 0
  for i=1,#buckets do max = max+buckets[i] end

  choice = rand() * max

  local acc = 0
  for i=1,#buckets do
    if choice < acc+buckets[i] then return i end
    acc = acc + buckets[i]
  end

  return -1
end

local function local_scale()
  return MusicUtil.generate_scale(params:get("root"), params:string("scale"), 1)
end
local function global_scale()
  return MusicUtil.generate_scale(24 + params:get("root") % 12, params:string("scale"), 8)
end

local function regen_seq(id)
  local r = rnd()
  r:seed(params:get("seq_"..id.."_seed"))

  local scale_len = #local_scale() - 1
  local full_scale = global_scale()

  local buckets = {}

  local root_idx = tab.key(full_scale, params:get("root"))
  for i=1, #full_scale-1 do
    if full_scale[i] < params:get("root") - params:get("seq_"..id.."_lower_bound") then
      buckets[i] = 0
    elseif full_scale[i] > params:get("root") + params:get("seq_"..id.."_upper_bound") then
      buckets[i] = 0
    else
      dist_from_root = (i-root_idx) % scale_len
      buckets[i] = params:get("seq_"..id.."_note_"..(dist_from_root+1).."_chance")
    end
  end

  local seq_len = params:get("seq_"..id.."_len")
  local seq = {}
  for i=1,seq_len do
    should_rest = r:next_float() * 100 < params:get("seq_1_rest_chance")
    bucket = choose_from_buckets(buckets, function() return r:next_float() end)
    if should_rest or bucket == -1 then
      seq[i] = -1
    else
      seq[i] = full_scale[bucket]
    end
  end

  seqs[id] = seq
  return seq
end

local function loop()
  while true do
    clock.sync(CLOCK_DIVS[params:get("clock_div")])

    step_idx = util.wrap(step_idx + 1, 1, #seqs[seq_idx])
    engine.noteOffAll()
    if seqs[seq_idx][step_idx] ~= -1 then
      note_num = seqs[seq_idx][step_idx]
      engine.noteOn(note_num, MusicUtil.note_num_to_freq(note_num), 127)
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
  params:set_action("root", function() for i=1,#seqs do regen_seq(i) end end)
  params:add{
    type="number", id="scale",
    min=1, max=#MusicUtil.SCALES, default=1,
    formatter=function (p) return MusicUtil.SCALES[p:get()].name end
  }
  params:set_action("scale", function() for i=1,#seqs do regen_seq(i) end end)

  params:add{
    type="option", id="clock_div", options=CLOCK_DIVS,
    default=6
  }

  params:add_group("Sequences", 272)
  for i=1,16 do
    prefix = "seq_"..i.."_"
    params:add_number(prefix.."seed", prefix.."seed", 1, math.maxinteger, 1)
    params:set_action(prefix.."seed", function() regen_seq(i) end)
    params:add_number(prefix.."len", prefix.."len", 1, 128, 16)
    params:set_action(prefix.."len", function() regen_seq(i) end)
    params:add_number(prefix.."upper_bound", prefix.."upper_bound", 0, 48, 12)
    params:set_action(prefix.."upper_bound", function() regen_seq(i) end)
    params:add_number(prefix.."lower_bound", prefix.."lower_bound", 0, 48, 0)
    params:set_action(prefix.."lower_bound", function() regen_seq(i) end)
    params:add_number(prefix.."rest_chance", prefix.."rest_chance", 0, 100, 10)
    params:set_action(prefix.."rest_chance", function() regen_seq(i) end)
    params:hide(prefix.."rest_chance")
    for j=1,12 do
      params:add_number(prefix.."note_"..j.."_chance", prefix.."note_"..j.."_chance", 0, 100, 50)
      params:set_action(prefix.."note_"..j.."_chance", function() regen_seq(i) end)
      params:hide(prefix.."note_"..j.."_chance")
    end
    regen_seq(i)
  end

  params:add_group("Synth", 46) -- 46 is hardcoded to the number of params in molly_the_poly
  MollyThePoly.add_params()

  seq_idx = 1
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
  if n==3 and alt==false then
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
