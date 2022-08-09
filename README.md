# vInspector
 Vehicle inspector for FiveM

 Creates dynamic showroom cameras to inspect a vehicle and adds interactive rotation with the mouse. Useful for cardealers / showrooms.

 [Demo Video](https://streamable.com/etw0i2)
 
 ## Installation
* Drop the `vInspector` directory into you `resources` directory
* Add `ensure vInspector` to your `server.cfg` file
* Add `'@vInspector/inspector.lua'` to the `client_scripts` table in the `fxmanifest.lua` of the resource(s) that will be using it:

```lua
client_scripts {
    '@vInspector/inspector.lua',
    ...
}
```

---

 ## Creating an instance
 Simply pass the model name of the vehicle you want to spawn and the coords (as a `vector4` type) to the constructor:
 ```lua
 local myInspector = Inspector:Create({
    model = 'adder', -- the vehicle model name
    coords = vector4(-791.61, -217.96, 36.40, 90.00), -- the spawn coords
    hasRearEngine = true, -- whether the vehicle is rear / mid-engined
    engineCompartmentIndex = 5, -- engine compartment doorIndex
    putInVehicle = false, -- whether to put the player in the vehicle or spawn a clone (required for cockpit view)
    easeIn = false, -- whether to smoothly transition to the inspector camera
    easeOut = false, -- whether to smoothly transition back to the player camera
    revolve = true, -- whether to set the vehicle as revolving when entering inspector
    rotate = true, -- whether to allow mouse-controlled rotation
    zoom = true, -- whether to allow zoom in / out
    toggleEngine = true, -- whether to allow toggling the engine on and off
    views = { 'front', 'rear', 'side', 'wheel', 'engine', 'cockpit' } -- available views
    primaryColor = { r = 255, g = 255, b = 255 } -- set the vehicle's primary colour
 })
 ```
 
 ---

 
## Controls
 * `F` - Switches to `'front'` view
 * `S` - Switches to `'side'` view
 * `R` - Switches to `'rear'` view
 * `C` - Switches to `'cockpit'` view
 * `E` - Switches to `'engine'` view (if it has a valid engine compartment door)
 * `G` - Switches to `'wheel'` view
 * `BACKSPACE` Switches to `'main'` view or exits the inspector if already in `'main'` view.
 * `SPACE` - Toggles auto-revolve (`'main'` view only)
 * `LSHIFT` - Toggles the vehicle's engine
 * `LMB` + `MOUSEMOVE` - Rotates the vehicle (`'main'` view only)
 * `MOUSEWHEEL` - Zooms In / Out (`'main'` view only)
 
The player is able to look around the cockpit while in `'cockpit'` view

Note: For the `'engine'` view there is list of rear/mid-engined vehicles included. If you use custom cars with rear/mid engines then you'll need to set the `hasRearEngine` option to `true` so the camera will focus on it correctly.

Some custom vehicles with rear / mid engines have the rear compartment door index incorrectly set to `4` (the bonnet) - if this is the case, then you need to set the `engineCompartmentIndex` to `4` otherwise the default index of `5` (the boot) will be used.

If the vehicle's engine compartment doesn't function then the instance will automatically remove the option for the `'engine'` view.

 ---
 
 ## Events

 ```lua
 local myInspector = Inspector:Create({ ... })
 
 myInspector:On('enter', function()
    -- do something when entering the inspector
 end)
 
  myInspector:On('viewChange', function(view -- [[ string ]])
    -- do something when the view is switched
 end)
 
   myInspector:On('exit', function()
    -- do something when exiting the inspector
 end)
 ```
 
 ---

 ## ToDo
- [ ] Allow controls to be customised
- [ ] Allow setting of vehicle attributes / mods
- [ ] Allow custom offsets / rotations for cameras
- [x] Fix camera distance when motorcycles are used
- [x] Some custom vehicles are badly made and the bounding boxes are off center which can cause the front / rear cameras to be misaligned - need to find a way of fixing this. Possibly use bones for alignment.
