--[[
  Utilities module for programs involving ComputerCraft turtles. Establishes a method for keeping
  track of relative position. Provides functions for advanced movement and interactions that can
  return home automatically when low on fuel or inventory and pause when an unexpected obstruction
  is encountered.

  Written by Kevin Cruse
]]

--[[
  Enumeration of possible directions along the 'x' and 'z' axes.
]]
local Directions = {
  POS_Z = 1,
  POS_X = 2,
  NEG_Z = 3,
  NEG_X = 4
}

--[[
  Whatever position and orientation the turtle has when createPosition is called becomes (0, 0, 0)
  and +z. At this position, depending on the program, up to three adjacent inventories are required.
  The relative direction of these inventories are set here.
]]
local DROP_DIRECTION = Directions.POS_Z  -- Direction to drop collected items
local REFUEL_DIRECTION = Directions.POS_X  -- Direction to collect fuel from
local PICKUP_DIRECTION = Directions.NEG_X  -- Direction to pick up any necessary materials from

--[[
  Slot range for disposable inventory. Any items that are collected
  into these slots will be deposited into the drop inventory.
]]
local FIRST_DISPOSABLE_SLOT = 2
local LAST_DISPOSABLE_SLOT = 16

-- Threshold for two floating point numbers to be considered equal
local _FLOATING_POINT_TOLERANCE = 0.001

local createPosition
local digDown
local digForward
local digUp
local dropItems
local goHome
local indicateRunning
local moveBackward
local moveDown
local moveForward
local moveUp
local pause
local pickUp
local refuel
local suckDown
local suckForward
local suckUp
local turn

local _attemptRefuelFromInventory
local _calcReturnSteps
local _checkDirectionValidity
local _checkNumericalCoordinates
local _checkPositionIntegrity
local _checkStepsValidity
local _dropItemsAndRefuelAtHome
local _hasEnoughFuel
local _isInventoryFull
local _moveOneStepBackward
local _moveOneStepDown
local _moveOneStepForward
local _moveOneStepUp
local _moveToX
local _moveToY
local _moveToZ
local _returnToSaved
local _savePosition
local _writeOut

--[[
  Returns a position table with the saved data from the given filename,
  if it exists, or a new table initialized to (0, 0, 0) and +z.

  Parameters:
    - filename: Name of file to save position data to

  Errors:
    - Non-string filename: Filename is not a string
    - Unable to open file: Filename is invalid
    - Unable to serialize position data: Position data stored in file was somehow corrupted
]]
createPosition = function(filename)

  assert(type(filename) == 'string', 'Non-string filename: ' .. tostring(filename))
  local filepath = '/' .. filename .. '.txt'

  local position

  if fs.exists(filepath) then
    local handle = fs.open(filepath, 'r')
    position = textutils.unserialize(handle.readAll())
    handle.close()
    assert(position, 'Unable to serialize position data: ' .. filepath)
  else
    position = {
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
      },
      filepath = filepath
    }
  end

  _writeOut(position)

  return position
end

--[[
  Mines the block below the turtle. Goes home if the disposable
  inventory is full and returns to the previous position.

  Parameters:
    - position: Position table to use for navigation if the turtle must return home

  Errors:
    - Malformed position: Position table is somehow invalid
]]
digDown = function(position)

  if _isInventoryFull() then
    _dropItemsAndRefuelAtHome(position)
  end

  turtle.select(FIRST_DISPOSABLE_SLOT)
  turtle.digDown()
end

--[[
  Mines the block in front of the turtle. Goes home if the disposable
  inventory is full and returns to the previous position.

  Parameters:
    - position: Position table to use for navigation if the turtle must return home

  Errors:
    - Malformed position: Position table is somehow invalid
]]
digForward = function(position)

  if _isInventoryFull() then
    _dropItemsAndRefuelAtHome(position)
  end

  turtle.select(FIRST_DISPOSABLE_SLOT)
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
digUp = function(position)

  if _isInventoryFull() then
    _dropItemsAndRefuelAtHome(position)
  end

  turtle.select(FIRST_DISPOSABLE_SLOT)
  turtle.digUp()
end

--[[
  Drops all disposable inventory items in front of the turtle.
]]
dropItems = function()

  for i = FIRST_DISPOSABLE_SLOT, LAST_DISPOSABLE_SLOT, 1 do
    turtle.select(i)
    turtle.drop()
  end
end

--[[
  Moves the turtle to (0, 0, 0) from the current position.

  Parameters:
    - position: Position table to use for navigation

  Errors:
    - Malformed position: Position table is somehow invalid
]]
goHome = function(position)

  _checkPositionIntegrity(position)

  _moveToY(position, 0)
  _moveToX(position, 0)
  _moveToZ(position, 0)
end

--[[
  Indicates on the terminal that the program is currently running.
]]
indicateRunning = function()

  term.clear()
  term.setCursorPos(1, 1)
  print('Running...')
end

--[[
  Moves the turtle backward by the given number of steps. If there is
  not enough fuel to make the movement, goes home and refuels first.

  Parameters:
    - position: Position table to use for navigation
    - steps: Number of steps to move backward by

  Errors:
    - Invalid step value: Step value is negative
    - Malformed position: Position table is somehow invalid
    - Non-numerical step value: Step value is not a number
]]
moveBackward = function(position, steps)

  _checkPositionIntegrity(position)
  _checkStepsValidity(steps)

  if not _hasEnoughFuel(position, steps) then
    _dropItemsAndRefuelAtHome(position)
  end

  for i = 1, steps, 1 do
    _moveOneStepBackward(position)
  end
end

--[[
  Moves the turtle down by the given number of steps. If there is not
  enough fuel to make the movement, goes home and refuels first.

  Parameters:
    - position: Position table to use for navigation
    - steps: Number of steps to move down by

  Errors:
    - Invalid step value: Step value is negative
    - Malformed position: Position table is somehow invalid
    - Non-numerical step value: Step value is not a number
]]
moveDown = function(position, steps)

  _checkPositionIntegrity(position)
  _checkStepsValidity(steps)

  if not _hasEnoughFuel(position, steps) then
    _dropItemsAndRefuelAtHome(position)
  end

  for i = 1, steps, 1 do
    _moveOneStepDown(position)
  end
end

--[[
  Moves the turtle forward by the given number of steps. If there is
  not enough fuel to make the movement, goes home and refuels first.

  Parameters:
    - position: Position table to use for navigation
    - steps: Number of steps to move forward by

  Errors:
    - Invalid step value: Step value is negative
    - Malformed position: Position table is somehow invalid
    - Non-numerical step value: Step value is not a number
]]
moveForward = function(position, steps)

  _checkPositionIntegrity(position)
  _checkStepsValidity(steps)

  if not _hasEnoughFuel(position, steps) then
    _dropItemsAndRefuelAtHome(position)
  end

  for i = 1, steps, 1 do
    _moveOneStepForward(position)
  end
end

--[[
  Moves the turtle up by the given number of steps. If there is not
  enough fuel to make the movement, goes home and refuels first.

  Parameters:
    - position: Position table to use for navigation
    - steps: Number of steps to move up by

  Errors:
    - Invalid step value: Step value is negative
    - Malformed position: Position table is somehow invalid
    - Non-numerical step value: Step value is not a number
]]
moveUp = function(position, steps)

  _checkPositionIntegrity(position)
  _checkStepsValidity(steps)

  if not _hasEnoughFuel(position, steps) then
    _dropItemsAndRefuelAtHome(position)
  end

  for i = 1, steps, 1 do
    _moveOneStepUp(position)
  end
end

--[[
  Pauses the program, displaying the given action which caused
  the pause and waits until the user presses a key to resume.
]]
pause = function(action)

  print(action .. ' unsuccessful. Press any key once resolved.')
  os.pullEvent('key')
  indicateRunning()
end

--[[
  Picks up items in front of the turtle until all leading non-disposable slots are filled.
]]
pickUp = function()

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
end

--[[
  Refuels from inventory or items in front of the turtle until
  enough fuel to return to the saved position is reached.

  Parameters:
    - position: Position table to use for determining fuel required

  Errors:
    - Malformed position: Position table is somehow invalid
]]
refuel = function(position)

  _checkPositionIntegrity(position)
  local steps = _calcReturnSteps(position)

  turtle.select(FIRST_DISPOSABLE_SLOT)

  turtle.suck()
  turtle.refuel()
  while not _hasEnoughFuel(position, steps) do
    pause('Refuel')

    turtle.suck()
    turtle.refuel()
  end
end

--[[
  Picks up items below the turtle. If the turtle's inventory is full,
  goes home and drops off items before picking up the item

  Parameters:
    - position: Position table to use for navigation if the turtle must return home

  Errors:
    - Malformed position: Position table is somehow invalid
]]
suckDown = function(position)

  if _isInventoryFull() then
    _dropItemsAndRefuelAtHome(position)
  end

  turtle.select(FIRST_DISPOSABLE_SLOT)
  turtle.suckDown()
end

--[[
  Picks up items in front of the turtle. If the turtle's inventory is
  full, goes home and drops off items before picking up the item

  Parameters:
    - position: Position table to use for navigation if the turtle must return home

  Errors:
    - Malformed position: Position table is somehow invalid
]]
suckForward = function(position)

  if _isInventoryFull() then
    _dropItemsAndRefuelAtHome(position)
  end

  turtle.select(FIRST_DISPOSABLE_SLOT)
  turtle.suck()
end

--[[
  Picks up items above the turtle. If the turtle's inventory is full,
  goes home and drops off items before picking up the item

  Parameters:
    - position: Position table to use for navigation if the turtle must return home

  Errors:
    - Malformed position: Position table is somehow invalid
]]
suckUp = function(position)

  if _isInventoryFull() then
    _dropItemsAndRefuelAtHome(position)
  end

  turtle.select(FIRST_DISPOSABLE_SLOT)
  turtle.suckUp()
end

--[[
  Turns the turtle toward the desired direction.

  Parameters:
    - position: Position table to use for turning the turtle
    - direction: Direction to turn the turtle toward

  Errors:
    - Invalid direction: Direction is not a member of the directions enumeration
    - Malformed position: Position table is somehow invalid
    - Non-numerical direction: Direction is not a number
]]
turn = function(position, direction)

  _checkPositionIntegrity(position)
  _checkDirectionValidity(direction)

  local unit_vectors = {
    [Directions.POS_Z] = {x = 0, z = 1},
    [Directions.POS_X] = {x = 1, z = 0},
    [Directions.NEG_Z] = {x = 0, z = -1},
    [Directions.NEG_X] = {x = -1, z = 0}
  }

  local angle = math.acos(unit_vectors[position.current.direction].x * unit_vectors[direction].x
      + unit_vectors[position.current.direction].z * unit_vectors[direction].z)
  local determinant = unit_vectors[position.current.direction].x * unit_vectors[direction].z
      - unit_vectors[position.current.direction].z * unit_vectors[direction].x

  local turn_func
  if determinant > 0 then
    turn_func = turtle.turnLeft
  else
    turn_func = turtle.turnRight
  end

  while angle > _FLOATING_POINT_TOLERANCE do
    turn_func()
    angle = angle - math.pi / 2
  end

  position.current.direction = direction
  _writeOut(position)
end

-- Attempts to refuel from the first disposable slot in the inventory
_attemptRefuelFromInventory = function()

  turtle.select(FIRST_DISPOSABLE_SLOT)
  turtle.refuel()
end

-- Calculates the number of steps required to return to the saved position from (0, 0, 0)
_calcReturnSteps = function(position)

  return math.abs(position.saved.x)
      + math.abs(position.saved.y)
      + math.abs(position.saved.z)
end

-- Checks that the given direction is a member of the directions enumeration
_checkDirectionValidity = function(direction)

  assert(type(direction) == 'number', 'Non-numerical direction: ' .. tostring(direction))

  local valid_direction = false

  for index, value in pairs(Directions) do
    if direction == value then
      valid_direction = true
      break
    end
  end

  assert(valid_direction, 'Invalid direction: ' .. direction)
end

-- Checks that the given position table is properly formed
_checkPositionIntegrity = function(position)

  assert(
    type(position) == 'table'
        and type(position.current) == 'table'
        and type(position.current.x) == 'number'
        and type(position.current.y) == 'number'
        and type(position.current.z) == 'number'
        and position.current.direction
        and type(position.saved) == 'table'
        and type(position.saved.x) == 'number'
        and type(position.saved.y) == 'number'
        and type(position.saved.z) == 'number'
        and position.saved.direction
        and type(position.filepath) == 'string',
    'Malformed position: ' .. textutils.serialize(position)
  )

  _checkDirectionValidity(position.current.direction)
  _checkDirectionValidity(position.saved.direction)
end

-- Checks that the given number of steps is non-negative
_checkStepsValidity = function(steps)

  assert(type(steps) == 'number', 'Non-numerical step value: ' .. tostring(steps))
  assert(steps >= 0, 'Invalid step value: ' .. steps)
end

-- Goes home, drops off all disposable items, refuels, and returns to previous position
_dropItemsAndRefuelAtHome = function(position)

  _savePosition(position)
  goHome(position)

  turn(position, DROP_DIRECTION)
  dropItems(position)

  _returnToSaved(position)
end

-- Determines if the turtle has enough fuel to move the specified number of steps
_hasEnoughFuel = function(position, steps)

  return 2 * (
    steps
        + math.abs(position.current.x)
        + math.abs(position.current.y)
        + math.abs(position.current.z)
  ) <= turtle.getFuelLevel()
end

-- Determines if the turtle's disposable inventory is full
_isInventoryFull = function()

  return turtle.getItemCount(LAST_DISPOSABLE_SLOT) > 0
end

-- Moves the turtle one step backward. If the turtle is out of
-- fuel, attempts to refuel from the first disposable slot
_moveOneStepBackward = function(position)

  local successful = false
  while not successful do
    successful = turtle.back()

    if successful then
      if position.current.direction == Directions.POS_Z then
        position.current.z = position.current.z - 1
      elseif position.current.direction == Directions.POS_X then
        position.current.x = position.current.x - 1
      elseif position.current.direction == Directions.NEG_Z then
        position.current.z = position.current.z + 1
      else
        position.current.x = position.current.x + 1
      end

      _writeOut(position)
    else
      pause('Movement')

      if turtle.getFuelLevel() == 0 then
        _attemptRefuelFromInventory()
      end
    end
  end
end

-- Moves the turtle one step down. If the turtle is out of fuel,
-- attempts to refuel from the first disposable slot
_moveOneStepDown = function(position)

  local successful = false
  while not successful do
    successful = turtle.down()

    if successful then
      position.current.y = position.current.y - 1
      _writeOut(position)
    else
      pause('Movement')

      if turtle.getFuelLevel() == 0 then
        _attemptRefuelFromInventory()
      end
    end
  end
end

-- Moves the turtle one step forward. If the turtle is out of
-- fuel, attempts to refuel from the first disposable slot
_moveOneStepForward = function(position)

  local successful = false
  while not successful do
    successful = turtle.forward()

    if successful then
      if position.current.direction == Directions.POS_Z then
        position.current.z = position.current.z + 1
      elseif position.current.direction == Directions.POS_X then
        position.current.x = position.current.x + 1
      elseif position.current.direction == Directions.NEG_Z then
        position.current.z = position.current.z - 1
      else
        position.current.x = position.current.x - 1
      end

      _writeOut(position)
    else
      pause('Movement')

      if turtle.getFuelLevel() == 0 then
        _attemptRefuelFromInventory()
      end
    end
  end
end

-- Moves the turtle one step forward. If the turtle is out of
-- fuel, attempts to refuel from the first disposable slot
_moveOneStepUp = function(position)

  local successful = false
  while not successful do
    successful = turtle.up()

    if successful then
      position.current.y = position.current.y + 1
      _writeOut(position)
    else
      pause('Movement')

      if turtle.getFuelLevel() == 0 then
        _attemptRefuelFromInventory()
      end
    end
  end
end

-- Moves to the given 'x' coordinate
_moveToX = function(position, coordinate)

  if position.current.x < coordinate then
    turn(position, Directions.POS_X)
  elseif position.current.x > coordinate then
    turn(position, Directions.NEG_X)
  end
  for i = 1, math.abs(position.current.x - coordinate), 1 do
    _moveOneStepForward(position)
  end
end

-- Moves to the given 'y' coordinate
_moveToY = function(position, coordinate)

  if position.current.y < coordinate then
    for i = 1, math.abs(position.current.y - coordinate), 1 do
      _moveOneStepUp(position)
    end
  elseif position.current.y > 0 then
    for i = 1, math.abs(position.current.y - coordinate), 1 do
      _moveOneStepDown(position)
    end
  end
end

-- Moves to the given 'z' coordinate
_moveToZ = function(position, coordinate)

  if position.current.z < coordinate then
    turn(position, Directions.POS_Z)
  elseif position.current.z > coordinate then
    turn(position, Directions.NEG_Z)
  end
  for i = 1, math.abs(position.current.z - coordinate), 1 do
    _moveOneStepForward(position)
  end
end

-- Returns to the saved position
_returnToSaved = function(position)

  if not _hasEnoughFuel(position, _calcReturnSteps(position)) then
    turn(position, REFUEL_DIRECTION)
    refuel(position)
  end

  _moveToZ(position, position.saved.z)
  _moveToX(position, position.saved.x)
  _moveToY(position, position.saved.y)

  turn(position, position.saved.direction)
end

-- Saves the current position
_savePosition = function(position)

  position.saved.x = position.current.x
  position.saved.y = position.current.y
  position.saved.z = position.current.z
  position.saved.direction = position.current.direction

  _writeOut(position)
end

-- Writes out the given position table to file
_writeOut = function(position)

  local handle = fs.open(position.filepath, "w")
  assert(handle, 'Unable to open file: ' .. position.filepath)
  handle.write(textutils.serialize(position))
  handle.close()
end

return {
  Directions = Directions,

  DROP_DIRECTION = DROP_DIRECTION,
  REFUEL_DIRECTION = REFUEL_DIRECTION,
  PICKUP_DIRECTION = PICKUP_DIRECTION,

  FIRST_DISPOSABLE_SLOT = FIRST_DISPOSABLE_SLOT,
  LAST_USED_SLOT = LAST_USED_SLOT,

  createPosition = createPosition,
  digDown = digDown,
  digForward = digForward,
  digUp = digUp,
  dropItems = dropItems,
  goHome = goHome,
  indicateRunning = indicateRunning,
  moveBackward = moveBackward,
  moveDown = moveDown,
  moveForward = moveForward,
  moveUp = moveUp,
  pause = pause,
  pickUp = pickUp,
  refuel = refuel,
  suckDown = suckDown,
  suckForward = suckForward,
  suckUp = suckUp,
  turn = turn
}
