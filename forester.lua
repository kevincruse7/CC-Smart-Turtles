local turtle_utils = require('/lib/turtle_utils')
local Directions = turtle_utils.Directions

local COLLECTION_RADIUS = 3
local PAUSE_TIME = 1200
local ROW_LENGTH = 8
local ROWS 4
local SAPLING_ID = 'minecraft:oak_sapling'
local TREE_HEIGHT = 7

function main()

  local position = turtle_utils.createPosition()

  turtle_utils.indicateRunning()
  while true do
    if outOfSaplings() then
      turtle_utils.turn(position, turtle_utils.PICKUP_DIRECTION)

      turtle_utils.pickUp(position)
      while outOfSaplings() do
        turtle_utils.pause('Sapling restock')

        turtle_utils.pickUp(position)
      end
    end

    harvestTrees(position)
    plantSaplings(position)

    sleep(PAUSE_TIME)
  end
end

local function harvestRow(position)

  harvestWoodLayer(position)
  for i = 1, TREE_HEIGHT - 1, 1 do
    turtle_utils.digUp(position)
    turtle_utils.moveUp(position, 1)

    if position.current.direction == Directions.POS_Z then
      turtle_utils.turn(position, Directions.NEG_Z)
    else
      turtle_utils.turn(position, Directions.POS_Z)
    end

    harvestWoodLayer(position)
  end

  turtle_utils.moveDown(position, TREE_HEIGHT - 1)
end

local function harvestTrees(position)

  turtle_utils.turn(position, Directions.POS_Z)
  turtle_utils.moveForward(position, COLLECTION_RADIUS)
  turtle_utils.dig(position)
  turtle_utils.moveForward(position, 1)

  harvestRow(position)
  for i = 1, ROWS - 1, 1 do
    turtle_utils.turn(position, Directions.POS_X)
    turtle_utils.moveForward(position, 2 * COLLECTION_RADIUS - 1)
    turtle_utils.dig(position)
    turtle_utils.moveForward(position, 1)

    if position.current.z == COLLECTION_RADIUS + 1 then
      turtle_utils.turn(position, Directions.POS_Z)
    else
      turtle_utils.turn(position, Directions.NEG_Z)
    end

    harvestRow(position)
  end

  turtle_utils.goHome(position)
  turtle_utils.turn(position, turtle_utils.DROP_DIRECTION)
  turtle_utils.dropItems(position)
end

local function harvestWoodLayer(position)

  for i = 1, ROW_LENGTH - 1, 1 do
    turtle_utils.dig(position)
    turtle_utils.moveForward(position, 1)
  end
end

local function outOfSaplings()

  local slot_data = turtle.getItemDetail(1)
  return slot_data == nil
      or slot_data.name ~= SAPLING_ID
      or slot_data.count < ROWS * ROW_LENGTH
end

local function placeSapling()

  local successful = turtle.placeDown()
  while not successful do
    turtle_utils.pause('Sapling placement')
    successful = turtle.placeDown()
  end
end

local function plantRow(position)

  placeSapling()
  for i = 1, ROW_LENGTH - 1, 1 do
    turtle_utils.moveForward(position, 1)
    placeSapling()
  end
end

local function plantSaplings(position)

  turtle_utils.turn(position, Directions.POS_Z)
  turtle_utils.moveForward(position, COLLECTION_RADIUS)
  turtle_utils.turn(position, Directions.POS_X)
  turtle_utils.moveForward(position, 2 * COLLECTION_RADIUS * (ROWS - 1))
  turtle_utils.turn(position, Directions.POS_Z)
  turtle_utils.moveForward(position, 1)
  turtle_utils.moveUp(position, 1)

  if math.fmod(ROWS, 2) == 1 then
    turtle_utils.moveForward(position, ROW_LENGTH - 1)
    turtle_utils.turn(position, Directions.NEG_Z)
  end

  plantRow(position)
  for i = 1, ROWS - 1, 1 do
    turtle_utils.turn(position, Directions.NEG_X)
    turtle_utils.moveForward(position, COLLECTION_RADIUS)

    if position.current.z == COLLECTION_RADIUS + 1 then
      turtle_utils.turn(position, Directions.POS_Z)
    else
      turtle_utils.turn(position, Directions.NEG_Z)
    end

    plantRow(position)
  end

  turtle_utils.goHome(position)
end

main()
