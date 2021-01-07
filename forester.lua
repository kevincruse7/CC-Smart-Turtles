--[[
  Forester program for ComputerCraft mining turtles. Harvests and plants trees in a set number of
  rows. Each row has a set number of trees lined up side-to-side, with a set radius around the line
  reserved for drop collection, be it by hoppers, water streams, etc.

  Written by Kevin Cruse
]]

local turtle_utils = require('/lib/turtle_utils')
local Directions = turtle_utils.Directions

local COLLECTION_RADIUS = 3  -- Radius around each row to be reserved for drop collection
local PAUSE_TIME = 1800  -- Time in seconds to wait between harvests
local ROW_LENGTH = 16  -- Number of trees in a row
local ROWS = 4  -- Number of rows
local SAPLING_ID = 'minecraft:oak_sapling'  -- Block ID of sapling to be planted
local TREE_HEIGHT = 6  -- Height of trees to be harvested

local harvestRow
local harvestTrees
local harvestWoodLayer
local moveToInitialHarvestPosition
local moveToInititalPlantPosition
local moveToNextHarvestRow
local moveToNextPlantRow
local moveToNextWoodLayer
local outOfSaplings
local pickUpDrops
local plantSapling
local plantRow
local plantSaplings
local turnAwayFromRow
local turnTowardRow

local function main()

  local position = turtle_utils.createPosition('position')

  turtle_utils.indicateRunning()
  turtle_utils.goHome(position)

  while true do
    harvestTrees(position)

    if outOfSaplings() then
      turtle_utils.turn(position, turtle_utils.PICKUP_DIRECTION)
      turtle_utils.pickUp(position)

      while outOfSaplings() do
        turtle_utils.pause('Sapling restock')
        turtle_utils.pickUp(position)
      end
    end
    plantSaplings(position)

    turtle_utils.turn(position, Directions.POS_Z)
    sleep(PAUSE_TIME)
  end
end

-- Harvests a row of trees
harvestRow = function(position)

  harvestWoodLayer(position)
  for i = 1, TREE_HEIGHT - 1, 1 do
    moveToNextWoodLayer(position)
    harvestWoodLayer(position)
  end

  pickUpDrops(position)
end

-- Harvests all the trees in the farm and deposits the collected wood at home
harvestTrees = function(position)

  moveToInitialHarvestPosition(position)

  harvestRow(position)
  for i = 1, ROWS - 1, 1 do
    moveToNextHarvestRow(position)
    harvestRow(position)
  end

  turtle_utils.goHome(position)
  turtle_utils.turn(position, turtle_utils.DROP_DIRECTION)
  turtle_utils.dropItems(position)
end

-- Harvests a layer of wood in the current row
harvestWoodLayer = function(position)

  for i = 1, ROW_LENGTH - 1, 1 do
    turtle_utils.digForward(position)
    turtle_utils.moveForward(position, 1)
  end
end

-- Moves the turtle from home to the initial harvesting position
moveToInitialHarvestPosition = function(position)

  turtle_utils.turn(position, Directions.POS_Z)
  turtle_utils.moveForward(position, COLLECTION_RADIUS)
  turtle_utils.digForward(position)
  turtle_utils.moveForward(position, 1)
end

-- Moves the turtle from home to the initial planting position
moveToInitialPlantPosition = function(position)

  turtle_utils.turn(position, Directions.POS_Z)
  turtle_utils.moveForward(position, COLLECTION_RADIUS + 2)
  turtle_utils.turn(position, Directions.POS_X)
  turtle_utils.moveForward(position, 2 * COLLECTION_RADIUS * (ROWS - 1))

  if math.fmod(ROWS, 2) == 1 then
    turtle_utils.turn(position, Directions.POS_Z)
    turtle_utils.moveForward(position, ROW_LENGTH - 3)
  else
    turtle_utils.turn(position, Directions.NEG_Z)
  end
end

-- Moves to the next row for harvesting
moveToNextHarvestRow = function(position)

  turtle_utils.turn(position, Directions.POS_X)
  turtle_utils.moveForward(position, 2 * COLLECTION_RADIUS - 1)
  turtle_utils.digForward(position)
  turtle_utils.moveForward(position, 1)

  turnTowardRow(position)
end

-- Moves to the next row for planting
moveToNextPlantRow = function(position)

  turtle_utils.turn(position, Directions.NEG_X)
  turtle_utils.moveForward(position, 2 * COLLECTION_RADIUS)
  turnAwayFromRow(position)
  turtle_utils.moveBackward(position, 2)
end

-- Moves to the next wood layer in the current row for harvesting
moveToNextWoodLayer = function(position)

  turtle_utils.digUp(position)
  turtle_utils.moveUp(position, 1)

  turnTowardRow(position)
end

-- Determines if the turtle is out of saplings to plant
outOfSaplings = function()

  local slot_data = turtle.getItemDetail(1)
  return slot_data == nil
      or slot_data.name ~= SAPLING_ID
      or slot_data.count < ROWS * ROW_LENGTH
end

-- Picks up drops that land on the dirt lines
pickUpDrops = function(position)

  turtle_utils.moveForward(position, 1)
  turtle_utils.moveDown(position, TREE_HEIGHT - 1)
  turnTowardRow(position)
  turtle.select(turtle_utils.FIRST_DISPOSABLE_SLOT)

  for i = 1, ROW_LENGTH, 1 do
    turtle_utils.suckForward(position)
    turtle_utils.moveForward(position, 1)
  end
end

-- Plants a sapling below the turtle
plantSapling = function()

  turtle.select(1)

  local successful = turtle.place()
  while not successful do
    turtle_utils.pause('Sapling placement')
    successful = turtle.place()
  end
end

-- Plants a row of saplings
plantRow = function(position)

  plantSapling()
  for i = 1, ROW_LENGTH - 1, 1 do
    turtle_utils.moveBackward(position, 1)
    plantSapling()
  end
end

-- Plants saplings along the entire farm and returns home
plantSaplings = function(position)

  moveToInitialPlantPosition(position)

  plantRow(position)
  for i = 1, ROWS - 1, 1 do
    moveToNextPlantRow(position)
    plantRow(position)
  end

  turtle_utils.goHome(position)
end

-- Faces the turtle away from the current row
turnAwayFromRow = function(position)

  if position.current.z <= COLLECTION_RADIUS + ROW_LENGTH / 2 then
    turtle_utils.turn(position, Directions.NEG_Z)
  else
    turtle_utils.turn(position, Directions.POS_Z)
  end
end

-- Faces the turtle toward the current row
turnTowardRow = function(position)

  if position.current.z <= COLLECTION_RADIUS + ROW_LENGTH / 2 then
    turtle_utils.turn(position, Directions.POS_Z)
  else
    turtle_utils.turn(position, Directions.NEG_Z)
  end
end

main()
