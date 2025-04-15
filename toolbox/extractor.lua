#!/usr/bin/env lua

-- depends on luasql
-- map pngs with alpha channel generated with:
-- `convert $file  -transparent white -resize '100x100!' $file`

local debugsql = {
  ["areatrigger"] = { "Using only client-data to find areatrigger locations" },
  --
  ["units"] = { "Iterate over all creatures using mangos data" },
  ["units_faction"] = { "Using mangos and client-data to find unit faction" },
  ["units_coords"] = { "Using mangos and client-data to find unit locations" },
  ["units_coords_pool"] = { "Only applies to CMaNGOS(TBC) to find pooled unit locations" },
  ["units_event"] = { "Using mangos data to find spawns from events" },
  ["units_event_map_object"] = { "Using mangos data to determine map based on object requirements associated with event" },
  ["units_event_spell"] = { "Using mangos data to find spells associated with spawn" },
  ["units_event_spell_map_object"] = { "Using mangos data to determine map based on objects associated with spawn spells" },
  ["units_event_spell_map_item"] = { "Using mangos data to determine map based on items associated with spawn spells" },
  ["units_summon_fixed"] = { "Using mangos data to find units that summon others and use their map with fixed spawn positions" },
  ["units_summon_unknown"] = { "Using mangos data to find units that summon others and use their coordinates as target spawn positions" },
  --
  ["objects"] = { "Iterate over all gameobjects using mangos data" },
  ["objects_faction"] = { "Using mangos and client-data to find object faction" },
  ["objects_coords"] = { "Using mangos and client-data to find unit locations" },
  --
  ["items"] = { "Iterate over all items using mangos data" },
  ["items_container"] = { "Using mangos data to find items that are looted from other items" },
  ["items_unit"] = { "Using mangos data to find units that drop an item" },
  ["items_object"] = { "Using mangos data to find objects that drop an item" },
  ["items_reference"] = { "Using mangos data to query for shared loot lists" },
  ["items_vendor"] = { "Using mangos data to find vendors for items" },
  ["items_vendortemplate"] = { "Using mangos data to find vendor templates of the item" },
  --
  ["refloot"] = { "Using mangos data to find shared loot lists" },
  ["refloot_unit"] = { "Using mangos data to find units for shared loot" },
  ["refloot_object"] = { "Using mangos data to find objects for shared loot" },
  --
  ["quests"] = { "Using mangos data to iterate over all quests" },
  ["quests_events"] = { "Using mangos data to detect event quests" },
  ["quests_eventscreature"] = { "Using mangos data to detect event quests based on creature" },
  ["quests_eventsobjects"] = { "Using mangos data to detect event quests based on objects" },
  ["quests_prequests"] = { "Using mangos data to detect pre-quests based on other quests next entries" },
  ["quests_prequestchain"] = { "Using mangos data to detect quest-chains based on other quests next entries" },
  ["quests_questspellobject"] = { "Using mangos data find objects associated with quest_template spell requirements" },
  ["quests_credit"] = { "Only applies to CMaNGOS(TBC) to find units that give shared credit to the quest" },
  ["quests_item"] = { "Using mangos data to scan through all items with spell requirements" },
  ["quests_itemspell"] = { "Using mangos data to scan through spells that apply to the given item" },
  ["quests_itemspellcreature"] = { "Using mangos data to find all creatures that are a spell target of the given item" },
  ["quests_itemspellobject"] = { "Using mangos data to find all objects that are a spell target of the given item" },
  ["quests_itemspellscript"] = { "Using mangos data to find all scripts that are a spell target of the given item" },
  ["quests_itemobject"] = { "Using mangos database and client data to search for object that can be used via item" },
  ["quests_itemcreature"] = { "Using mangos database and client data to search for creature that can be target of item" },
  ["quests_areatrigger"] = { "Using mangos data to find associated areatriggers" },
  ["quests_starterunit"] = { "Using mangos data to search for quest starter units" },
  ["quests_starterobject"] = { "Using mangos data to search for quest starter objects" },
  ["quests_starteritem"] = { "Using mangos data to search for quest starter items" },
  ["quests_enderunit"] = { "Using mangos data to search for quest ender units" },
  ["quests_enderobject"] = { "Using mangos data to search for quest ender objects" },
  --
  ["zones"] = { "Using client data to read zone data" },
  --
  ["minimap"] = { "Using client data to read minimap zoom levels" },
  --
  ["meta_taxi"] = { "Using client and mangos data to find flight masters" },
  ["meta_rares"] = { "Using client and mangos data to find rare mobs" },
  ["meta_farm"] = { "Using client and mangos data to find chests, herbs and mines" },
  --
  ["locales_unit"] = { "Using mangos data to find unit translations" },
  ["locales_object"] = { "Using mangos data to find object translations" },
  ["locales_item"] = { "Using mangos data to find item translations" },
  ["locales_quest"] = { "Using mangos data to find quest translations" },
  ["locales_profession"] = { "Using client and mangos data to find profession translations" },
  ["locales_zone"] = { "Using client and mangos data to find zone translations" },
}

-- limit all sql loops
local limit = nil
function debug(name)
  -- count sql debugs
  debugsql[name][2] = debugsql[name][2] or 0
  debugsql[name][2] = debugsql[name][2] + 1

  -- abort here when no debug limit is set
  if not limit then return nil end
  return debugsql[name][2] > limit or nil
end

function debug_statistics()
  for name, data in pairs(debugsql) do
    local count = data[2] or 0
    if count == 0 then
      print("WARNING: \27[1m\27[31m" .. count .. "\27[0m \27[1m" .. name .. "\27[0m \27[2m-- " .. data[1] .. "\27[0m")
    end
    debugsql[name][2] = nil
  end
end

-- local associations
local all_locales = {
  ["enUS"] = 0,
  ["koKR"] = 1,
  ["frFR"] = 2,
  ["deDE"] = 3,
  ["zhCN"] = 4,
  ["zhTW"] = 5,
  ["esES"] = 6,
  ["ruRU"] = 8,
  ["itIT"] = 9,
  ["ptBR"] = 10,
}

local config = {
  -- known expansions and their config
  expansions = {
    {
      name = "vanilla",
      core = "vmangos",
      database = "vmangos",
      locales = all_locales,
      custom = false,
    },
  },

  -- core-type database column glue tables
  -- every table column name that differs
  -- from cmangos should be listed here
  cores = {
    ["vmangos"] = {
      ["Id"] = "entry",
      ["Entry"] = "entry",
      ["Faction"] = "faction",
      ["Name"] = "name",
      ["MinLevel"] = "level_min",
      ["MaxLevel"] = "level_max",
      ["Rank"] = "rank",
      ["RequiresSpellFocus"] = "requiresSpellFocus",
      ["dbscripts_on_event"] = "event_scripts",
      ["VendorTemplateId"] = "vendor_id",
      ["NpcFlags"] = "npc_flags",
      ["EffectTriggerSpell"] = "effectTriggerSpell",
      ["Map"] = "map_bound",
      ["startquest"] = "start_quest",
      ["targetEntry"] = "target_entry",
    },
  }
}

if false then
  -- add turtle settings to expansions
  table.insert(config.expansions, {
    name = "turtle",
    core = "vmangos",
    database = "turtle",
    locales = { ["enUS"] = 0 },
    custom = true,
  })
end

do -- map lookup functions
  maps = {}
  package.path = './pngLua/?.lua;' .. package.path
  require("png")

  function isFile(name)
    if type(name) ~= "string" then return false end
    if not (os.rename(name, name) and true or false) then return false end
    local f = io.open(name)
    if not f then return false end
    f:close()
    return true
  end

  function isValidMap(map, x, y, expansion)
    local id = map .. expansion

    -- load map if required
    if not maps[id] then
      local preferred = string.format("maps/%s/%s.png", expansion, map)
      local fallback = string.format("maps/%s.png", map)

      if isFile(preferred) then
        maps[id] = pngImage(preferred)
      elseif isFile(fallback) then
        maps[id] = pngImage(fallback)
      end
    end

    -- no mapfile means valid map
    if not maps[id] then return true end

    -- error handling
    if not maps[id].getPixel then return false end
    if x == 0 or y == 0 then return false end

    -- check pixel alpha
    local pixel = maps[id]:getPixel(x, y)
    if pixel and pixel.A and pixel.A > 0 then
      return true
    else
      return false
    end
  end
end

do -- helper functions
  function round(input, places)
    if not places then places = 0 end
    if type(input) == "number" and type(places) == "number" then
      local pow = 1
      for i = 1, places do pow = pow * 10 end
      local result = math.floor(input * pow + 0.5) / pow
      return result == math.floor(result) and math.floor(result) or result
    end
  end

  function sanitize(str)
    str = string.gsub(str, "\\", "\\\\")
    str = string.gsub(str, "\"", "\\\"")
    str = string.gsub(str, "\'", "\\\'")
    str = string.gsub(str, "\r", "")
    str = string.gsub(str, "\n", "")
    return str
  end

  -- http://lua-users.org/wiki/SortedIteration
  function __genOrderedIndex(t)
    local orderedIndex = {}
    for key in pairs(t) do
      table.insert(orderedIndex, key)
    end
    table.sort(orderedIndex)
    return orderedIndex
  end

  function orderedNext(t, state)
    local key = nil
    if state == nil then
      t.__orderedIndex = __genOrderedIndex(t)
      key = t.__orderedIndex[1]
    else
      for i = 1, #t.__orderedIndex do
        if t.__orderedIndex[i] == state then
          key = t.__orderedIndex[i + 1]
        end
      end
    end

    if key then
      return key, t[key]
    end

    t.__orderedIndex = nil
    return
  end

  function opairs(t)
    return orderedNext, t, nil
  end
  --

  function tblsize(tbl)
    local count = 0
    for _ in pairs(tbl) do
      count = count + 1
    end
    return count
  end

  function smalltable(tbl)
    local size = tblsize(tbl)
    if size > 10 then return end
    if size < 1 then return end

    for i = 1, size do
      if not tbl[i] then return end
      if type(tbl[i]) == "table" then return end
    end

    return true
  end

  function trealsize(tbl)
    local count = 0
    for _ in pairs(tbl) do
      count = count + 1
    end
    return count
  end

  local dupehashes = {}
  function removedupes(tbl)
    dupehashes = {}
    local output = {}

    -- [count] = { x, y, zone, respawn }
    for k, coords in pairs(tbl) do
      local hash = ""
      for k, v in pairs(coords) do
        hash = hash .. v
      end

      if not dupehashes[hash] then
        dupehashes[hash] = true
        table.insert(output, coords)
      end
    end

    return output
  end

  -- return true if the base table or any of its subtables
  -- has different values than the new table
  function isdiff(new, base)
    -- different types
    if type(new) ~= type(base) then
      return true
    end

    -- different values
    if type(new) ~= "table" then
      if new ~= base then
        return true
      end
    end

    -- recursive on tables
    if type(new) == "table" then
      for k, v in pairs(new) do
        local result = isdiff(new[k], base[k])
        if result then return true end
      end
    end

    return nil
  end

  -- create a new table with only those indexes that are
  -- either different or non-existing in the base table
  function tablesubstract(new, base)
    local result = {}

    -- changed value
    for k, v in pairs(new) do
      if new[k] and (not base or not base[k]) then
        -- write new entries
        result[k] = new[k]
      elseif new[k] and base[k] and isdiff(new[k], base[k]) then
        -- write different entries
        result[k] = new[k]
      end
    end

    -- remove obsolete entries
    if base then
      for k, v in pairs(base) do
        if base[k] and not new[k] then
          result[k] = "_"
        end
      end
    end

    return result
  end

  function serialize(file, name, tbl, spacing, flat)
    local closehandle = type(file) == "string"
    local file = type(file) == "string" and io.open(file, "w") or file
    local spacing = spacing or ""

    if tblsize(tbl) == 0 then
      file:write(string.format("%s%s = {}%s\n", spacing, name, (spacing == "" and "" or ",")))
    else
      file:write(spacing .. name .. " = {\n")

      for k, v in opairs(tbl) do
        local prefix = "[" .. k .. "]"
        if type(k) == "string" then
          prefix = "[\"" .. k .. "\"]"
        end

        if type(v) == "table" and flat then
          file:write("  " .. spacing .. prefix .. " = {},\n")
        elseif type(v) == "table" and smalltable(v) then
          local init
          local line = spacing .. "  " .. prefix .. " = { "
          for _, v in pairs(v) do
            line = line .. (init and ", " or "") .. (type(v) == "string" and "\"" .. v .. "\"" or v)
            if not init then
              init = true
            end
          end
          line = line .. " },\n"
          file:write(line)
        elseif type(v) == "table" then
          serialize(file, prefix, v, spacing .. "  ")
        elseif type(v) == "string" then
          file:write("  " .. spacing .. prefix .. " = " .. "\"" .. v .. "\",\n")
        elseif type(v) == "number" then
          file:write("  " .. spacing .. prefix .. " = " .. v .. ",\n")
        end
      end

      file:write(spacing .. "}" .. (not closehandle and "," or "") .. "\n")
    end

    if closehandle then file:close() end
  end
end

local pfDB = {}

for _, settings in pairs(config.expansions) do
  print("Extracting: " .. settings.name)

  local expansion = settings.name
  local db = settings.database
  local core = settings.core
  local locales = settings.locales

  local C = config.cores[core]

  local exp = expansion == "vanilla" and "" or "-" .. expansion
  local data = "data" .. exp

  do -- database connection
    luasql = require("luasql.mysql").mysql()
    mysql = luasql:connect(settings.database, "mangos", "mangos", "127.0.0.1")
    if not mysql:execute("SET SESSION sql_mode = ''") then
      error("Failed to connect to database: " .. db)
    end
  end

  pfDB["units"] = pfDB["units"] or {}
  pfDB["objects"] = pfDB["objects"] or {}
  pfDB["items"] = pfDB["items"] or {}
  pfDB["quests"] = pfDB["quests"] or {}

  print("- loading locales...")
  do -- unit locales
    -- load unit locales
    local locales_creature = {}
    local query = mysql:execute('SELECT *, creature_template.' .. C.Entry .. ' AS _entry FROM creature_template LEFT JOIN locales_creature ON locales_creature.entry = creature_template.entry GROUP BY creature_template.entry ORDER BY creature_template.entry ASC')
    while query:fetch(locales_creature, "a") do
      if debug("locales_unit") then break end

      local entry = tonumber(locales_creature["_entry"])
      local name  = locales_creature[C.Name]

      if entry then
        for loc in pairs(locales) do
          local name_loc = locales_creature["name_loc" .. locales[loc]]
          if not name_loc or name_loc == "" then name_loc = name or "" end
          if name_loc and name_loc ~= "" then
            local locale = loc .. (expansion ~= "vanilla" and "-" .. expansion or "")
            pfDB["units"][locale] = pfDB["units"][locale] or { [420] = "Shagu" }
            pfDB["units"][locale][entry] = sanitize(name_loc)
          end
        end
      end
    end
  end

  do -- objects locales
    local locales_gameobject = {}
    local query = mysql:execute('SELECT *, gameobject_template.entry AS _entry FROM gameobject_template LEFT JOIN locales_gameobject ON locales_gameobject.entry = gameobject_template.entry GROUP BY gameobject_template.entry ORDER BY gameobject_template.entry ASC')
    while query:fetch(locales_gameobject, "a") do
      if debug("locales_object") then break end

      local entry = tonumber(locales_gameobject["_entry"])
      local name  = locales_gameobject.name

      if entry then
        for loc in pairs(locales) do
          local name_loc = locales_gameobject["name_loc" .. locales[loc]]
          if not name_loc or name_loc == "" then name_loc = name or "" end
          if name_loc and name_loc ~= "" then
            local locale = loc .. (expansion ~= "vanilla" and "-" .. expansion or "")
            pfDB["objects"][locale] = pfDB["objects"][locale] or {}
            pfDB["objects"][locale][entry] = sanitize(name_loc)
          end
        end
      end
    end
  end

  do -- items locales
    local items_loc = {}
    local locales_item = {}
    local query = mysql:execute('SELECT *, item_template.entry AS _entry FROM item_template LEFT JOIN locales_item ON locales_item.entry = item_template.entry GROUP BY item_template.entry ORDER BY item_template.entry ASC')
    while query:fetch(locales_item, "a") do
      if debug("locales_item") then break end

      local entry = tonumber(locales_item["_entry"])
      local name  = locales_item.name

      if entry then
        for loc in pairs(locales) do
          local name_loc = locales_item["name_loc" .. locales[loc]]
          if not name_loc or name_loc == "" then name_loc = name or "" end
          if name_loc and name_loc ~= "" then
            local locale = loc .. (expansion ~= "vanilla" and "-" .. expansion or "")
            pfDB["items"][locale] = pfDB["items"][locale] or {}
            pfDB["items"][locale][entry] = sanitize(name_loc)
          end
        end
      end
    end
  end

  do -- quests locales
    local locales_quest = {}
    local query = mysql:execute('SELECT *, quest_template.entry AS _entry FROM quest_template LEFT JOIN locales_quest ON locales_quest.entry = quest_template.entry GROUP BY quest_template.entry ORDER BY quest_template.entry ASC')
    while query:fetch(locales_quest, "a") do
      if debug("locales_quest") then break end

      for loc in pairs(locales) do
        local entry = tonumber(locales_quest["_entry"])

        if entry then
          local locale = loc .. (expansion ~= "vanilla" and "-" .. expansion or "")
          pfDB["quests"][locale] = pfDB["quests"][locale] or {}

          local title_loc = locales_quest["Title_loc" .. locales[loc]]
          local details_loc = locales_quest["Details_loc" .. locales[loc]]
          local objectives_loc = locales_quest["Objectives_loc" .. locales[loc]]

          -- fallback to enUS titles
          if not title_loc or title_loc == "" then title_loc = locales_quest.Title or "" end
          if not details_loc or details_loc == "" then details_loc = locales_quest.Details or "" end
          if not objectives_loc or objectives_loc == "" then objectives_loc = locales_quest.Objectives or "" end

          pfDB["quests"][locale][entry] = {
            ["T"] = sanitize(title_loc),
            ["O"] = sanitize(objectives_loc),
            ["D"] = sanitize(details_loc)
          }
        end
      end
    end
  end

  -- write down tables
  print("- writing database...")
  local output = settings.custom and "output/custom/" or "output/"

  for loc in pairs(locales) do
    local locale = loc .. (expansion ~= "vanilla" and "-" .. expansion or "")

    os.execute("mkdir -p " .. output .. loc)
    serialize(output .. string.format("%s/units%s.lua", loc, exp), "pfDB[\"units\"][\"" .. locale .. "\"]", pfDB["units"][locale])
    serialize(output .. string.format("%s/objects%s.lua", loc, exp), "pfDB[\"objects\"][\"" .. locale .. "\"]", pfDB["objects"][locale])
    serialize(output .. string.format("%s/items%s.lua", loc, exp), "pfDB[\"items\"][\"" .. locale .. "\"]", pfDB["items"][locale])
    serialize(output .. string.format("%s/quests%s.lua", loc, exp), "pfDB[\"quests\"][\"" .. locale .. "\"]", pfDB["quests"][locale]) 
  end

  if not settings.custom then
    serialize(output .. "init.lua", "pfDB", pfDB, nil, true)
  end

  debug_statistics()
end
