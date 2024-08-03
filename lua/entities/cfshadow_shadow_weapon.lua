AddCSLuaFile()

ENT.Type            = "anim"
ENT.PrintName       = "CFShadow Weapon Shadow"
ENT.Author          = "afxnatic"
ENT.Information     = "ez optimized firstperson shadows"
ENT.Category        = "chicagoRP"

ENT.Spawnable       = false
ENT.AdminSpawnable  = false

local ply = nil

function ENT:Initialize()
    MsgC(color_white, "[", Color(200, 0, 0), "CFShadow", color_white, "] - Firstperson weapon shadow created!", "\n")

    ply = LocalPlayer()

    if !IsValid(ply) then
        self:Remove()

        return
    end

    -- MsgC(color_white, "[", Color(200, 0, 0), "CFShadow", color_white, "] - Firstperson weapon shadow's player validity check passed!", "\n")

    self:SetAutomaticFrameAdvance(true)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetRenderMode(RENDERMODE_NORMAL)
    self:SetMaterial("engine/occlusionproxy")
    self:DrawShadow(true)
end

local lastBodygroupApply = 0

function ENT:Think()
    local curTime = CurTime()

    if lastBodygroupApply + 1.0 < curTime then
        local wep = ply:GetActiveWeapon()

        if IsValid(wep) and wep:IsValid() then
            for i = 1, wep:GetNumBodyGroups() do
                self:SetBodygroup(i, wep:GetBodygroup(i))
            end
        end

        lastBodygroupApply = curTime
    end

    -- Set the next think to run as soon as possible, i.e. the next frame.
    self:NextThink(curTime)

    -- Apply NextThink call
    return true
end

local arc9Ang = Angle(-5, 0, 180)

local getOffsetFuncs = {
    ["arc9_base"] = function(wep)
        local wmOffsets = wep.WorldModelOffset
        local shouldTPIK = wep:ShouldTPIK()

        return shouldTPIK and wmOffsets.TPIKPos or wmOffsets.Pos, shouldTPIK and wmOffsets.TPIKAng or wmOffsets.Ang or arc9Ang, wmOffsets.Scale
    end,
    ["arccw_base"] = function(wep)
        local wmOffsets = wep.WorldModelOffset

        if !wmOffsets then return end

        local bonename = wmOffsets.bone or "ValveBiped.Bip01_R_Hand"
        local apos, aang = nil, nil

        if bonename then
            local boneID = ply:LookupBone(bonename)

            if !boneID then
                return
            end

            apos, aang = ply:GetBonePosition(boneID)
        else
            apos, aang = Vector(0, 0, 0), Angle(0, 0, 0)
        end

        local offsetPos = wmOffsets.pos or Vector(0, 0, 0)
        local offsetAng = wmOffsets.ang or angle_zero
        local scale = wmOffsets.scale or 1

        offsetPos:Mul(scale)

        apos:Add(bang:Forward() * offsetPos.x)
        apos:Add(bang:Right() * offsetPos.y)
        apos:Add(bang:Up() * offsetPos.z)

        aang:RotateAroundAxis(aang:Right(), offsetAng.p)
        aang:RotateAroundAxis(aang:Up(), offsetAng.y)
        aang:RotateAroundAxis(aang:Forward(), offsetAng.r)

        if !apos or !aang then return end

        return apos, aang, scale

        -- local bone = ply:LookupBone(wmOffsets.bone)

        -- if !bone then return end

        -- local pos, ang = ply:GetBonePosition(bone)
        -- pos:Add(wmOffsets.pos or vector_origin)
        -- ang:Add(wmOffsets.ang or angle_zero)

        -- return pos, ang, wmOffsets.scale
    end,
    ["cw_base"] = function(wep)
        if wep.DrawTraditionalWorldModel then return end

        local wm = wep.WMEnt

        if IsValid(wm) then
            local hand = ply:LookupBone("ValveBiped.Bip01_R_Hand")

            if hand then
                local pos, ang = ply:GetBonePosition(hand)

                if pos and ang then
                    ang:RotateAroundAxis(ang:Right(), wep.WMAng.x)
                    ang:RotateAroundAxis(ang:Up(), wep.WMAng.y)
                    ang:RotateAroundAxis(ang:Forward(), wep.WMAng.y)

                    pos = pos + wep.WMPos.x * ang:Right()
                    pos = pos + wep.WMPos.y * ang:Forward()
                    pos = pos + wep.WMPos.z * ang:Up()
                    
                    return pos, ang
                end
            else
                return wep:GetPos(), wep:GetAngles()
            end
        end
    end
}

function ENT:ApplyWeaponOffsets(wep)
    local origin, angles, scale = nil, nil, nil
    local getOffsetFunc = getOffsetFuncs[wep.Base]

    if getOffsetFunc then
        origin, angles, scale = getOffsetFunc(wep)
    end

    if !origin then
        return
    end

    self:SetRenderOrigin(origin)
    self:SetRenderAngles(angles)
    self:SetModelScale(scale or wep:GetModelScale())
end

local waterRT = "_rt_waterreflection"
local emptyString = ""

function ENT:Draw()
    self:DestroyShadow()

    -- COMMENT
    if !IsValid(ply) or !ply:Alive() then
        return
    end

    local wep = ply:GetActiveWeapon()

    -- COMMENT
    if !IsValid(wep) or !wep:IsValid() then
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

    local wepModel = wep:GetWeaponWorldModel()
    local didOverride = false

    if wepModel == emptyString then
        return
    end

    if !didOverride and self:GetModel() != wepModel then
        self:SetModel(wepModel)
    end

    self:ApplyWeaponOffsets(wep)

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