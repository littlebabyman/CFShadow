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

    -- MsgC(color_white, "[", Color(200, 0, 0), "CFShadow", color_white, "] - Firstperson player shadow's player validity check passed!", "\n")

    self:SetAutomaticFrameAdvance(true)
    self:SetMoveType(MOVETYPE_NONE)
    self:DrawShadow(true)
    self:SetRenderMode(RENDERMODE_NORMAL)
    self:SetMaterial("engine/occlusionproxy")
end

local ENTITY = FindMetaTable("Entity")
local PLAYER = FindMetaTable("Player")
local eGetModelScale, eSetModelScale = ENTITY.GetModelScale, ENTITY.SetModelScale
local eGetPos, eSetPos = ENTITY.GetPos, ENTITY.SetPos
local eGetAngles, eSetAngles = ENTITY.GetAngles, ENTITY.SetAngles
local eGetSequence, eSetSequence = ENTITY.GetSequence, ENTITY.SetSequence
local eGetCycle, eSetCycle = ENTITY.GetCycle, ENTITY.SetCycle
local eGetNumPoseParameters = ENTITY.GetNumPoseParameters
local eGetPoseParameterRange = ENTITY.GetPoseParameterRange
local eGetPoseParameter, eSetPoseParameter = ENTITY.GetPoseParameter, ENTITY.SetPoseParameter
local eInvalidateBoneCache = ENTITY.InvalidateBoneCache
local eGetNumBodyGroups = ENTITY.GetNumBodyGroups
local eGetBodygroup, eSetBodygroup = ENTITY.GetBodygroup, ENTITY.SetBodygroup
local eSetNextClientThink = ENTITY.SetNextClientThink
local aCurTime = CurTime
local haveLayeredSequencesBeenFixed = false
local lastBodygroupApply = 0

function ENT:Think()
    eSetModelScale(self, eGetModelScale(ply))
    eSetPos(self, eGetPos(ply))
    eSetAngles(self, eGetAngles(ply))
    eSetSequence(self, eGetSequence(ply))

    -- ISSUE: https://github.com/Facepunch/garrysmod-requests/issues/1723
    if haveLayeredSequencesBeenFixed then
        self:CopyLayerSequenceInfo(0, ply)
        self:CopyLayerSequenceInfo(1, ply)
        self:CopyLayerSequenceInfo(2, ply)
        self:CopyLayerSequenceInfo(3, ply)
        self:CopyLayerSequenceInfo(4, ply)
        self:CopyLayerSequenceInfo(5, ply)
    end

    eSetCycle(self, eGetCycle(ply))

    for i = 0, eGetNumPoseParameters(ply) - 1 do
        local min, max = eGetPoseParameterRange(ply, i)

        eSetPoseParameter(self, i, math.Remap(eGetPoseParameter(ply, i), 0, 1, min, max))
    end

    eInvalidateBoneCache(self)

    local curTime = aCurTime()

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

function ENT:CopyLayerSequenceInfo(layer, fromEnt)
    self:SetLayerSequence(layer, fromEnt:GetLayerSequence(layer))
    self:SetLayerDuration(layer, fromEnt:GetLayerDuration(layer))
    self:SetLayerPlaybackRate(layer, fromEnt:GetLayerPlaybackRate(layer))
    self:SetLayerWeight(layer, fromEnt:GetLayerWeight(layer))
    self:SetLayerCycle(layer, fromEnt:GetLayerCycle(layer))
end

local eDestroyShadow = ENTITY.DestroyShadow
local pAlive = PLAYER.Alive
local pShouldDrawLocalPlayer = PLAYER.ShouldDrawLocalPlayer
local pFlashlightIsOn = PLAYER.FlashlightIsOn
local rGetName = FindMetaTable("ITexture").GetName
local sLower = string.lower
local eGetModel = ENTITY.GetModel
local eSetModel = ENTITY.SetModel
local eDrawModel = ENTITY.DrawModel
local eCreateShadow = ENTITY.CreateShadow
local waterRT = "_rt_waterreflection"

function ENT:Draw()
    eDestroyShadow(self)

    -- COMMENT
    if !aIsValid(ply) or !pAlive(ply) then
        return
    end

    -- COMMENT
    if pShouldDrawLocalPlayer(ply) then
        return
    end

    -- COMMENT
    if pFlashlightIsOn(ply) then
        return
    end

    local rt = render.GetRenderTarget()

    -- WORKAROUND: https://github.com/Facepunch/garrysmod-requests/issues/1943#issuecomment-1039511256
    if rt then
        local rtName = sLower(rGetName(rt))

        if rtName == waterRT then
            return
        end
    end

    local plyModel = eGetModel(ply)

    if eGetModel(self) != plyModel then
        eSetModel(self, plyModel)
    end

    -- self:SetMaterial("editor/wireframe")

    -- self:DrawModel()

    -- self:SetMaterial("engine/occlusionproxy")

    eDrawModel(self)

    -- FIXME: Why do we have to do this manually?
    eCreateShadow(self)
end

function ENT:OnReloaded()
    self:Remove()
end