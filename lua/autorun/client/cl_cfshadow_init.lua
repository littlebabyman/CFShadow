local enabled = CreateClientConVar("cl_firstperson_shadow", 1, true, false, "", 0, 1)
local playerShadow, weaponShadow = nil, nil

local function DestroyShadows()
	if IsValid(playerShadow) then
		playerShadow:Remove()
	end

	if IsValid(weaponShadow) then
		weaponShadow:Remove()
	end
end

local function MakeShadows()
	DestroyShadows()
	RunConsoleCommand("cl_drawownshadow", "0")

	local client = LocalPlayer()

	if !IsValid(client) then
		return
	end

	local plyModel = client:GetModel()
	playerShadow = ents.CreateClientside("cfshadow_shadow_player")
	playerShadow:SetModel(plyModel)
	playerShadow:SetParent(client)
	playerShadow:Spawn()

	weaponShadow = ents.CreateClientside("cfshadow_shadow_weapon")
	weaponShadow:SetModel(plyModel)
	weaponShadow:SetParent(playerShadow)
	weaponShadow:Spawn()
end

hook.Add("InitPostEntity", "CFShadow.Init", function()
	-- We need to wait for a valid playermodel to be set.
	timer.Simple(1.0, function()
		if !enabled:GetBool() then
			return
		end

		MakeShadows()
	end)
end)

cvars.AddChangeCallback("cl_firstperson_shadow", function(convar, old, new)
	if old == new then
		return
	end

	local bool = new == "1" and true or false

	if bool then
		MakeShadows()
	else
		DestroyShadows()
	end
end)