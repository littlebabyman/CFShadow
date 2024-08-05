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
    self:DrawShadow(true)
    self:SetRenderMode(RENDERMODE_NORMAL)
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
    ["arccw_base"] = function(wep, wepTable)
        local wmOffsets = wepTable.WorldModelOffset

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

        if !apos or !aang then
            return
        end

        return apos, aang, scale

        -- local bone = ply:LookupBone(wmOffsets.bone)

        -- if !bone then return end

        -- local pos, ang = ply:GetBonePosition(bone)
        -- pos:Add(wmOffsets.pos or vector_origin)
        -- ang:Add(wmOffsets.ang or angle_zero)

        -- return pos, ang, wmOffsets.scale
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
        return
    end

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

    if wepModel == emptyString then
        return
    end

    if !didOverride and eGetModel(self) != wepModel then
        eSetModel(self, wepModel)
    end

    ApplyWeaponOffsets(self, wep, eGetTable(wep))

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