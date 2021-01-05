local turtle_utils = require('turtle_utils')

local DISTANCE_TO_FIRST_SAPLING = 3
local FARM_LENGTH = 8
local PAUSE_TIME = 1200
local SAPLING_NAME = 'minecraft:oak_sapling'
local TREE_HEIGHT = 7

local function outOfSaplings()

  local slot_data = turtle.getItemDetail(1)
  return slot_data == nil
      or slot_data.name ~= SAPLING_NAME
      or slot_data.count <= FARM_LENGTH
end

local function plantSaplings(position)

  turtle_utils.turn(position, '+z')
  turtle_utils.moveForward(position, DISTANCE_TO_FIRST_SAPLING + FARM_LENGTH - 1)
  turtle_utils.moveUp(position, 1)
  turtle_utils.turn(position, '-z')
  
  for i = 1, FARM_LENGTH, 1 do
    local successful = turtle.placeDown()
    while not successful do
      turtle_utils.pause('Sapling placement')
      successful = turtle.placeDown()
    end
    
    turtle_utils.moveForward(position, 1)
  end
  
  turtle_utils.goHome(position)
  turtle_utils.turn(position, '+z')
end

local function harvestRow(position)

  for i = 1, FARM_LENGTH - 1, 1 do
    turtle_utils.dig(position)
    turtle_utils.moveForward(position, 1)
  end
end

local function harvestTrees(position)

  turtle_utils.moveForward(position, DISTANCE_TO_FIRST_SAPLING - 1)
  turtle_utils.dig(position)
  turtle_utils.moveForward(position, 1)
  
  harvestRow(position)
  for i = 1, TREE_HEIGHT - 1, 1 do
    turtle_utils.digUp(position)
    turtle_utils.moveUp(position, 1)
    
    if position.current.direction == '+z' then
      turtle_utils.turn(position, '-z')
    else
      turtle_utils.turn(position, '+z')
    end
    
    harvestRow(position)
  end
end

turtle_utils.indicateRunning()
local position = turtle_utils.position
while true do
  if outOfSaplings() then
    turtle_utils.pickup(position)
    
    while outOfSaplings() do
      turtle_utils.pause('Sapling restock')
      turtle_utils.pickup(position)
    end
  end
  
  plantSaplings(position)
  sleep(PAUSE_TIME)
  harvestTrees(position)
  
  turtle_utils.goHome(position)
  turtle_utils.dropAll(position)
end
