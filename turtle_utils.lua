--[[
  Utilities module for programs involving ComputerCraft turtles. Establishes a method for keeping
  track of relative position. Provides functions for advanced movement and interactions that can
  return home automatically when low on fuel or inventory and pause when an unexpected obstruction
  is encountered.
  
  Written by Kevin Cruse.
]]

--[[
  Enumeration of possible directions along the 'x' and 'z' axes. The integer values represent the
  number of right turns needed to turn to the associated direction from +z.
]]
Directions = {
  POS_Z = 0,
  POS_X = 1,
  NEG_Z = 2,
  NEG_X = -1
}

--[[
  Whatever position and orientation the turtle has when createPosition is called becomes (0, 0, 0)
  and +z. At this position, depending on the program, up to three adjacent inventories are required.
  The relative direction of these inventories are set here.
]]
DROP_DIRECTION = Directions.NEG_Z  -- Inventory to drop collected items
REFUEL_DIRECTION = Directions.NEG_X  -- Inventory to collect fuel from
PICKUP_DIRECTION = Directions.POS_X  -- Inventory to pick up any necessary materials from

--[[
  Slot range for disposable inventory. Any items that are collected
  into these slots will be deposited into the drop inventory.
]]
FIRST_DISPOSABLE_SLOT = 2
LAST_DISPOSABLE_SLOT = 16

--[[
  Returns a position table with the current and saved positions initialized to (0, 0, 0) and +z.
]]
function createPosition()

  return {
    current = {
      x = 0,
      y = 0,
      z = 0,
      direction = Directions.POS_Z
    },
    saved = {
      x = 0,
      y = 0,
      z = 0,
      direction = Directions.POS_Z
    }
  }
end

--[[
  Mines the block in front of the turtle. Goes home if the disposable
  inventory is full and returns to the previous position.
  
  Parameters:
    - position: Position table to use for navigation if the turtle must return home
  
  Errors:
    - Malformed position: Position table is somehow invalid
]]
function dig(position)
  
  if isInventoryFull() then
    dropItemsAtHome(position)
  end
  
  turtle.dig()
end

--[[
  Mines the block above the turtle. Goes home if the disposable
  inventory is full and returns to the previous position.
  
  Parameters:
    - position: Position table to use for navigation if the turtle must return home
  
  Errors:
    - Malformed position: Position table is somehow invalid
]]
function digUp(position)

  if isInventoryFull() then
    dropItemsAtHome(position)
  end
  
  turtle.digUp()
end

--[[
  Drops all disposable inventory items in front of the turtle.
]]
function dropItems()
  
  for i = FIRST_DISPOSABLE_SLOT, LAST_DISPOSABLE_SLOT, 1 do
    turtle.select(i)
    turtle.drop()
  end
  
  turtle.select(1)
end

--[[
  Moves the turtle to (0, 0, 0) from the current position.
  
  Parameters:
    - position: Position table to use for navigation
  
  Errors:
    - Malformed position: Position table is somehow invalid
]]
function goHome(position)
  
  checkPositionIntegrity(position)
  
  moveToY(position, 0)
  moveToX(position, 0)
  moveToZ(position, 0)
end

--[[
  Indicates on the terminal that the program is currently running.
]]
function indicateRunning()

  term.clear()
  term.setCursorPos(1, 1)
  print('Running...')
end

--[[
  Moves the turtle down by the given number of steps.
  
  Parameters:
    - position: Position table to use for navigation
    - steps: Number of steps to move down by
  
  Errors:
    - Malformed position: Position table is somehow invalid
    - Invalid number of steps: Number of steps is either not a number or is negative
]]
function moveDown(position, steps)
  
  checkPositionIntegrity(position)
  steps = checkStepsValidity(steps)
  
  if not hasEnoughFuel(position, steps) then
    refuelAtHome(position)
  end
  
  for i = 1, steps, 1 do
    moveOneStepDown(position)
  end
end

--[[
  Moves the turtle forward by the given number of steps.
  
  Parameters:
    - position: Position table to use for navigation
    - steps: Number of steps to move forward by
  
  Errors:
    - Malformed position: Position table is somehow invalid
    - Invalid number of steps: Number of steps is either not a number or is negative
]]
function moveForward(position, steps)
  
  checkPositionIntegrity(position)
  steps = checkStepsValidity(steps)
  
  if not hasEnoughFuel(position, steps) then
    refuelAtHome(position)
  end

  for i = 1, steps, 1 do
    moveOneStepForward(position)
  end
end

--[[
  Moves the turtle up by the given number of steps.
  
  Parameters:
    - position: Position table to use for navigation
    - steps: Number of steps to move up by
  
  Errors:
    - Malformed position: Position table is somehow invalid
    - Invalid number of steps: Number of steps is either not a number or is negative
]]
function moveUp(position, steps)

  checkPositionIntegrity(position)
  steps = checkStepsValidity(steps)
  
  if not hasEnoughFuel(position, steps) then
    refuelAtHome(position)
  end
  
  for i = 1, steps, 1 do
    moveOneStepUp(position)
  end
end

--[[
  Pauses the program, displaying the given action which caused
  the pause and waits until the user presses a key to resume.
]]
function pause(action)

  print(action .. ' unsuccessful. Press any key once resolved.')
  os.pullEvent('key')
  indicateRunning()
end

--[[
  Picks up items in front of the turtle until all leading non-disposable slots are filled.
]]
function pickUp()
  
  for i = 1, FIRST_DISPOSABLE_SLOT - 1, 1 do
    turtle.select(i)
  
    turtle.suck()
    local successful = turtle.getItemCount(i) >= 1
    while not successful do
      pause('Pickup')
    
      turtle.suck()
      successful = turtle.getItemCount(i) >= 1
    end
  end
  
  turtle.select(1)
end

--[[
  Refuels from inventory or items in front of the turtle until
  enough fuel to return to the saved position is reached.
  
  Parameters:
    - position: Position table to use for determining fuel required
  
  Errors:
    - Malformed position: Position table is somehow invalid
]]
function refuel(position)

  checkPositionIntegrity(position)
  local steps = calcReturnSteps(position)
  
  turtle.select(FIRST_DISPOSABLE_SLOT)

  turtle.suck()
  turtle.refuel()
  while not hasEnoughFuel(position, steps) do
    pause('Refuel')
    
    turtle.suck()
    turtle.refuel()
  end
  
  turtle.select(1)
end

--[[
  Turns the turtle toward the desired direction.
  
  Parameters:
    - position: Position table to use for turning the turtle
    - direction: Direction to turn the turtle toward
  
  Errors:
    - Invalid direction: Direction is not a member of the directions enumeration
    - Malformed position: Position table is somehow invalid
]]
function turn(position, direction)

  checkPositionIntegrity(position)
  checkDirectionValidity(direction)
  
  local right_turns_required = Directions[direction] - Directions[position.current.direction]  
  if right_turns_required > 0 then
    for i = 1, right_turns_required, 1 do
      turtle.turnRight()
    end
  elseif distance < 0 then
    for i = 1, -right_turns_required, 1 do
      turtle.turnLeft()
    end
  end
  
  position.current.direction = direction
end

-- Calculates the number of steps required to return to the saved position from (0, 0, 0)
local function calcReturnSteps(position)

  return math.abs(position.saved.x)
      + math.abs(position.saved.y)
      + math.abs(position.saved.z)
end

-- Checks that the given direction is a member of the directions enumeration
local function checkDirectionValidity(direction)

  assert(Directions[direction] ~= nil, 'Invalid direction')
end

-- Checks that the given position table is properly formed
local function checkPositionIntegrity(position)

  assert(
    position ~= nil
        and position.current ~= nil
        and position.current.x ~= nil
        and position.current.y ~= nil
        and position.current.z ~= nil
        and position.current.direction ~= nil
        and position.saved ~= nil
        and position.saved.x ~= nil
        and position.saved.y ~= nil
        and position.saved.z ~= nil
        and position.saved.direction ~= nil,
    'Malformed position'
  )
  
  checkDirectionValidity(position.current.direction)
  checkDirectionValidity(position.saved.direction)
end

local function checkStepsValidity(steps)

  steps = tonumber(steps)
  assert(steps ~= nil and steps >= 0, 'Invalid number of steps')
  return steps
end

local function dropItemsAtHome(position)

  savePosition(position)
  goHome(position)
  
  dropItems(position)
  
  if not hasEnoughFuel(position, calcReturnSteps()) then
    grabFuel(position)
  end
  
  returnToSaved(position)
end

local function hasEnoughFuel(position, steps)

  return 2 * (
    steps
    + math.abs(position.current.x)
    + math.abs(position.current.y)
    + math.abs(position.current.z)
  ) <= turtle.getFuelLevel()
end

local function isInventoryFull()

  return turtle.getItemCount(LAST_DISPOSABLE_SLOT) > 0
end

local function moveOneStepDown(position)

  local successful = false
  while not successful do
    successful = turtle.down()
    
    if successful then
      position.current.y = position.current.y - 1
    else
      pause('Movement')
      
      if turtle.getFuelCount() == 0 then
        tryRefuel()
      end
    end
  end
end

local function moveOneStepForward(position)

  local successful = false
  while not successful do
    successful = turtle.forward()

    if successful then
      if position.current.direction == '+x' then
        position.current.x = position.current.x + 1
      elseif position.current.direction == '-x' then
        position.current.x = position.current.x - 1
      elseif position.current.direction == '+z' then
        position.current.z = position.current.z + 1
      elseif position.current.direction == '-z' then
        position.current.z = position.current.z - 1
      end
    else
      pause('Movement')
      
      if turtle.getFuelLevel() == 0 then
        tryRefuel()
      end
    end
  end
end

local function moveOneStepUp(position)

  local successful = false
  while not successful do
    successful = turtle.up()

    if successful then
      position.current.y = position.current.y + 1
    else
      pause('Movement')
      
      if turtle.getFuelCount() == 0 then
        tryRefuel()
      end
    end
  end
end

local function moveToX(position, coordinate)

  if position.current.x < 0 then
    turn(position, Directions.POS_X)
  elseif position.current.x > 0 then
    turn(position, Directions.NEG_X)
  end
  for i = 1, math.abs(position.current.x), 1 do
    moveOneStepForward(position)
  end
end

local function moveToY(position, coordinate)

  if position.current.y < 0 then
    for i = 1, -position.current.y, 1 do
      moveOneStepUp(position)
    end
  elseif position.current.y > 0 then
    for i = 1, position.current.y, 1 do
      moveOneStepDown(position)
    end
  end
end

local function moveToZ(position, coordinate)

  if position.current.z < 0 then
    turn(position, Directions.POS_Z)
  elseif position.current.z > 0 then
    turn(position, Directions.NEG_Z)
  end
  for i = 1, math.abs(position.current.z), 1 do
    moveOneStepForward(position)
  end
end

local function refuelAtHome(position)

  savePosition(position)
  goHome(position)
  
  dropItems(position)
  refuel(position)
  
  returnToSaved(position)
end

local function returnToSaved(position)

  if position.saved.z < 0 then
    turn(position, '-z')
  elseif position.saved.z > 0 then
    turn(position, '+z')
  end
  for i = 1, math.abs(position.saved.z), 1 do
    moveOneStepForward(position)
  end
  
  if position.saved.x < 0 then
    turn(position, '-x')
  elseif position.saved.x > 0 then
    turn(position, '+x')
  end
  
  for i = 1, math.abs(position.saved.x), 1 do
    moveOneStepForward(position)
  end
  
  if position.saved.y < 0 then
    for i = 1, -position.saved.y, 1 do
      moveOneStepDown(position)
    end
  elseif position.saved.y > 0 then
    for i = 1, position.saved.y, 1 do
      moveOneStepUp(position)
    end
  end
  
  turn(position, position.saved.direction)
end

local function savePosition(position)

  position.saved.x = position.current.x
  position.saved.y = position.current.y
  position.saved.z = position.current.z
  position.saved.direction = position.current.direction
end

local function tryRefuel()

  turtle.select(FIRST_DISPOSABLE_SLOT)
  turtle.refuel()
  turtle.select(1)
end

return {
  Directions = Directions,
  
  DROP_DIRECTION = DROP_DIRECTION,
  REFUEL_DIRECTION = REFUEL_DIRECTION,
  PICKUP_DIRECTION = PICKUP_DIRECTION,
  
  FIRST_DISPOSABLE_SLOT = FIRST_DISPOSBALE_SLOT,
  LAST_USED_SLOT = LAST_USED_SLOT,
  
  createPosition = createPosition,
  dig = dig,
  digUp = digUp,
  dropItems = dropItems,
  goHome = goHome,
  indicateRunning = indicateRunning,
  moveDown = moveDown,
  moveForward = moveForward,
  moveUp = moveUp,
  pause = pause,
  pickUp = pickUp,
  refuel = refuel,
  turn = turn
}
