-- List of rear / mid-engined vehicles
RearEnginedVehicles = {
    [`ninef`] = true,
    [`adder`] = true,
    [`vagner`] = true,
    [`t20`] = true,
    [`infernus`] = true,
    [`zentorno`] = true,
    [`reaper`] = true,
    [`comet2`] = true,
    [`comet3`] = true,
    [`jester`] = true,
    [`jester2`] = true,
    [`cheetah`] = true,
    [`cheetah2`] = true,
    [`prototipo`] = true,
    [`turismor`] = true,
    [`pfister811`] = true,
    [`ardent`] = true,
    [`nero`] = true,
    [`nero2`] = true,
    [`tempesta`] = true,
    [`vacca`] = true,
    [`bullet`] = true,
    [`osiris`] = true,
    [`entityxf`] = true,
    [`turismo2`] = true,
    [`fmj`] = true,
    [`re7b`] = true,
    [`tyrus`] = true,
    [`italigtb`] = true,
    [`penetrator`] = true,
    [`monroe`] = true,
    [`ninef2`] = true,
    [`stingergt`] = true,
    [`surfer`] = true,
    [`surfer2`] = true,
    [`gp1`] = true,
    [`autarch`] = true,
    [`tyrant`] = true,
}

local function mergeTables(t1, t2)
    for k,v in pairs(t2) do
        if type(v) == "table" then
            if type(t1[k] or false) == "table" then
                mergeTables(t1[k] or {}, t2[k] or {})
            else
                t1[k] = v
            end
        else
            t1[k] = v
        end
    end
    return t1
end

Inspector = {}
Inspector.__index = Inspector

function Inspector:Create(options)
    local obj = {}

    setmetatable(obj, Inspector)

    local player = PlayerPedId()
    obj.playerCoords = GetEntityCoords(player)
    obj.playerHeading = GetEntityHeading(player)
        
    obj.camCoords = vector3(0,0,0)
    obj.camRotation = vector3(0,0,0)
    obj.FOV = 60
    obj.currentCam = nil
    obj.currentView = nil
        
    obj.screenWidth = 0
    obj.screenHeight = 0
    obj.lastX = 0
    obj.camRotY = 0  
    obj.timestamp = nil
    obj.mouseDown = false
    obj.revolve = false
    obj.lastRevolve = false
    obj.firstDown = true
    obj.inertia = 0
    obj.direction = 0
    obj.initialised = false
    obj.KillThread = false
    obj.callbacks = {}
    obj.views = { 'main', 'front', 'rear', 'side', 'wheel', 'engine', 'cockpit' }

    -- Default config for set-up
    local defaultConfig = {
        maxCockpitViewAngle = 180,
        engineCompartmentIndex = 4,
        hasRearEngine = false
    }

    obj.options = mergeTables(defaultConfig, options)

    assert(IsModelInCdimage(GetHashKey(obj.options.model)), '^1Invalid model')
    assert(type(obj.options.coords) == 'vector4', '^1Invalid vector4')

    obj:CreateCams()
    obj:SpawnVehicle()

    -- Make sure we destroy the instance if the resource stops
    AddEventHandler('onResourceStop', function(resource)
        if resource == GetCurrentResourceName() then
            obj:Destroy()
        end
    end)   

    return obj
end

function Inspector:CreateCams()
    self.cams = {}

    for _, view in ipairs(self.views) do
        self.cams[view] = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", vector3(0,0,0), vector3(0,0,0), self.FOV * 1.0)
    end
end

function Inspector:SpawnVehicle(model)
    Citizen.CreateThread(function()
        local player = PlayerPedId()

        -- Load the model
        local model = GetHashKey(self.options.model)

        if not HasModelLoaded(model) and IsModelInCdimage(model) then
            RequestModel(model)

            while not HasModelLoaded(model) do
                Citizen.Wait(4)
            end
        end
    
        -- Create the vehicle
        local vehicle = CreateVehicle(model, self.options.coords.xyz, self.options.coords.w, false, false)
    
        local netid = NetworkGetNetworkIdFromEntity(vehicle)
        SetVehicleHasBeenOwnedByPlayer(vehicle, true)
        SetNetworkIdCanMigrate(netid, true)
        SetVehicleNeedsToBeHotwired(vehicle, false)
        SetVehRadioStation(vehicle, 'OFF')
        SetVehicleEngineOn(vehicle, false, false, true)
        SetVehicleHandbrake(vehicle, true) -- Prevent driving
        FreezeEntityPosition(vehicle, true) -- Prevent driving
        SetModelAsNoLongerNeeded(model)

        self.hasValidEngineBay = false
        self.isRearEngined = RearEnginedVehicles[model] or self.options.hasRearEngine

        if self.isRearEngined then
            self.hasValidEngineBay = GetIsDoorValid(vehicle, self.options.engineCompartmentIndex or 5)
        else
            self.hasValidEngineBay = GetIsDoorValid(vehicle, self.options.engineCompartmentIndex or 4)
        end

        SetEntityAlpha(player, 0) -- Hide the player so we can see the interior
    
        -- Make sure we have collisions loaded
        RequestCollisionAtCoord(self.options.coords.xyz)
        while not HasCollisionLoadedAroundEntity(vehicle) do
            Citizen.Wait(0)
        end

        -- Put player in vehicle
        TaskWarpPedIntoVehicle(player, vehicle, -1)
    
        self.vehicle = vehicle
        self.spawnCoords = GetEntityCoords(self.vehicle)
        self.spawnHeading = GetEntityHeading(self.vehicle)        
        self.currentRotation = GetEntityRotation(self.vehicle).z

        -- TriggerEvent('viewer:client:start')
        self:Start()
    end)
end

function Inspector:DeleteVehicle()
    if self.vehicle then
        SetEntityAsMissionEntity(self.vehicle, false, true)
        DeleteVehicle(self.vehicle)
        self.vehicle = nil

        -- Put the player back where they were
        local player = PlayerPedId()
        SetEntityCoordsNoOffset(player, self.playerCoords.x, self.playerCoords.y, self.playerCoords.z, 0, 0, 0)
        SetEntityHeading(player, self.playerHeading)
        ResetEntityAlpha(player)
        FreezeEntityPosition(player, false)
    end
end

function Inspector:Start()
    local coords = self:GetFrontOfVehicle()

    self:SetView('main')

    SetCamAffectsAiming(self.currentCam, false)

    SetFocusPosAndVel(self.spawnCoords.x, self.spawnCoords.y, self.spawnCoords.z, 20.0, 20.0, 20.0)    

    DisplayRadar(false)

    if self.callbacks.enter then
        self.callbacks.enter(self.vehicle)
    end
    
    self:CreateThreads()
end

function Inspector:Destroy()
    self.KillThread = true

    ClearFocus()
    RenderScriptCams(0, false, 0, true, false)
    DestroyAllCams(true)
    
    self.cams = {}

    SetScaleformMovieAsNoLongerNeeded(self.buttons)

    DisplayRadar(true)

    self:DeleteVehicle()

    if self.callbacks.exit then
        self.callbacks.exit()
    end
end

function Inspector:CreateThreads()
    if not self.initialised then
    
        self.initialised = true
        self.KillThread = false

        self:SetScreenSize()

        Citizen.CreateThread(function()
            while true do
                if not self.transitioning then
                    if self.currentView == 'main' then
                        if IsDisabledControlJustPressed(0, 24) then
                            self:OnMouseDown()
                        elseif IsDisabledControlJustReleased(0, 24) then
                            self:OnMouseUp()
                        end

                        if IsControlPressed(0, 15) then
                            if self.FOV > 1.0 then
                                self.FOV = self.FOV - 1.0
                                SetCamFov(self.currentCam, self.FOV * 1.0)
                            end
                        elseif IsControlPressed(0, 14) then
                            if self.FOV < 130.0 then
                                self.FOV = self.FOV + 1.0
                                SetCamFov(self.currentCam, self.FOV * 1.0)
                            end                    
                        end
                    end

                    if IsDisabledControlJustPressed(0, 22) then -- TOGGLE REVOLVE
                        self.revolve = not self.revolve
                        self.inertia = 0
                    elseif IsDisabledControlJustPressed(0, 23) then -- SET FRONT VIEW
                        self.revolve = false
                        self.inertia = 0
                        self:SetView('front')          
                    elseif IsDisabledControlJustPressed(0, 47) then -- SET WHEEL VIEW
                        self.revolve = false
                        self.inertia = 0
                        self:SetView('wheel')
                    elseif IsDisabledControlJustPressed(0, 45) then -- SET REAR VIEW
                        self.revolve = false
                        self.inertia = 0
                        self:SetView('rear')
                    elseif IsDisabledControlJustPressed(0, 33) then -- SET SIDE VIEW
                        self.revolve = false
                        self.inertia = 0
                        self:SetView('side')
                    elseif IsDisabledControlJustPressed(0, 26) then -- SET COCKPIT VIEW
                        self.revolve = false
                        self.inertia = 0
                        self:SetView('cockpit')
                    elseif IsDisabledControlJustPressed(0, 38) then -- SET ENGINE VIEW
                        if self.hasValidEngineBay then
                            self.revolve = false
                            self.inertia = 0
                            self:SetView('engine')
                        end                                   
                    elseif IsControlJustPressed(0, 194) then -- EXIT
                        if self.currentView == 'main' then
                            self:Destroy()
                        else
                            self:SetView('main')
                        end
                    elseif IsDisabledControlJustPressed(0, 21) then -- ENGINE
                        self.engineRunning = not self.engineRunning
                        SetVehicleEngineOn(self.vehicle, self.engineRunning, false, true)
                    end
                end

                if self.KillThread then
                    self.initialised = false
                    return
                end

                Citizen.Wait(0)
            end
        end)

        Citizen.CreateThread(function()
            while true do
                -- Display instructional buttons
                DrawScaleformMovieFullscreen(self.buttons, 255, 255, 255, 255, 0)

                self:DisableActions()

                if not self.transitioning then
                    if self.currentView == 'main' then
                        SetMouseCursorSprite(self.mouseDown and 4 or 3)
                        SetMouseCursorActiveThisFrame()

                        if self.revolve and not self.rotatingTo then
                            self:SetVehicleRotation(self.currentRotation + 0.2)
                        end                    
                    end

                    if self.currentView == 'cockpit' then
                        local x = GetDisabledControlNormal(2, 239)
                        local y = GetDisabledControlNormal(2, 240)

                        SetCamRot(
                            self.currentCam,
                            -((y - 0.5) * 90.00),
                            0,
                            -((x - 0.5) * self.options.maxCockpitViewAngle) + self.currentRotation, 
                            2
                        )
                    end

                    if self.mouseDown then
                        local x, y = self:GetMousePosition()

                        if self.timestamp == nil then
                            self.timestamp = GetGameTimer()
                        end
        
                        local now = GetGameTimer()
                        local dt =  now - self.timestamp
                        local dx = x - self.lastX
                        local speedX = math.abs(dx / dt)

                        self.inertia = speedX / 2

                        if dt > 0 then
                            if x < self.lastX then
                                self.direction = 0
                                self:SetVehicleRotation(self.currentRotation - speedX)
                            elseif x > self.lastX then
                                self.direction = 1
                                self:SetVehicleRotation(self.currentRotation + speedX)
                            end
                        end
        
                        self.lastX = x
                        self.timestamp = now;
                    else
                        local min = 0
                        if self.revolve then
                            min = 0.2
                        end

                        if self.inertia > min then
                            if self.direction > 0 then
                                self:SetVehicleRotation(self.currentRotation + self.inertia)
                            else
                                self:SetVehicleRotation(self.currentRotation - self.inertia)
                            end

                            self.inertia = self.inertia - 0.025
                        end
                    end                
                end                
                
                if self.KillThread then
                    self.initialised = false
                    return
                end

                Citizen.Wait(0)
            end
        end)
    end
end

function Inspector:SetVehicleRotation(rotation)
    self.currentRotation = rotation
    self:LimitRotation()

    SetEntityRotation(self.vehicle, 0, 0, self.currentRotation, 2)
end

function Inspector:LimitRotation()
    self.currentRotation =  self.currentRotation % 360
    self.currentRotation = (self.currentRotation + 360) % 360
end

function Inspector:DisableActions()
    HideHudComponentThisFrame(19)
    DisableControlAction(1, 37)
    HudWeaponWheelIgnoreSelection()
    
    DisableControlAction(0, 1, true)
    DisableControlAction(0, 2, true)
    DisableControlAction(0,22, true)
    DisableControlAction(0,23, true)
    DisableControlAction(0,24, true)
    DisableControlAction(0,25, true)
    DisableControlAction(0,33, true)
    DisableControlAction(0,45, true)
    DisableControlAction(0,47, true)
    DisableControlAction(0,21,true)
    DisableControlAction(0,47,true)
    DisableControlAction(0,58,true)
    DisableControlAction(0,59,true)
    DisableControlAction(0,81,true)
    DisableControlAction(0,82,true)
    DisableControlAction(0,263,true)
    DisableControlAction(0,264,true)
    DisableControlAction(0,257,true)
    DisableControlAction(0,140,true)
    DisableControlAction(0,141,true)
    DisableControlAction(0,142,true)
    DisableControlAction(0,143,true)
    DisableControlAction(0,75,true)
    DisableControlAction(0,75,true)
end

function Inspector:SetButtons(view)
    local buttons = {
        { text = "Exit", key = 194 }
    }
    
    if self.hasValidEngineBay and view ~= 'engine' then
        table.insert(buttons, { text = "Engine View", key = 38 })
    end

    if view ~= 'wheel' then
        table.insert(buttons, { text = "Wheel View", key = 47 })
    end

    if view ~= 'side' then
        table.insert(buttons, { text = "Side View", key = 33 })
    end
    
    if view ~= 'rear' then
        table.insert(buttons, { text = "Rear View", key = 45 })
    end

    if view ~= 'cockpit' then
        table.insert(buttons, { text = "Cockpit View", key = 26 })
    end

    if view ~= 'front' then
        table.insert(buttons, { text = "Front View", key = 23 })
    end 

    if view == 'main' then
        table.insert(buttons, { text = "Zoom In", key = 14 })
        table.insert(buttons, { text = "Zoom Out", key = 15 })
        table.insert(buttons, { text = "Rotate",  key = 1 })
        table.insert(buttons, { text = "Toggle Revolve",  key = 22 })
    end

    table.insert(buttons, { text = "Toggle Engine",   key = 21 })

    return buttons
end

function Inspector:SetView(view)
    local coords    = vector3(0,0,0)
    local rotation  = vector3(0,0,0)
    local buttons   = {}

    if self.currentView ~= view and not self.transitioning then
        self.transitioning = true

        SetVehicleDoorShut(self.vehicle, 4, false)
        SetVehicleDoorShut(self.vehicle, 5, false)

        if view == 'main' then
            coords = vector3(self.spawnCoords.x, self.spawnCoords.y, self.spawnCoords.z + 1.0)
            coords = self:TranslateVector(coords, self.spawnHeading - 180, 4.00)
            rotation = vector3(-20.0, 0, self.spawnHeading - 180)     
        elseif view == 'front' then
            coords = self:GetFrontOfVehicle()
            rotation = vector3(0, 0, self.currentRotation - 180)
        elseif view == 'rear' then
            coords = self:GetRearOfVehicle()
            rotation = vector3(0, 0, self.currentRotation)          
        elseif view == 'side' then
            coords = self:GetSideOfVehicle()
            rotation = vector3(0, 0, self.currentRotation - 90)             
        elseif view == 'wheel' then
            coords = GetWorldPositionOfEntityBone(self.vehicle, GetEntityBoneIndexByName(self.vehicle, 'wheel_lf'))
            coords = self:TranslateVector(coords, self.currentRotation - 90, 1.00)
            rotation = vector3(0, 0, self.currentRotation - 90)           
        elseif view == 'cockpit' then       
            SetCursorLocation(0.5, 0.5)

            local player = PlayerPedId()
            coords = GetWorldPositionOfEntityBone(player, GetPedBoneIndex(player, 0x796E))
            rotation = vector3(0.0, 0, self.currentRotation)           
        elseif view == 'engine' and self.hasValidEngineBay then       
            coords = GetWorldPositionOfEntityBone(self.vehicle, GetEntityBoneIndexByName(self.vehicle, 'engine'))

            if self.isRearEngined then
                coords = self:TranslateVector(coords, self.currentRotation, 1.00)
                coords = coords + vector3(0, 0, 0.8)
                rotation = vector3(-35.0, 0, self.currentRotation)

                if self.isRearEngined == 'flipped' then
                    SetVehicleDoorOpen(self.vehicle, 4, false, false)
                else
                    SetVehicleDoorOpen(self.vehicle, 5, false, false)
                end
            else
                coords = self:TranslateVector(coords, self.currentRotation - 180, 1.00)
                coords = coords + vector3(0, 0, 0.8)
                rotation = vector3(-35.0, 0, self.currentRotation - 180)

                SetVehicleDoorOpen(self.vehicle, 4, false, false)
            end        
        end

        self.currentView = view

        if self.currentCam == nil then
            self.currentCam = self.cams.main

            SetCamCoord(self.currentCam, coords.x, coords.y, coords.z)
            SetCamRot(self.currentCam, rotation.x, rotation.y, rotation.z, 2)
            SetCamFov(self.currentCam, self.FOV * 1.0)
            SetCamActive(self.currentCam, true)
            RenderScriptCams(true, true, 1000, true, false)
            SetCamAffectsAiming(self.currentCam, false) 
        else
            -- SetCamParams(self.cams[view], coords.x, coords.y, coords.z, rotation.x, rotation.y, rotation.z, self.FOV * 1.0, 1000, 0, 0, 2)
            SetCamCoord(self.cams[view], coords.x, coords.y, coords.z)
            SetCamRot(self.cams[view], rotation.x, rotation.y, rotation.z, 2)
            SetCamFov(self.cams[view], self.FOV * 1.0)
            SetCamActiveWithInterp(self.cams[view], self.currentCam, 1000, 1, 1)

            Wait(1100)

            self.currentCam = self.cams[view]
        end


        -- if self.currentCam == nil then
        --     self.currentCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", coords, rotation, self.FOV * 1.0)

        --     SetCamActive(self.currentCam, true)

        --     RenderScriptCams(true, true, 1000, true, false)
    
        --     SetCamAffectsAiming(self.currentCam, false)
        -- else
        --     local currentCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", coords, rotation, self.FOV * 1.0)

        --     -- Animate cam position / rotation
        --     SetCamActiveWithInterp(currentCam, self.currentCam, 1000, 1, 1)

        --     -- Wait for cam to finish transitioning
        --     Wait(1100)

        --     -- There seems to be a limit of 25 cameras
        --     -- so lets destroy the previous one here otherwise subsequent cams won't work

        --     -- TODO: Create camera for each view when initialising instance instead of creating them here
        --     DestroyCam(self.currentCam, true)

        --     -- Set the current cam to the newly created one
        --     self.currentCam = currentCam
        -- end

        self.transitioning = false

        -- SetCamUseShallowDofMode(self.currentCam, true)
        -- SetCamFarDof(self.currentCam, 6.0)
        -- SetCamDofStrength(self.currentCam, 1.0)

        self:SetInstructionalButtons(self:SetButtons(view))  

        if self.callbacks.viewChange then
            self.callbacks.viewChange(view)
        end
    end
end

function Inspector:RotateTo(dest)
    self:SetVehicleRotation(self.spawnHeading - dest)
end

function Inspector:OnMouseDown()
    self.currentRotation = GetEntityRotation(self.vehicle).z
    self.lastRevolve = self.revolve
    self.revolve = false

    self:LimitRotation()
    
    Citizen.Wait(10)
    self.mouseDown = true
end

function Inspector:OnMouseUp()
    if self.lastRevolve then
        self.revolve = true
    end
    
    Citizen.Wait(10)
    self.mouseDown = false    
end

function Inspector:SetScreenSize()
    local w, h = GetActiveScreenResolution()

    self.screenWidth = w
    self.screenHeight = h
end

function Inspector:GetMousePosition()
    local x = GetDisabledControlNormal(2, 239)
    local y = GetDisabledControlNormal(2, 240)
    return self.screenWidth * x, self.screenHeight * y
end

function Inspector:GetFrontOfVehicle()
    local bounds = self:GetEntityBounds(self.vehicle)
    local topFront = self:GetCentreOfVectors(bounds[7], bounds[8])
    local bottomFront = self:GetCentreOfVectors(bounds[3], bounds[4])
    local center = self:GetCentreOfVectors(topFront, bottomFront)

    return self:TranslateVector(center, self.currentRotation, -1.25)
end

function Inspector:GetRearOfVehicle()
    local bounds = self:GetEntityBounds(self.vehicle)
    local topFront = self:GetCentreOfVectors(bounds[5], bounds[6])
    local bottomFront = self:GetCentreOfVectors(bounds[1], bounds[2])
    local center = self:GetCentreOfVectors(topFront, bottomFront)

    return self:TranslateVector(center, self.currentRotation, 1.25)
end

function Inspector:GetSideOfVehicle()
    local bounds = self:GetEntityBounds(self.vehicle)
    local topFront = self:GetCentreOfVectors(bounds[6], bounds[7])
    local bottomFront = self:GetCentreOfVectors(bounds[1], bounds[4])
    local center = self:GetCentreOfVectors(topFront, bottomFront)

    return self:TranslateVector(center, self.currentRotation - 90, 3.25)
end

function Inspector:GetEntityBounds(entity)
    local min, max = GetModelDimensions(GetEntityModel(entity))
    local pad = 0.00

    return {
        -- BOTTOM
        GetOffsetFromEntityInWorldCoords(entity, min.x - pad, min.y - pad, min.z - pad), -- REAR LEFT
        GetOffsetFromEntityInWorldCoords(entity, max.x + pad, min.y - pad, min.z - pad), -- REAR RIGHT
        GetOffsetFromEntityInWorldCoords(entity, max.x + pad, max.y + pad, min.z - pad), -- FRONT RIGHT
        GetOffsetFromEntityInWorldCoords(entity, min.x - pad, max.y + pad, min.z - pad), -- FRONT LEFT

        -- TOP
        GetOffsetFromEntityInWorldCoords(entity, min.x - pad, min.y - pad, max.z + pad), -- REAR RIGHT
        GetOffsetFromEntityInWorldCoords(entity, max.x + pad, min.y - pad, max.z + pad), -- REAR LEFT
        GetOffsetFromEntityInWorldCoords(entity, max.x + pad, max.y + pad, max.z + pad), -- FROM LEFT
        GetOffsetFromEntityInWorldCoords(entity, min.x - pad, max.y + pad, max.z + pad), -- FROM RIGHT
    }
end

function Inspector:TranslateVector(p, dir, dist)
    local angle = math.rad(dir - 90)
    local x = p.x + dist * math.cos(angle)
    local y = p.y + dist * math.sin(angle)
    return vector3(x, y, p.z)
end

function Inspector:GetCentreOfVectors(v1, v2)
    return vector3((v1.x+v2.x)/2.0,(v1.y+v2.y)/2.0,(v1.z+v2.z)/2.0)
end

function Inspector:SetButtonMessage(text)
    BeginTextCommandScaleformString("STRING")
    AddTextComponentScaleform(text)
    EndTextCommandScaleformString()
end

function Inspector:SetInstructionalButtons(data)

    if self.buttons then
        SetScaleformMovieAsNoLongerNeeded(self.buttons)
    end

    self.buttons = RequestScaleformMovie("instructional_buttons")

    while not HasScaleformMovieLoaded(self.buttons) do
        Citizen.Wait(0)
    end

    PushScaleformMovieFunction(self.buttons, "CLEAR_ALL")
    PopScaleformMovieFunctionVoid()
    
    PushScaleformMovieFunction(self.buttons, "SET_CLEAR_SPACE")
    PushScaleformMovieFunctionParameterInt(200)
    PopScaleformMovieFunctionVoid()

    local index = 0

    for _, btn in ipairs(data) do
        self:AddInstuctionalButton(btn.text, btn.key, index)

        index = index + 1
    end

    PushScaleformMovieFunction(self.buttons, "DRAW_INSTRUCTIONAL_BUTTONS")
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(self.buttons, "SET_BACKGROUND_COLOUR")
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(50)
    PopScaleformMovieFunctionVoid()
end

function Inspector:AddInstuctionalButton(text, key, index)
    PushScaleformMovieFunction(self.buttons, "SET_DATA_SLOT")
    PushScaleformMovieFunctionParameterInt(index)
    ScaleformMovieMethodAddParamPlayerNameString(GetControlInstructionalButton(2, key, true))
    self:SetButtonMessage(text)
    PopScaleformMovieFunctionVoid()
end

function Inspector:On(event, cb)
    -- Check event name is a string
    assert(type(event) == 'string', string.format("^1Invalid type for param: 'event' | Expected 'string', got %s ", type(event)))

    -- Check if event is already registered
    assert(self.callbacks[event] == nil, string.format("^1Event '%s' already registered", event))

    self.callbacks[event] = cb
end