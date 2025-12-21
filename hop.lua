if not game:IsLoaded() then game.Loaded:Wait() end
repeat task.wait() until game:GetService("Players").LocalPlayer

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Player = Players.LocalPlayer

local SCAN_DURATION = 2
local SCAN_INTERVAL = 0.1
local MAX_HOP_ATTEMPTS = 99999
local API_URL_ADD = "https://webhooks-api-production-0ca4.up.railway.app/add-server"
local API_URL_GET = "http://78.109.16.22:8081/next_id"
local BEARER_TOKEN = "atlas_publish_key_z8237498dz7a42caa9fdb391z"
local PLACE_ID = game.PlaceId

local function log(level, msg)
    print(string.format("[%s][%s] %s", os.date("%H:%M:%S"), string.upper(level), msg))
end

local function parseGeneration(genStr)
    if not genStr then return 0 end
    genStr = string.gsub(genStr, "[%$,/s]", "")
    genStr = string.upper(genStr)
    local number, suffix = string.match(genStr, "([%d%.]+)([KMB]?)")
    number = tonumber(number) or 0
    if suffix=="K" then number*=1e3
    elseif suffix=="M" then number*=1e6
    elseif suffix=="B" then number*=1e9 end
    return number / 1e6
end

local function determineTier(value)
    if value >= 1 and value < 10 then return "1-9.9"
    elseif value >= 10 and value < 50 then return "10-49.9"
    elseif value >= 50 and value < 100 then return "50-99.9"
    elseif value >= 100 and value < 400 then return "100-399.9"
    elseif value >= 400 and value < 1000 then return "400-999.9"
    elseif value >= 1000 then return "1b+"
    else return nil end
end

local function SendToAPI(data)
    local req = http_request or request or (syn and syn.request) or (fluxus and fluxus.request)
    if not req then return end
    local body = HttpService:JSONEncode(data)
    req({
        Url = API_URL_ADD,
        Method = "POST",
        Headers = { ["Content-Type"]="application/json" },
        Body = body
    })
    print("[SCANNER] Enviado a API con "..#data.brainrots.." brainrots y "..data.players.." players")
end

local function scanPlots()
    log("info","ðŸ” Escaneando Debris...")
    local startTime = tick()
    local sent = {}
    local allBrainrots = {}

    while tick()-startTime < SCAN_DURATION do
        local debris = Workspace:FindFirstChild("Debris")
        if debris then
            for _, obj in ipairs(debris:GetDescendants()) do
                if obj:IsA("TextLabel") and obj.Name == "Generation" then
                    local gen = obj.Text ~= "" and obj.Text or obj.ContentText
                    if gen and gen:find("/s") then
                        local gui = obj.Parent
                        local displayName = gui and gui:FindFirstChild("DisplayName")
                        local name = displayName and (displayName.Text ~= "" and displayName.Text or displayName.ContentText) or "Unknown"
                        
                        local key = name.."_"..gen
                        if not sent[key] then
                            sent[key] = true
                            local value = parseGeneration(gen)
                            local tier = determineTier(value)
                            if tier then
                                table.insert(allBrainrots, {tier=tier, name=name, gen=gen, value=value})
                            end
                        end
                    end
                end
            end
        end
        task.wait(SCAN_INTERVAL)
    end

    if #allBrainrots > 0 then
        SendToAPI({
            jobId = game.JobId,
            players = #Players:GetPlayers(),
            brainrots = allBrainrots,
            timestamp = os.time()
        })
    else
        log("info","âš ï¸ No se detectaron brainrots que enviar")
    end
end

local attempt = 0
local function GetJobId()
    local req = http_request or request or (syn and syn.request) or (fluxus and fluxus.request)
    if not req then 
        log("error","âŒ No hay funciÃ³n request disponible")
        return nil 
    end
    
    local ok, resp = pcall(function()
        return req({
            Url = API_URL_GET,
            Method = "GET",
            Headers = {
                ["Authorization"] = "Bearer " .. BEARER_TOKEN
            }
        })
    end)
    
    if not ok then
        log("error","âŒ Error en peticiÃ³n: "..tostring(resp))
        return nil
    end
    
    if resp and resp.Body then
        local jobId = resp.Body:match("^%s*(.-)%s*$")
        if jobId and jobId ~= "" then
            log("info","âœ… JobID obtenido: "..jobId)
            return jobId
        end
    end
    
    log("error","âŒ Respuesta vacÃ­a o invÃ¡lida")
    return nil
end

local function Teleport_To_Server()
    attempt += 1
    if attempt > MAX_HOP_ATTEMPTS then
        log("error","âŒ MÃ¡ximo de intentos de server hop alcanzado.")
        return
    end
    log("info","ðŸŒ Buscando nuevo servidor... (Intento "..attempt..")")
    local jobId = GetJobId()
    if jobId then
        log("info","ðŸš€ Teletransportando al JobID: "..jobId)
        local ok, err = pcall(function()
            TeleportService:TeleportToPlaceInstance(PLACE_ID, jobId, Player)
        end)
        if not ok then
            warn("[Error Teleport]: "..tostring(err))
            task.wait(0.6)
            Teleport_To_Server()
        end
    else
        warn("âŒ No se pudo obtener JobID, reintentando...")
        task.wait(0.5)
        Teleport_To_Server()
    end
end

TeleportService.TeleportInitFailed:Connect(function()
    warn("âš ï¸ Teleport fallido, reintentando...")
    task.wait(0.3)
    Teleport_To_Server()
end)

local function main()
    log("info","Almost ready...")
    task.wait(0)
    scanPlots()
    log("info","Done...")
    Teleport_To_Server()
end

main()




local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local EventController = ReplicatedStorage:WaitForChild("Controllers").EventController.Events
for _, child in EventController:GetChildren() do
    child:Destroy()
end
local EVENT_PATTERNS = {
    "1x1x1x1Map", "3RoadsMap", "4thOfJulyVFX", "BombardiroPlane", "BrazilHitbox", 
    "RadioactiveMap", "YinYangMap", "BloodmoonVFX", "CandyMap", "ExtinctMap", 
    "CrabRaveStage", "GlitchVFX", "RainbowVFX", "MoltenVFX", "SolarFlareVFX", 
    "FuseMachine", "LaVaccaModel", "MatteoVFX", "NyanCatModel", "RainingTacoVFX",
    "RainWeather", "StarfallVFX", "SnowWeather", "ConcertStage", "ConcertMap",
    "EventPlane", "EventVFX", "EventStage", "EventMap", "EventExplosion",
    "CrabFolder", "MeteorVFX", "CometVFX", "FireworkVFX", "DiscoProjectile",
    "SummonVFX", "WindParts", "SmokeStage", "EventRig", "SanddrumRoll",
    "EventHole", "EventCrater", "SnowPile", "BubblegumMachine"
}

local EVENT_TAGS = {
    "BrazilHitbox", "BombardiroPlane", "1x1x1x1Map", "BubblegumMachine",
    "MapVFX", "HideInBrazil", "HideInYinYang", "HideInRadioactive",
    "HideIn1x1x1x1", "HideIn3Roads", "BombardiroCrocodiloPlayerVFX",
    "1x1x1x1PlayerVFX", "ShowIn3Roads", "HideInConcert", "HideInExtinct",
    "CrabRaveCrabFolder", "CrabRaveCrabs", "RainbowEventAttachment",
    "LaVaccaModel", "LaVaccaPlayerVFX", "SnowPile", "BubbleGumProgress",
    "RainbowModel", "HideInCandy", "HideInMolten", "HideInSnow",
    "HideInRain", "HideInStarfall", "NyanCatModel"
}

local function shouldRemoveObject(instance)
    local name = instance.Name

    for _, pattern in EVENT_PATTERNS do
        if name == pattern or name:match("^" .. pattern .. "%d*$") then
            return true
        end
    end

    for _, tag in EVENT_TAGS do
        if CollectionService:HasTag(instance, tag) then
            return true
        end
    end

    if instance:FindFirstAncestor("Events") then
        return true
    end

    return false
end

local function disableVFXModule()
    local success, vfxModule = pcall(function()
        return require(ReplicatedStorage.Shared.VFX)
    end)

    if success and vfxModule then
        vfxModule.emit = function() end
        vfxModule.enable = function() end
        vfxModule.disable = function() end
        print("✓ VFX module disabled")
    end
end

local function disableEffectController()
    local success, effectController = pcall(function()
        return require(ReplicatedStorage.Controllers.EffectController)
    end)

    if success and effectController then
        effectController.Activate = function() end
        effectController.Run = function() end
        effectController.Stop = function() end
        print("✓ EffectController disabled")
    end
end

local function processVFX(instance)
    if instance:IsA("ParticleEmitter") then
        instance.Enabled = false
        instance.Rate = 0
    elseif instance:IsA("Beam") then
        instance.Enabled = false
        instance.Transparency = NumberSequence.new(1)
    elseif instance:IsA("PointLight") or instance:IsA("SpotLight") or instance:IsA("SurfaceLight") then
        instance.Enabled = false
        instance.Brightness = 0
    elseif instance:IsA("Fire") or instance:IsA("Smoke") or instance:IsA("Sparkles") then
        instance.Enabled = false
    elseif instance:IsA("Sound") and instance:FindFirstAncestor("Events") then
        instance.Volume = 0
    end
end

local function cleanWorkspace()
    print("Cleaning workspace...")
    local removed = 0

    workspace.DescendantAdded:Connect(function(descendant)
        if shouldRemoveObject(descendant) then
            descendant:Destroy()
            removed = removed + 1
        else

            processVFX(descendant)
        end
    end)

    for _, descendant in workspace:GetDescendants() do
        if shouldRemoveObject(descendant) then
            descendant:Destroy()
            removed = removed + 1
        else
            processVFX(descendant)
        end
    end

    print("✓ Workspace cleaned (" .. removed .. " objects removed)")
end

local function lockLighting()
    print("Locking lighting...")

    local originalAmbient = Lighting.Ambient
    local originalOutdoorAmbient = Lighting.OutdoorAmbient
    local originalBrightness = Lighting.Brightness
    local originalClockTime = Lighting.ClockTime

    Lighting.ChildAdded:Connect(function(child)
        if child:IsA("Atmosphere") or 
           child:IsA("Sky") or 
           child:IsA("ColorCorrectionEffect") or
           child:IsA("BloomEffect") or
           child:IsA("BlurEffect") then
            child:Destroy()
        end
    end)

    Lighting:GetPropertyChangedSignal("Ambient"):Connect(function()
        Lighting.Ambient = originalAmbient
    end)

    Lighting:GetPropertyChangedSignal("OutdoorAmbient"):Connect(function()
        Lighting.OutdoorAmbient = originalOutdoorAmbient
    end)

    Lighting:GetPropertyChangedSignal("Brightness"):Connect(function()
        Lighting.Brightness = originalBrightness
    end)

    Lighting:GetPropertyChangedSignal("ClockTime"):Connect(function()
        Lighting.ClockTime = originalClockTime
    end)

    for _, child in Lighting:GetChildren() do
        if child:IsA("Atmosphere") or 
           child:IsA("Sky") or 
           child:IsA("ColorCorrectionEffect") or
           child:IsA("BloomEffect") or
           child:IsA("BlurEffect") then
            child:Destroy()
        end
    end

    print("✓ Lighting locked")
end

local function initialize()
    print("\nInitializing all systems...")

    disableVFXModule()
    disableEffectController()
    lockLighting()
    cleanWorkspace()

    print("\n=================================")
    print("✓ ALL EVENT VFX REMOVED")
    print("✓ Zero FPS impact")
    print("=================================")
end

if game:IsLoaded() then
    initialize()
else
    game.Loaded:Wait()
    initialize()
end

return {
    Version = "2.2",
    Description = "Ultimate VFX Remover - Optimized",
    EventsSupported = 25
}


