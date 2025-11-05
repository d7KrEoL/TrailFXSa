## TrailFX Lua script
Hotkey to toggle the script on/off: `G`. You can change it in the script code, inside the `OnUpdateKeys()` function:
```lua
function OnUpdateKeys()
    if isKeyJustPressed(keys.VK_G) then -- Change here. For example, to use 'H' replace VK_G with VK_H
        TrailFXCommand()
    end
end
```
Main script command: `/trailfx`. If used without a player `id`, it toggles the script for yourself. If you use `/trailfx [id]`, it will add a trail to another player (the player must be near you and be the pilot of a vehicle supported by the script).

> [!NOTE]
> This functionality has not been thoroughly tested yet; issues may occur when adding multiple players.

### Adding new airplanes / editing existing ones
All information about supported airplanes is stored in the `dbOffset` table. This table is populated each time the script initializes, inside the `InitDB()` function.

Each entry in the table has the following format:

```lua
dbOffset 
{ 
    particleName1 = string "effect name 1 (FXSystem)", 
    particleName2 = string "effect name 2 (FXSystem)", 
    modelID = int vehicle_model, 
    x1 = float effect_1_X_offset, 
    y1 = float effect_1_Y_offset, 
    z1 = float effect_1_Z_offset, 
    x2 = float effect_2_X_offset, 
    y2 = float effect_2_Y_offset, 
    z2 = float effect_2_Z_offset 
}
```

To add a new airplane to the table, add an entry in `InitDB()` like:

```lua
table.insert(dbOffset, { particleName1 = "trail_white_long", particleName2 = "trail_blue_long", modelID = 513, x1 = 3, y1 = -0.2, z1 = -1.5, x2 = -3, y2 = -0.2, z2 = -1.5 })
```

Then add a mapping in the `GetPlaneOffsetType(modelID)` function like:

```lua
function GetPlaneOffsetType(modelID)
    if modelID == 520 then return 1
    elseif modelID == 476 then return 2
    -- New entry added below
    elseif modelID == 513 then return 3 -- return the next sequential number here
    end
    return nil
end
```