AddCSLuaFile()

ENT.Type            = "anim"
ENT.PrintName       = "CFShadow Player Shadow"
ENT.Author          = "afxnatic"
ENT.Information     = "ez optimized firstperson shadows"
ENT.Category        = "chicagoRP"

ENT.Spawnable       = false
ENT.AdminSpawnable  = false

local ply = nil

function ENT:Initialize()
    MsgC(color_white, "[", Color(200, 0, 0), "CFShadow", color_white, "] - Firstperson player shadow created!", "\n")

    ply = LocalPlayer()

    if !IsValid(ply) then
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

function ENT:CopyLayerSequenceInfo(layer, fromEnt)
    self:SetLayerSequence(layer, fromEnt:GetLayerSequence(layer))
    self:SetLayerDuration(layer, fromEnt:GetLayerDuration(layer))
    self:SetLayerPlaybackRate(layer, fromEnt:GetLayerPlaybackRate(layer))
    self:SetLayerWeight(layer, fromEnt:GetLayerWeight(layer))
    self:SetLayerCycle(layer, fromEnt:GetLayerCycle(layer))
end

local haveLayeredSequencesBeenFixed = false
local lastBodygroupApply = 0

function ENT:Think()
    self:SetModelScale(ply:GetModelScale())
    self:SetPos(ply:GetPos())
    self:SetAngles(ply:GetRenderAngles())
    self:SetSequence(ply:GetSequence())

    -- ISSUE: https://github.com/Facepunch/garrysmod-requests/issues/1723
    if haveLayeredSequencesBeenFixed then
        self:CopyLayerSequenceInfo(0, ply)
        self:CopyLayerSequenceInfo(1, ply)
        self:CopyLayerSequenceInfo(2, ply)
        self:CopyLayerSequenceInfo(3, ply)
        self:CopyLayerSequenceInfo(4, ply)
        self:CopyLayerSequenceInfo(5, ply)
    end

    self:SetCycle(ply:GetCycle())

    for i = 0, ply:GetNumPoseParameters() - 1 do
        local min, max = ply:GetPoseParameterRange(i)

        self:SetPoseParameter(i, math.Remap(ply:GetPoseParameter(i), 0, 1, min, max))
    end

    self:InvalidateBoneCache()

    local curTime = CurTime()

    if lastBodygroupApply + 1.0 < curTime then
        for i = 1, ply:GetNumBodyGroups() do
            self:SetBodygroup(i, ply:GetBodygroup(i))
        end

        lastBodygroupApply = curTime
    end

    -- Set the next think to run as soon as possible, i.e. the next frame.
    self:NextThink(curTime)

    -- Apply NextThink call
    return true
end

local waterRT = "_rt_waterreflection"

function ENT:Draw()
    self:DestroyShadow()

    -- COMMENT
    if !IsValid(ply) or !ply:Alive() then
        return
    end

    -- COMMENT
    if ply:ShouldDrawLocalPlayer() then
        return
    end

    -- COMMENT
    if ply:FlashlightIsOn() then
        return
    end

    local rt = render.GetRenderTarget()

    -- WORKAROUND: https://github.com/Facepunch/garrysmod-requests/issues/1943#issuecomment-1039511256
    if rt then
        local rtName = string.lower(rt:GetName())

        if rtName == waterRT then
            return
        end
    end

    local plyModel = ply:GetModel()

    if self:GetModel() != plyModel then
        self:SetModel(plyModel)
    end

    -- self:SetMaterial("editor/wireframe")

    -- self:DrawModel()

    -- self:SetMaterial("engine/occlusionproxy")

    self:DrawModel()

    -- FIXME: Why do we have to do this manually?
    self:CreateShadow()
end

function ENT:OnReloaded()
    self:Remove()
end