AddCSLuaFile()

ENT.Type            = "anim"
ENT.PrintName       = "CFShadow Player Shadow"
ENT.Author          = "afxnatic"
ENT.Information     = "ez optimized firstperson shadows"
ENT.Category        = "chicagoRP"

ENT.Spawnable       = false
ENT.AdminSpawnable  = false

local aIsValid = IsValid
local ply = nil

function ENT:Initialize()
    MsgC(color_white, "[", Color(200, 0, 0), "CFShadow", color_white, "] - Firstperson player shadow created!", "\n")

    ply = LocalPlayer()

    if !aIsValid(ply) then
        self:Remove()

        return
    end

    self:DrawShadow(true)
    self:SetAutomaticFrameAdvance(true)
    self:SetRenderMode(RENDERMODE_NORMAL)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetMaterial("engine/occlusionproxy")
end

local ENTITY = FindMetaTable("Entity")
local PLAYER = FindMetaTable("Player")
local eGetModel, eSetModel = ENTITY.GetModel, ENTITY.SetModel
local eGetModelScale, eSetModelScale = ENTITY.GetModelScale, ENTITY.SetModelScale
local eGetTable = ENTITY.GetTable
local eGetPos, eSetPos = ENTITY.GetPos, ENTITY.SetPos
local eGetAngles, eSetAngles = ENTITY.GetAngles, ENTITY.SetAngles
local eGetSequence, eSetSequence = ENTITY.GetSequence, ENTITY.SetSequence
local eGetCycle, eSetCycle = ENTITY.GetCycle, ENTITY.SetCycle
local eGetNumPoseParameters = ENTITY.GetNumPoseParameters
local eGetPoseParameterName = ENTITY.GetPoseParameterName
local eGetPoseParameterRange = ENTITY.GetPoseParameterRange
local eGetPoseParameter, eSetPoseParameter = ENTITY.GetPoseParameter, ENTITY.SetPoseParameter
local eInvalidateBoneCache = ENTITY.InvalidateBoneCache
local eGetNumBodyGroups = ENTITY.GetNumBodyGroups
local eGetBodygroup, eSetBodygroup = ENTITY.GetBodygroup, ENTITY.SetBodygroup
local eSetNextClientThink = ENTITY.SetNextClientThink
local poseParameterBlacklist = {
    ["aim_yaw"] = true
}
local haveLayeredSequencesBeenFixed = false
local lastBodygroupApply = 0
local lastModelScale = nil

function ENT:Think()
    local plyModel = eGetModel(ply)
    local ourModel = eGetModel(self)

    if ourModel != plyModel then
        eSetModel(self, plyModel)

        eInvalidateBoneCache(self)
    end

    local curModelScale = eGetModelScale(ply)

    if curModelScale != lastModelScale then
        eSetModelScale(self, curModelScale)
    end

    local plyPos = eGetPos(ply)
    local pos = plyPos
    local legs = eGetTable(ply).LegEnt

    if IsValid(legs) then
        local legsTable = eGetTable(legs)

        if legsTable.DidDraw then
            pos = legsTable.RenderPos
            pos.z = plyPos.z
        end
    end

    eSetPos(self, pos)

    local ang = eGetAngles(ply)
    ang.p = 0
    ang.r = 0

    eSetAngles(self, ang)
    eSetSequence(self, eGetSequence(ply))

    -- ISSUE: https://github.com/Facepunch/garrysmod-requests/issues/1723
    if haveLayeredSequencesBeenFixed then
        self:CopyLayerSequence(0, ply)
        self:CopyLayerSequence(1, ply)
        self:CopyLayerSequence(2, ply)
        self:CopyLayerSequence(3, ply)
        self:CopyLayerSequence(4, ply)
        self:CopyLayerSequence(5, ply)
    end

    eSetCycle(self, eGetCycle(ply))

    for i = 0, eGetNumPoseParameters(ply) - 1 do
        local name = eGetPoseParameterName(ply, i)

        if poseParameterBlacklist[name] then
            continue
        end

        local min, max = eGetPoseParameterRange(ply, i)

        eSetPoseParameter(self, i, math.Remap(eGetPoseParameter(ply, i), 0, 1, min, max))
    end

    if curModelScale != lastModelScale then
        eInvalidateBoneCache(self)
    end

    lastModelScale = curModelScale

    local curTime = CurTime()

    if lastBodygroupApply + 1.0 < curTime then
        for i = 1, eGetNumBodyGroups(ply) do
            eSetBodygroup(self, i, eGetBodygroup(ply, i))
        end

        lastBodygroupApply = curTime
    end

    -- Set the next think to run as soon as possible, i.e. the next frame.
    eSetNextClientThink(self, curTime)

    -- Apply NextThink call
    return true
end

function ENT:CopyLayerSequence(layer, fromEnt)
    self:SetLayerSequence(layer, fromEnt:GetLayerSequence(layer))
    self:SetLayerDuration(layer, fromEnt:GetLayerDuration(layer))
    self:SetLayerPlaybackRate(layer, fromEnt:GetLayerPlaybackRate(layer))
    self:SetLayerWeight(layer, fromEnt:GetLayerWeight(layer))
    self:SetLayerCycle(layer, fromEnt:GetLayerCycle(layer))
end

local eDestroyShadow = ENTITY.DestroyShadow
local pAlive = PLAYER.Alive
local pInVehicle = PLAYER.InVehicle
local pShouldDrawLocalPlayer = PLAYER.ShouldDrawLocalPlayer
local pFlashlightIsOn = PLAYER.FlashlightIsOn
local pGetObserverMode = PLAYER.GetObserverMode
local rGetName = FindMetaTable("ITexture").GetName
local sLower = string.lower
local eDrawModel = ENTITY.DrawModel
local eCreateShadow = ENTITY.CreateShadow
local waterRT = {
    _rt_waterreflection = true,
    _rt_waterrefraction = true
}

function ENT:Draw()
    eDestroyShadow(self)

    -- COMMENT
    if !aIsValid(ply) or !pAlive(ply) then
        return
    end

    -- COMMENT
    if pInVehicle(ply) or pShouldDrawLocalPlayer(ply) then
        return
    end

    -- COMMENT
    if pFlashlightIsOn(ply) or pGetObserverMode(ply) != OBS_MODE_NONE then
        return
    end

    local rt = render.GetRenderTarget()

    -- WORKAROUND: https://github.com/Facepunch/garrysmod-requests/issues/1943#issuecomment-1039511256
    if rt then
        local rtName = sLower(rGetName(rt))

        if waterRT[rtName] then
            return
        end
    end

    eDrawModel(self)
    eCreateShadow(self)
end

function ENT:OnReloaded()
    ply = LocalPlayer()
end