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

    self:SetAutomaticFrameAdvance(true)
    self:SetMoveType(MOVETYPE_NONE)
    self:DrawShadow(true)
    self:SetRenderMode(RENDERMODE_NORMAL)
    self:AddEffects(EF_BONEMERGE)
    self:SetMaterial("engine/occlusionproxy")
end

local ENTITY = FindMetaTable("Entity")
local PLAYER = FindMetaTable("Player")
local pGetActiveWeapon = PLAYER.GetActiveWeapon
local eIsValid = ENTITY.IsValid
local eGetNumBodyGroups = ENTITY.GetNumBodyGroups
local eGetBodygroup = ENTITY.GetBodygroup
local eSetBodygroup = ENTITY.SetBodygroup
local eSetNextClientThink = ENTITY.SetNextClientThink
local aCurTime = CurTime
local aIsValid = IsValid

function ENT:Think()
    local curTime = aCurTime()
    local wep = pGetActiveWeapon(ply)

    if aIsValid(wep) and eIsValid(wep) then
        for i = 1, eGetNumBodyGroups(wep) do
            eSetBodygroup(self, i, eGetBodygroup(wep, i))
        end
    end

    -- Set the next think to run as soon as possible, i.e. the next frame.
    eSetNextClientThink(self, curTime + 1.0)

    -- Apply NextThink call
    return true
end

local arc9Ang = Angle(-5, 0, 180)

local getOffsetFuncs = {
    ["arc9_base"] = function(wep, wepTable)
        local wmOffsets = wepTable.WorldModelOffset
        local shouldTPIK = wep:ShouldTPIK()

        return shouldTPIK and wmOffsets.TPIKPos or wmOffsets.Pos, shouldTPIK and wmOffsets.TPIKAng or wmOffsets.Ang or arc9Ang, wmOffsets.Scale
    end,
    -- ISSUE: Impossible(?) to fix, base implementation relies on .WMModel which doesn't draw unless localplayer does.
    ["arccw_base"] = function(wep, wepTable)
        local wmOffsets = wepTable.WorldModelOffset

        if !wmOffsets then
            return
        end

        local vm = ply

        if wepTable.MirrorVMWM then
            vm = wep
        end

        local bonename = wmOffsets.WMBone or "ValveBiped.Bip01_R_Hand"
        local boneindex = vm:LookupBone(bonename)

        if !boneindex then
            return
        end

        local bpos, bang = vm:GetBonePosition(boneindex)
        local pos = offset or Vector(0, 0, 0)
        local ang = wmOffsets.OffsetAng or Angle(0, 0, 0)
        local vs = wmOffsets.scale or 1
        vscale = Vector(vs, vs, vs)

        pos = pos * vscale

        local moffset = (wmOffsets.ModelOffset or Vector(0, 0, 0))
        local apos = Vector(0, 0, 0)

        apos = bpos + bang:Forward() * pos.x
        apos = apos + bang:Right() * pos.y
        apos = apos + bang:Up() * pos.z

        local aang = Angle(0, 0, 0)
        aang:Set(bang)

        aang:RotateAroundAxis(aang:Right(), ang.p)
        aang:RotateAroundAxis(aang:Up(), ang.y)
        aang:RotateAroundAxis(aang:Forward(), ang.r)

        apos = apos + aang:Forward() * moffset.x
        apos = apos + aang:Right() * moffset.y
        apos = apos + aang:Up() * moffset.z

        if !apos or !aang then
            return
        end

        return apos, aang, vs
    end,
    ["cw_base"] = function(wep, wepTable)
        if wepTable.DrawTraditionalWorldModel then
            return
        end

        local wm = wepTable.WMEnt

        if aIsValid(wm) then
            local hand = ply:LookupBone("ValveBiped.Bip01_R_Hand")

            if hand then
                local pos, ang = ply:GetBonePosition(hand)

                if pos and ang then
                    ang:RotateAroundAxis(ang:Right(), wepTable.WMAng.x)
                    ang:RotateAroundAxis(ang:Up(), wepTable.WMAng.y)
                    ang:RotateAroundAxis(ang:Forward(), wepTable.WMAng.y)

                    pos = pos + wepTable.WMPos.x * ang:Right()
                    pos = pos + wepTable.WMPos.y * ang:Forward()
                    pos = pos + wepTable.WMPos.z * ang:Up()
                    
                    return pos, ang
                end
            else
                return wep:GetPos(), wep:GetAngles()
            end
        end
    end
}

local eAddEffects = ENTITY.AddEffects
local eRemoveEffects = ENTITY.RemoveEffects
local eSetRenderOrigin = ENTITY.SetRenderOrigin
local eSetRenderAngles = ENTITY.SetRenderAngles
local eGetModelScale = ENTITY.GetModelScale
local eSetModelScale = ENTITY.SetModelScale

local function ApplyWeaponOffsets(ent, wep, wepTable)
    local origin, angles, scale = nil, nil, nil
    local getOffsetFunc = getOffsetFuncs[wepTable.Base]

    if getOffsetFunc then
        origin, angles, scale = getOffsetFunc(wep, wepTable)
    end

    if !origin then
        eAddEffects(ent, EF_BONEMERGE)

        return
    end

    eRemoveEffects(ent, EF_BONEMERGE)
    eSetRenderOrigin(ent, origin)
    eSetRenderAngles(ent, angles)
    eSetModelScale(ent, scale or eGetModelScale(wep))
end

local eGetTable = ENTITY.GetTable
local eDestroyShadow = ENTITY.DestroyShadow
local pAlive = PLAYER.Alive
local pShouldDrawLocalPlayer = PLAYER.ShouldDrawLocalPlayer
local pFlashlightIsOn = PLAYER.FlashlightIsOn
local rGetName = FindMetaTable("ITexture").GetName
local sLower = string.lower
local wGetWeaponWorldModel = FindMetaTable("Weapon").GetWeaponWorldModel
local eGetModel = ENTITY.GetModel
local eSetModel = ENTITY.SetModel
local eDrawModel = ENTITY.DrawModel
local eCreateShadow = ENTITY.CreateShadow
local waterRT = "_rt_waterreflection"
local emptyString = ""

function ENT:Draw()
    eDestroyShadow(self)

    -- COMMENT
    if !aIsValid(ply) or !pAlive(ply) then
        return
    end

    local wep = pGetActiveWeapon(ply)
    -- COMMENT
    if !aIsValid(wep) or !eIsValid(wep) then
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

    local wepModel = wGetWeaponWorldModel(wep)
    local didOverride = false

    -- print("wepModel", wepModel)

    if wepModel == emptyString then
        return
    end

    if !didOverride and eGetModel(self) != wepModel then
        eSetModel(self, wepModel)
    end

    ApplyWeaponOffsets(self, wep, eGetTable(wep))

    eDrawModel(self)

    -- FIXME: Why do we have to do this manually?
    eCreateShadow(self)
end

function ENT:OnReloaded()
    self:Remove()
end