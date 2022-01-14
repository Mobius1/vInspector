# vInspector
 Vehicle inspector for FiveM

 Creates dynamic showroom cameras to inspect a vehicle. Useful for cardealers.
 
 ## Installation
* Drop the `vInspector` directory into you `resources` directory
* Add `ensure vInspector` to your `server.cfg` file
* Add `'@vInspector/inspector.lua'` to the `client_scripts` table in the `fxmanifest.lua`:

```lua
client_scripts {
    '@vInspector/inspector.lua',
    ...
}
```

---

 ## Creating an instance
 ```lua
 local myInspector = Inspector:Create(model, --[[ string ]], coords -- [[ Vector4 ]])
 ```
 
 The controls will be displayed on screen for the player.
 
 ---
 
 ## Events

 ```lua
 local myInspector = Inspector:Create(model, --[[ string ]], coords -- [[ Vector4 ]])
 
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