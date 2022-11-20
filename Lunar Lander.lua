
Config = {
    Map = "gaetan.lunar_lander_map_v3",
	Items = {"gaetan.lunar_lander_v3",
             "gaetan.rocket_exhaust",
			 "gaetan.landing_pad_v2",
			 "gaetan.launch_pad_v2",
			 "gaetan.single_cube_grey"},
}

-- IDEAS
-- animate engine plume (scale/rotation)
-- put Player avatar in rocket
-- left/right modify the rotation speed (rotation acceleration), instead of setting its value

Client.OnStart = function()

    versionLabel = UI.Label("v3", Anchor.Top, Anchor.Left)

    -- reduce default gravity to 16%
    Config.ConstantAcceleration = Config.ConstantAcceleration * 0.16
    
    -- Constant values for the game
    const = {
        startPadPosition = Number3(6, 3, 6.5),
        endPadPosition = Number3(120, 3, 6.5),
		spawnPosition = Number3(30, 56, 32.5),
		spawnRotation = Number3(0, 0, 0),
		spawnVelocity = Number3(0, 0, 0),
		enginePower = 100,
		rotationSpeed = 100,
		landingSpeedLimit = 10.0,
        landingAngleLimit = math.pi / 8.0, -- 16th of 360° on each side (positive or negative rotation)
		fuelTime = 200, -- in 10ths of second
		scoreBaseTime = 60, -- in seconds (0.03 * const.enginePower)
        scoreTimeComponent = 1000, -- points
        scoreFuelComponent = 500, -- points
        -- Game states ---
        stateWaiting = "waiting", -- waiting for game to be started
        stateRunning = "running", -- game is running
        stateEnd = "end", -- either won or crashed
	}

    Clouds.On = false
    
    asEngine = AudioSource()
    asEngine.Sound = "wind_wind_child_1"
    asEngine.Spatialized = false
    World:AddChild(asEngine, true)
    
    asCrash = AudioSource()
    asCrash.Sound = "big_explosion_2"
    asCrash.Spatialized = false
    World:AddChild(asCrash, true)

	UI.Crosshair = false -- hide the crosshair
    Fog.On = false -- disable the distance fog

    -- disable the day/night cycle and set the ambiance
	TimeCycle.On = false
	Time.Current = Time.Noon
	TimeCycle.Marks.Noon.SkyColor = Color(0, 0, 0)
	TimeCycle.Marks.Noon.HorizonColor = Color(0, 0, 0)

    -- Create shapes

	-- start landing pad
	startPad = Shape(Items.gaetan.launch_pad_v2)
	Map:AddChild(startPad)
    
	-- landing pad
	endPad = Shape(Items.gaetan.landing_pad_v2)
	Map:AddChild(endPad)

	-- create ship
	ship = Shape(Items.gaetan.lunar_lander_v3)

	ship.Physics = true
	Map:AddChild(ship)
	ship.OnCollision = function(self, other)
		if ship.Velocity.Length > const.landingSpeedLimit or not isShipWithinAngleLimit(ship, const.landingAngleLimit) then
            s:endGame(false) -- failure

		elseif other == startPad then

		elseif other == endPad then
            s:endGame(true) -- success
			
		else -- hit the map
			s:endGame(false) -- failure
		end
	end

	-- create exhaust
	exhaust = Shape(Items.gaetan.rocket_exhaust)
	exhaust.CollisionGroups = {}
	exhaust.CollidesWithGroups = {}
	ship:AddChild(exhaust)
	exhaust.LocalPosition = Number3(0, -7, 0)
	exhaust.IsHidden = true

    exhaustLight = Light()
    exhaustLight.Radius = 70
    exhaustLight.Color = Color(1.0, 1.0, 0.5)
    exhaustLight:SetParent(exhaust)
    exhaustLight.LocalPosition = {0, 3, 0}

    -- create & init game state
	s = {}
    s.init = function()
        s.bestScore = 0
    end
    s.reset = function(self)
        s.state = const.stateWaiting
        s.stateEndSuccess = false
        s.engineOn = false
        s.rotation = 0
        s.time = 0
        s.fuel = const.fuelTime
        if s.timeLabel == nil then
            s.timeLabel = UI.Label("0 s", Anchor.Top, Anchor.HCenter)
        end
        if s.fuelLabel == nil then
            s.fuelLabel = UI.Label("", Anchor.Top, Anchor.HCenter)
        end
        if s.scoreLabel == nil then
            s.scoreLabel = UI.Label("", Anchor.Top, Anchor.HCenter)
        end
        s.fuelLabel.Text = "fuel: " .. math.floor(s.fuel)
        s.scoreLabel.Text = ""
        startPad.LocalPosition = const.startPadPosition
        endPad.LocalPosition = const.endPadPosition
        ship.IsHidden = false
        ship.Physics = true
        ship.Position = const.spawnPosition
        ship.Rotation = const.spawnRotation
        ship.Velocity = const.spawnVelocity
    end
    s.endGame = function(state, success)
        s.state = const.stateEnd
        s.stateEndSuccess = success
        s.fuel = 0
        if success then
            -- compute score
            -- time score
            local score = (const.scoreBaseTime - s.time) / const.scoreBaseTime * const.scoreTimeComponent
            -- fuel score
            score = score + (const.scoreFuelComponent * (s.fuel/const.fuelTime))
            score = math.floor(score) -- round it down
            s.scoreLabel.Text = "WIN! Score: " .. score .. " points"
            if score > s.bestScore then
                s.bestScore = score
                local e = Event()
                e.action = "didScore"
                e.score = score
                e:SendTo(Server)
            end
        else
            crash()
        end
        Pointer:Show()
    end
    s:init()
    s:reset()

    bestPlayerScore = UI.Label("My best: 0")
    bestWorldScore = UI.Label("World best: 0")

    retryButton = UI.Button("Retry!")
    retryButton.OnRelease = function()
        Pointer:Hide()
        s:reset()
    end

    -- Ping the server to notify it a player has arrived
    -- (This will be removed when "Server.OnPlayerJoin" callback will be working)
	local e = Event()
	e.action = "didStart"
	e:SendTo(Server)
end

Client.Tick = function(dt)
	-- Game loop, executed ~30 times per second on each client.

    if s.state == const.stateWaiting then

    elseif s.state == const.stateRunning then

        if ship.Position.X < -50 or ship.Position.Y > 240 or ship.Position.Y < -20 then
            s:endGame(false)
        end

        s.time = s.time + dt

    elseif s.state == const.stateEnd then

    end

    s.timeLabel.Text = string.format("%.2f", s.time) .. " s"

	if ship.IsHidden == false then
        Camera:SetModeSatellite(ship.Position, 300)
        Pointer:Show()
	end

	-- ship rotation
	if ship.IsOnGround == false then
		ship.Rotation.Z = ship.Rotation.Z -s.rotation * dt * const.rotationSpeed * 0.02
	end
	
	if s.engineOn and s.fuel > 0 then
        -- show engine exhaust plume
        exhaust.IsHidden = false
		ship.Velocity = ship.Velocity + (ship.Up * const.enginePower * dt)
		s.fuel = s.fuel - (dt * 10)
		if s.fuel < 0 then s.fuel = 0 end
		s.fuelLabel.Text = "fuel: " .. math.floor(s.fuel)
    else
		exhaust.IsHidden = true
	end
end

Client.DirectionalPad = function(x, y)
	-- x : left/right (-1 / 1)
	s.rotation = x
end

-- jump function, triggered with Action1
Client.Action1 = function()
    if s.state == const.stateWaiting then
        if ship.IsOnGround then
            s.state = const.stateRunning
            -- turn engine ON
            s.engineOn = true
            asEngine:Play()
        end

    elseif s.state == const.stateRunning then
        -- turn engine ON
        s.engineOn = true
        asEngine:Play()

    elseif s.state == const.stateEnd then
        if s.stateEndSuccess == false then
            -- restart game
            Pointer:Hide()
            s:reset()
        end
    end
end

Client.Action1Release = function()
    if s.state == const.stateRunning then
        -- engine OFF
	    s.engineOn = false
        asEngine:Stop()
    end
end

-- ship crash animation
crash = function()
	ship.IsHidden = true
	ship.Physics = false
	s.fuel = 0
    asCrash:Play() -- play crash sound
    for i = 1, 30 do
        local c = getParticle()
        World:AddChild(c)
        c.Scale = 5
        c.CollisionGroupsMask = 0 -- TODO: replace this
        c.CollidesWithMask = 0    -- TODO: replace this
        c.Position = ship.Position
        c.Physics = true
        c.Velocity.Y = (math.random() - 0.5) * 150
        c.Velocity.X = (math.random() - 0.5) * 150
        c.Velocity.Z = (math.random() - 0.5) * 150
    end
end

-- 
isShipWithinAngleLimit = function(ship, angleLimit)
	local rot = ship.Rotation.Z
	local lim = angleLimit	
	return (rot >= 0 and rot <= lim) or (rot >= (math.pi * 2 - lim) and rot <= math.pi * 2) 
end

Client.DidReceiveEvent = function(e)
    if e.action == "player_best" then
        -- print("received player best: " .. e.score)
        s.bestScore = e.score
        bestPlayerScore.Text = "My best: " .. s.bestScore

    elseif e.action == "world_best" then
        -- print("received world best: " .. e.score)
        bestWorldScore.Text = "World best: " .. e.score

    end
end

getParticle = function()
    if particles == nil then
        particles = {}
    end

    local p = table.remove(particles)
    if p == nil then
        p = Shape(Items.gaetan.single_cube_grey)
    end
    Timer(6.0, false, function()
        table.insert(particles, p)
        p:RemoveFromParent()
    end)

    return p
end

-- Pointer.Down = function(pointerEvent)
--     Dev:SetGameThumbnail()
-- end

-- --------------------------------------------------
--
-- Server code
--
-- --------------------------------------------------

-- called when the Server receives an event from a Client
Server.DidReceiveEvent = function(e)
    if e.action == "didStart" then
		-- print("DID START", e.Sender.Username, e.Sender.UserID)

		-- set player best score

	    local store = KeyValueStore(e.Sender.UserID)        
		local callback = function(success, results)
            -- print("DB GET success:", success)
            collectgarbage("collect")
            if success then
                local response = Event()
                response.action = "player_best"
                if results.bestScore == nil then
                    response.score = 0
                else
                    response.score = results.bestScore
                end
                response:SendTo(e.Sender) 
            end
		end
		store:Get("bestScore", callback)

        -- send world best score
        local store = KeyValueStore("global")        
		local callback = function(success, results)
            collectgarbage("collect")
            if success then    
                local response = Event()
                response.action = "world_best"
                if results.bestScore == nil then
                    response.score = 0
                else
                    response.score = results.bestScore
                end                
                response:SendTo(e.Sender)
            end
		end
		store:Get("bestScore", callback)

    elseif e.action == "didScore" then
        -- save score in DB
        local store = KeyValueStore(e.Sender.UserID)
        store:Set("bestScore", e.score, function(success)
            if success then
                local response = Event()
                response.action = "player_best"
                response.score = e.score
                response:SendTo(e.Sender)
            end
        end)

        -- get/set world best score
        local store = KeyValueStore("global")
		local callback = function(success, results)
            collectgarbage("collect")
            if success then
                if results.bestScore == nil or results.bestScore < e.score then
                    -- save world best score
                    local store2 = KeyValueStore("global")
                    store2:Set("bestScore", e.score, function(success2)
                        if success2 then
                            local response2 = Event()
                            response2.action = "world_best"
                            response2.score = e.score
                            response2:SendTo(e.Sender)
                        end
                    end)
                end
            end
		end
		store:Get("bestScore", callback)
	end
end

-- Server game loop, executed ~30 times per second on the Server

Server.Tick = function(dt) 

end