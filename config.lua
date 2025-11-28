Config = {}

-- Command Names
Config.Commands = {
    Toggle = "veh_bounce",    -- Command to start/stop bouncing
    Whitelist = "bouncewl"    -- Command to add/remove plate from whitelist
}

-- List of CitizenIDs allowed to use the Whitelist command
-- These players can use /bouncewl [plate]
Config.AuthorizedCIDs = {
    "QA123456", -- Example CitizenID
    "AB000000",
}

-- Bounce Physics Settings
Config.Radius = 50.0
Config.BounceAmplitude = 0.08 -- How high it bounces
Config.BounceSpeed = 1.5      -- Frequency of the sine wave (speed)

-- Vehicle Classes that are allowed to bounce
-- 0: Compacts, 1: Sedans, 2: SUVs, 3: Coupes, 4: Muscle, 5: Sports, 6: Classics, 7: Super
Config.AllowedClasses = { 0, 1, 2, 3, 4, 5, 6, 7 }

-- Toggle affecting nearby vehicles (true = sync bouncing with nearby cars, false = only own car)
Config.AffectVehiclesInRange = true
