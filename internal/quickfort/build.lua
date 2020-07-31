-- build-related logic for the quickfort script
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

local quickfort_common = reqscript('internal/quickfort/common')
local quickfort_building = reqscript('internal/quickfort/building')
local log = quickfort_common.log

local function is_valid_tile_dirt(pos)
    local tileattrs = df.tiletype.attrs[dfhack.maps.getTileType(pos)]
    local shape = tileattrs.shape
    local mat = tileattrs.material
    local good_shape =
            shape == df.tiletype_shape.FLOOR or
            shape == df.tiletype_shape.TWIG or
            shape == df.tiletype_shape.SAPLING or
            shape == df.tiletype_shape.SHRUB
    local good_material =
            mat == df.tiletype_material.SOIL or
            mat == df.tiletype_material.GRASS_LIGHT or
            mat == df.tiletype_material.GRASS_DARK or
            mat == df.tiletype_material.GRASS_DRY or
            mat == df.tiletype_material.GRASS_DEAD or
            mat == df.tiletype_material.PLANT or
            -- below here need to verify
            mat == df.tiletype_material.DRIFTWOOD
end

local function is_valid_tile_construction(pos)
    local flags, occupancy = dfhack.maps.getTileFlags(pos)
    if flags.hidden or occupancy.building ~= 0 then return false end
    local shape = df.tiletype.attrs[dfhack.maps.getTileType(pos)].shape
    return shape == df.tiletype_shape.FLOOR or
            shape == df.tiletype_shape.BOULDER or
            shape == df.tiletype_shape.PEBBLES or
            shape == df.tiletype_shape.TWIG or
            shape == df.tiletype_shape.SAPLING or
            shape == df.tiletype_shape.SHRUB
end

local function is_valid_tile_bridge(pos)
    local shape = df.tiletype.attrs[dfhack.maps.getTileType(pos)].shape
    return is_valid_tile_construction(pos) or
            shape == df.tiletype_shape.EMPTY
end

local function flood_extent(extent_grid, x, y, reachable_grid)
    if reachable_grid[x] and reachable_grid[x][y] then return end
    if not extent_grid[x] or not extent_grid[x][y] then return end
    reachable_grid[x][y] = true
    -- diagonal connections count
    flood_extent(extent_grid, x-1, y-1, reachable_grid)
    flood_extent(extent_grid, x-1, y, reachable_grid)
    flood_extent(extent_grid, x-1, y+1, reachable_grid)
    flood_extent(extent_grid, x, y-1, reachable_grid)
    flood_extent(extent_grid, x, y+1, reachable_grid)
    flood_extent(extent_grid, x+1, y-1, reachable_grid)
    flood_extent(extent_grid, x+1, y, reachable_grid)
    flood_extent(extent_grid, x+1, y+1, reachable_grid)
end

-- extent checking functions assume valid, non-zero width or height extents
local function is_extent_connected(b)
    local extent_grid = b.extent_grid
    local reachable_grid = {}
    for x, col in ipairs(extent_grid) do
        reachable_grid[x] = {}
        for y, _ in ipairs(col) do reachable_grid[x][y] = false end
    end
    local done = false
    for x, col in ipairs(extent_grid) do
        for y, in_extent in ipairs(col) do
            if in_extent then
                -- flood from any tile in the extent
                flood_extent(extent_grid, x, y, reachable_grid)
                done = true
            end
        end
        if done then break end
    end
    for x, col in ipairs(extent_grid) do
        for y, _ in ipairs(col) do
            if extent_grid[x][y] ~= reachable_grid[x][y] then return false end
        end
    end
    return true
end

local function is_extent_solid(b)
    local area = b.width * b.height
    local num_tiles = 0
    for extent_x, col in ipairs(b.extent_grid) do
        for extent_y, in_extent in ipairs(col) do
            if in_extent then num_tiles = num_tiles + 1 end
        end
    end
    return num_tiles == area
end

local function is_extent_nonempty(b)
    for extent_x, col in ipairs(b.extent_grid) do
        for extent_y, in_extent in ipairs(col) do
            if in_extent then return true end
        end
    end
    return false
end

local function is_extent_solid_and_supported(b)
    print("TODO: check that bridges are supported")
    return is_extent_solid(b)
end

-- grouped by type, generally in ui order
local building_db = {
    -- basic building types
    a={label='Armor Stand', type=df.building_type.Armorstand},
    b={label='Bed', type=df.building_type.Bed},
    c={label='Seat', type=df.building_type.Chair},
    n={label='Burial Receptacle', type=df.building_type.Coffin},
    d={label='Door', type=df.building_type.Door},
    x={label='Floodgate', type=df.building_type.Floodgate},
    H={label='Floor Hatch', type=df.building_type.Hatch},
    W={label='Wall Grate', type=df.building_type.GrateWall},
    G={label='Floor Grate', type=df.building_type.GrateFloor},
    B={label='Vertical Bars', type=df.building_type.BarsVertical},
    ['{Alt}b']={label='Floor Bars', type=df.building_type.BarsFloor},
    f={label='Cabinet', type=df.building_type.Cabinet},
    h={label='Container', type=df.building_type.Box},
    r={label='Weapon Rack', type=df.building_type.Weaponrack},
    s={label='Statue', type=df.building_type.Statue},
    ['{Alt}s']={label='Slab', type=df.building_type.Slab},
    t={label='Table', type=df.building_type.Table},
    g={label='Bridge',
       type=df.building_type.Bridge,
       min_width=1, max_width=10, min_height=1, max_height=10,
       is_valid_tile_fn=is_valid_tile_bridge,
       is_valid_extent_fn=is_extent_solid_and_supported},
    l={label='Well', type=df.building_type.Well},
    y={label='Glass Window', type=df.building_type.WindowGlass},
    Y={label='Gem Window', type=df.building_type.WindowGem},
    D={label='Trade Depot', type=df.building_type.TradeDepot,
       min_width=5, max_width=5, min_height=5, max_height=5},
    Ms={label='Screw Pump (Pump From North)', type=df.building_type.ScrewPump,
        min_width=1, max_width=1, min_height=2, max_height=2,
        fields={direction=df.screw_pump_direction.FromNorth}},
    Msu={label='Screw Pump (Pump From North)', type=df.building_type.ScrewPump,
         min_width=1, max_width=1, min_height=2, max_height=2,
         fields={direction=df.screw_pump_direction.FromNorth}},
    Msk={label='Screw Pump (Pump From East)', type=df.building_type.ScrewPump,
         min_width=2, max_width=2, min_height=1, max_height=1,
         fields={direction=df.screw_pump_direction.FromEast}},
    Msm={label='Screw Pump (Pump From South)', type=df.building_type.ScrewPump,
         min_width=1, max_width=1, min_height=2, max_height=2,
         fields={direction=df.screw_pump_direction.FromSouth}},
    Msh={label='Screw Pump (Pump From West)', type=df.building_type.ScrewPump,
         min_width=2, max_width=2, min_height=1, max_height=1,
         fields={direction=df.screw_pump_direction.FromWest}},
    Mw={label='Water Wheel (N/S)', type=df.building_type.WaterWheel,
        min_width=1, max_width=1, min_height=3, max_height=3,
        fields={is_vertical=true}},
    Mws={label='Water Wheel (E/W)', type=df.building_type.WaterWheel,
         min_width=3, max_width=3, min_height=1, max_height=1},
    Mg={label='Gear Assembly', type=df.building_type.GearAssembly},
    Mh={label='Horizontal Axle (E/W)', type=df.building_type.AxleHorizontal,
        min_width=1, max_width=10, min_height=1, max_height=1},
    Mhs={label='Horizontal Axle (N/S)', type=df.building_type.AxleHorizontal,
         min_width=1, max_width=1, min_height=1, max_height=10,
         fields={is_vertical=true}},
    Mv={label='Vertical Axle', type=df.building_type.AxleVertical},
    -- TODO: handle q* suffixes to set the speed
    Mr={label='Rollers (N->S)', type=df.building_type.Rollers,
        min_width=1, max_width=1, min_height=1, max_height=10,
        fields={direction=df.screw_pump_direction.FromNorth}},
    Mrs={label='Rollers (E->W)', type=df.building_type.Rollers,
         min_width=1, max_width=10, min_height=1, max_height=1,
         fields={direction=df.screw_pump_direction.FromEast}},
    Mrss={label='Rollers (S->N)', type=df.building_type.Rollers,
          min_width=1, max_width=1, min_height=1, max_height=10,
          fields={direction=df.screw_pump_direction.FromSouth}},
    Mrsss={label='Rollers (W->E)', type=df.building_type.Rollers,
           min_width=1, max_width=10, min_height=1, max_height=1,
           fields={direction=df.screw_pump_direction.FromWest}},
    I={label='Instrument', type=df.building_type.Instrument},
    S={label='Support', type=df.building_type.Support},
    m={label='Animal Trap', type=df.building_type.AnimalTrap},
    v={label='Restraint', type=df.building_type.Chain},
    j={label='Cage', type=df.building_type.Cage},
    A={label='Archery Target', type=df.building_type.ArcheryTarget},
    R={label='Traction Bench', type=df.building_type.TractionBench},
    N={label='Nest Box', type=df.building_type.NextBox},
    ['{Alt}h']={label='Hive', type=df.building_type.Hive},
    ['{Alt}a']={label='Offering Place', type=df.building_type.OfferingPlace},
    ['{Alt}c']={label='Bookcase', type=df.building_type.Bookcase},
    F={label='Display Furniture', type=df.building_type.DisplayFurniture},
    -- basic building types with extents
    p={label='Farm Plot',
       type=df.building_type.FarmPlot, has_extents=true,
       no_extents_if_solid=true,
       is_valid_tile_fn=is_valid_tile_dirt,
       is_valid_extent_fn=is_extent_nonempty},
    o={label='Paved Road',
       type=df.building_type.RoadPaved, has_extents=true,
       no_extents_if_solid=true, is_valid_extent_fn=is_extent_connected},
    O={label='Dirt Road',
       type=df.building_type.RoadDirt, has_extents=true,
       no_extents_if_solid=true,
       is_valid_tile_fn=is_valid_tile_dirt,
       is_valid_extent_fn=is_extent_connected},
    -- workshops
    k={label='Kennels',
       type=df.building_type.Workshop, subtype=df.workshop_type.Kennels},
    we={label='Leather Works',
        type=df.building_type.Workshop, subtype=df.workshop_type.Leatherworks},
    wq={label='Quern',
        type=df.building_type.Workshop, subtype=df.workshop_type.Quern,
        min_width=1, max_width=1, min_height=1, max_height=1},
    wM={label='Millstone',
        type=df.building_type.Workshop, subtype=df.workshop_type.Millstone},
    wo={label='Loom',
        type=df.building_type.Workshop, subtype=df.workshop_type.Loom},
    wk={label='Clothier\'s shop',
        type=df.building_type.Workshop, subtype=df.workshop_type.Clotheirs},
    wb={label='Bowyer\'s Workshop',
        type=df.building_type.Workshop, subtype=df.workshop_type.Bowyers},
    wc={label='Carpenter\'s Workshop',
        type=df.building_type.Workshop, subtype=df.workshop_type.Carpenters},
    wf={label='Metalsmith\'s Forge',
        type=df.building_type.Workshop,
        subtype=df.workshop_type.MetalsmithsForge},
    wv={label='Magma Forge',
        type=df.building_type.Workshop, subtype=df.workshop_type.MagmaForge},
    wj={label='Jeweler\'s Workshop',
        type=df.building_type.Workshop, subtype=df.workshop_type.Jewelers},
    wm={label='Mason\'s Workshop',
        type=df.building_type.Workshop, subtype=df.workshop_type.Masons},
    wu={label='Butcher\'s Shop',
        type=df.building_type.Workshop, subtype=df.workshop_type.Butchers},
    wn={label='Tanner\'s Shop',
        type=df.building_type.Workshop, subtype=df.workshop_type.Tanners},
    wr={label='Craftsdwarf\'s Workshop',
        type=df.building_type.Workshop, subtype=df.workshop_type.Craftdwarfs},
    ws={label='Siege Workshop',
        type=df.building_type.Workshop, subtype=df.workshop_type.Siege},
    wt={label='Mechanic\'s Workshop',
        type=df.building_type.Workshop, subtype=df.workshop_type.Mechanics},
    wl={label='Still',
        type=df.building_type.Workshop, subtype=df.workshop_type.Still},
    ww={label='Farmer\'s Workshop',
        type=df.building_type.Workshop, subtype=df.workshop_type.Farmers},
    wz={label='Kitchen',
        type=df.building_type.Workshop, subtype=df.workshop_type.Kitchen},
    wh={label='Fishery',
        type=df.building_type.Workshop, subtype=df.workshop_type.Fishery},
    wy={label='Ashery',
        type=df.building_type.Workshop, subtype=df.workshop_type.Ashery},
    wd={label='Dyer\'s Shop',
        type=df.building_type.Workshop, subtype=df.workshop_type.Dyers},
    wS={label='Soap Maker\'s Workshop',
        type=df.building_type.Workshop, subtype=df.workshop_type.Custom},
    wp={label='Screw Press',
        type=df.building_type.Workshop, subtype=df.workshop_type.Tool},
    -- furnaces
    ew={label='Wood Furnace',
        type=df.building_type.Furnace, subtype=df.siegeengine_type.WoodFurnace},
    es={label='Smelter',
        type=df.building_type.Furnace, subtype=df.siegeengine_type.Smelter},
    el={label='Magma Smelter',
        type=df.building_type.Furnace, subtype=df.siegeengine_type.MagmaSmelter},
    eg={label='Glass Furnace',
        type=df.building_type.Furnace, subtype=df.siegeengine_type.GlassFurnace},
    ea={label='Magma Glass Furnace',
        type=df.building_type.Furnace,
        subtype=df.siegeengine_type.MagmaGlassFurnace},
    ek={label='Kiln',
        type=df.building_type.Furnace, subtype=df.siegeengine_type.Kiln},
    en={label='Magma Kiln',
        type=df.building_type.Furnace, subtype=df.siegeengine_type.MagmaKiln},
    -- siege engines
    ib={label='Ballista',
        type=df.building_type.SiegeEngine,
        subtype=df.siegeengine_type.Ballista},
    ic={label='Catapult',
        type=df.building_type.SiegeEngine,
        subtype=df.siegeengine_type.Catapult},
    -- constructions
    Cw={label='Wall',
        type=df.building_type.Construction, subtype=df.construction_type.Wall},
    Cf={label='Floor',
        type=df.building_type.Construction, subtype=df.construction_type.Floor},
    Cr={label='Ramp',
        type=df.building_type.Construction, subtype=df.construction_type.Ramp},
    Cu={label='Up Stair',
        type=df.building_type.Construction,
        subtype=df.construction_type.UpStair},
    Cd={label='Down Stair',
        type=df.building_type.Construction,
        subtype=df.construction_type.DownStair},
    Cx={label='Up/Down Stair',
        type=df.building_type.Construction,
        subtype=df.construction_type.UpDownStair},
    CF={label='Fortification',
        type=df.building_type.Construction,
        subtype=df.construction_type.Fortification},
    -- traps
    -- TODO: CSd*a* for friction options; high=10000
    CS={label='Track Stop (No Dump)',
        type=df.building_type.Trap, subtype=df.trap_type.TrackStop},
    CSd={label='Track Stop (Dump North)',
         type=df.building_type.Trap, subtype=df.trap_type.TrackStop,
         fields={use_dump=true, dump_y_shift=-1}},
    CSdd={label='Track Stop (Dump South)',
          type=df.building_type.Trap, subtype=df.trap_type.TrackStop,
          fields={use_dump=true, dump_y_shift=1}},
    CSddd={label='Track Stop (Dump East)',
           type=df.building_type.Trap, subtype=df.trap_type.TrackStop,
           fields={use_dump=true, dump_x_shift=1}},
    CSdddd={label='Track Stop (Dump West)',
            type=df.building_type.Trap, subtype=df.trap_type.TrackStop,
            fields={use_dump=true, dump_x_shift=-1}},
    Ts={label='Stone-Fall Trap',
        type=df.building_type.Trap, subtype=df.trap_type.StoneFallTrap},
    Tw={label='Weapon Trap',
        type=df.building_type.Trap, subtype=df.trap_type.WeaponTrap},
    Tl={label='Lever',
        type=df.building_type.Trap, subtype=df.trap_type.Lever},
    Tp={label='Pressure Plate',
        type=df.building_type.Trap, subtype=df.trap_type.PressurePlate},
    Tc={label='Cage Trap',
        type=df.building_type.Trap, subtype=df.trap_type.CateTrap},
    -- TODO: maybe TS1 through TS10 for how many weapons?
    TS={label='Upright Spear/Spike',
        type=df.building_type.Weapon, subtype=df.trap_type.StoneFallTrap},
    -- tracks (CT...)
    trackN={label='Track (N)',
            type=df.building_type.Construction,
            subtype=df.construction_type.TrackN},
    trackS={label='Track (S)',
            type=df.building_type.Construction,
            subtype=df.construction_type.TrackS},
    trackE={label='Track (E)',
            type=df.building_type.Construction,
            subtype=df.construction_type.TrackE},
    trackW={label='Track (W)',
            type=df.building_type.Construction,
            subtype=df.construction_type.TrackW},
    trackNS={label='Track (NS)',
             type=df.building_type.Construction,
             subtype=df.construction_type.TrackNS},
    trackNE={label='Track (NE)',
             type=df.building_type.Construction,
             subtype=df.construction_type.TrackNE},
    trackNW={label='Track (NW)',
             type=df.building_type.Construction,
             subtype=df.construction_type.TrackNW},
    trackSE={label='Track (SE)',
             type=df.building_type.Construction,
             subtype=df.construction_type.TrackSE},
    trackSW={label='Track (SW)',
             type=df.building_type.Construction,
             subtype=df.construction_type.TrackSW},
    trackEW={label='Track (EW)',
             type=df.building_type.Construction,
             subtype=df.construction_type.TrackEW},
    trackNSE={label='Track (NSE)',
              type=df.building_type.Construction,
              subtype=df.construction_type.TrackNSE},
    trackNSW={label='Track (NSW)',
              type=df.building_type.Construction,
              subtype=df.construction_type.TrackNSW},
    trackNEW={label='Track (NEW)',
              type=df.building_type.Construction,
              subtype=df.construction_type.TrackNEW},
    trackSEW={label='Track (SEW)',
              type=df.building_type.Construction,
              subtype=df.construction_type.TrackSEW},
    trackNSEW={label='Track (NSEW)',
               type=df.building_type.Construction,
               subtype=df.construction_type.TrackNSEW},
    trackrampN={label='Track/Ramp (N)',
                type=df.building_type.Construction,
                subtype=df.construction_type.TrackRampN},
    trackrampS={label='Track/Ramp (S)',
                type=df.building_type.Construction,
                subtype=df.construction_type.TrackRampS},
    trackrampE={label='Track/Ramp (E)',
                type=df.building_type.Construction,
                subtype=df.construction_type.TrackRampE},
    trackrampW={label='Track/Ramp (W)',
                type=df.building_type.Construction,
                subtype=df.construction_type.TrackRampW},
    trackrampNS={label='Track/Ramp (NS)',
                 type=df.building_type.Construction,
                 subtype=df.construction_type.TrackRampNS},
    trackrampNE={label='Track/Ramp (NE)',
                 type=df.building_type.Construction,
                 subtype=df.construction_type.TrackRampNE},
    trackrampNW={label='Track/Ramp (NW)',
                 type=df.building_type.Construction,
                 subtype=df.construction_type.TrackRampNW},
    trackrampSE={label='Track/Ramp (SE)',
                 type=df.building_type.Construction,
                 subtype=df.construction_type.TrackRampSE},
    trackrampSW={label='Track/Ramp (SW)',
                 type=df.building_type.Construction,
                 subtype=df.construction_type.TrackRampSW},
    trackrampEW={label='Track/Ramp (EW)',
                 type=df.building_type.Construction,
                 subtype=df.construction_type.TrackRampEW},
    trackrampNSE={label='Track/Ramp (NSE)',
                  type=df.building_type.Construction,
                  subtype=df.construction_type.TrackRampNSE},
    trackrampNSW={label='Track/Ramp (NSW)',
                  type=df.building_type.Construction,
                  subtype=df.construction_type.TrackRampNSW},
    trackrampNEW={label='Track/Ramp (NEW)',
                  type=df.building_type.Construction,
                  subtype=df.construction_type.TrackRampNEW},
    trackrampSEW={label='Track/Ramp (SEW)',
                  type=df.building_type.Construction,
                  subtype=df.construction_type.TrackRampSEW},
    trackrampNSEW={label='Track/Ramp (NSEW)',
                   type=df.building_type.Construction,
                   subtype=df.construction_type.TrackRampNSEW},
}

-- fill in default values if they're not already specified
for _, v in pairs(building_db) do
    if v.has_extents then
        if not v.min_width then
            v.min_width = 1
            v.max_width = 10
            v.min_height = 1
            v.max_height = 10
        end
    elseif v.type == df.building_type.Workshop or
            v.type == df.building_type.SiegeEngine then
        if not v.min_width then
            v.min_width = 3
            v.max_width = 3
            v.min_height = 3
            v.max_height = 3
        end
    else
        if not v.min_width then
            v.min_width = 1
            v.max_width = 1
            v.min_height = 1
            v.max_height = 1
        end
    end
    if not v.is_valid_tile_fn then
        v.is_valid_tile_fn = is_valid_tile_construction
    end
    if not v.is_valid_extent_fn then
        v.is_valid_extent_fn = is_extent_solid
    end
end

-- case insensitive aliases for tricky keys in the db
local aliases = {
    trackstopn='CSd',
    trackstops='CSdd',
    trackstope='CSddd',
    trackstopw='CSdddd',
    trackn='trackN',
    tracks='trackS',
    tracke='trackE',
    trackw='trackW',
    trackns='trackNS',
    trackne='trackNE',
    tracknw='trackNW',
    trackse='trackSE',
    tracksw='trackSW',
    trackew='trackEW',
    tracknse='trackNSE',
    tracknsw='trackNSW',
    tracknew='trackNEW',
    tracksew='trackSEW',
    tracknsew='trackNSEW',
    trackrampn='trackrampN',
    trackramps='trackrampS',
    trackrampe='trackrampE',
    trackrampw='trackrampW',
    trackrampns='trackrampNS',
    trackrampne='trackrampNE',
    trackrampnw='trackrampNW',
    trackrampse='trackrampSE',
    trackrampsw='trackrampSW',
    trackrampew='trackrampEW',
    trackrampnse='trackrampNSE',
    trackrampnsw='trackrampNSW',
    trackrampnew='trackrampNEW',
    trackrampsew='trackrampSEW',
    trackrampnsew='trackrampNSEW',
}

local function create_building(b)
    db_entry = building_db[b.type]
    log('creating %s at map coordinates (%d, %d, %d), defined from ' ..
        'spreadsheet cells: %s',
        db_entry.label, b.pos.x, b.pos.y, b.pos.z,
        table.concat(b.cells, ', '))
    local extents, room = nil, nil
    if db_entry.has_extents then
        extents = quickfort_building.make_extents(b, building_db)
        room = {x=b.pos.x, y=b.pos.y, width=b.width, height=b.height}
    end
    local bld, err = dfhack.buildings.constructBuilding{
        type=db_entry.type, subtype=db_entry.subtype, pos=b.pos,
        width=b.width, height=b.height, fields={room=room}}
    if not bld then
        if extents then df.delete(extents) end
        -- this is an error instead of a qerror since our validity checking
        -- is supposed to prevent this from ever happening
        error(string.format('unable to place %s: %s', db_entry.label, err))
    end
    -- constructBuilding deallocates extents, so we have to assign it after
    if db_entry.has_extents then
        bld.room.extents = extents
    end
end

function do_run(zlevel, grid)
    local stats = {
        designated={label='Buildings designated', value=0, always=true},
        occupied={label='Buildings skipped (tile occupied)', value=0},
        out_of_bounds={label='Buildings skipped (outside map boundary)',
                       value=0},
        invalid_keys={label='Invalid key sequences', value=0},
    }

    local buildings = {}
    stats.invalid_keys.value = quickfort_building.init_buildings(
        zlevel, grid, buildings, building_db)
    stats.out_of_bounds.value = quickfort_building.crop_to_bounds(
        buildings, building_db)
    stats.occupied.value = quickfort_building.check_tiles_and_extents(
        buildings, building_db)

    for _, b in ipairs(buildings) do
        if b.pos then
            create_building(b)
            stats.designated.value = stats.designated.value + 1
        end
    end
    return stats
end

function do_orders(zlevel, grid)
    local stats = nil
    print('"quickfort orders" not yet implemented for mode: build')
    return stats
end

local function is_queued_for_destruction(bld)
    for k,v in ipairs(bld.jobs) do
        if v.job_type == df.job_type.DestroyBuilding then
            return true
        end
    end
    return false
end

function do_undo(zlevel, grid)
    local stats = {
        removed={label='Planned buildings removed', value=0, always=true},
        marked={label='Buildings marked for removal', value=0},
        invalid_keys={label='Invalid key sequences', value=0},
    }

    local buildings = {}
    stats.invalid_keys.value = quickfort_building.init_buildings(
        zlevel, grid, buildings, building_db)

    for _, s in ipairs(buildings) do
        for extent_x, col in ipairs(s.extent_grid) do
            for extent_y, in_extent in ipairs(col) do
                if not s.extent_grid[extent_x][extent_y] then goto continue end
                local pos =
                        xyz2pos(s.pos.x+extent_x-1, s.pos.y+extent_y-1, s.pos.z)
                local bld = dfhack.buildings.findAtTile(pos)
                if bld and bld:getType() ~= df.building_type.Stockpile and
                        not is_queued_for_destruction(bld) then
                    if dfhack.buildings.deconstruct(bld) then
                        stats.removed.value = stats.removed.value + 1
                    else
                        stats.marked.value = stats.marked.value + 1
                    end
                end
                ::continue::
            end
        end
    end
    return stats
end
