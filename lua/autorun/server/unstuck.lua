-- vector with 1 on every axis
local oneVec = Vector(1,1,1)

-- margin used when doing the hull trace (should be a little bit)
local margin = CreateConVar("unstuck_margin", 3, FCVAR_NEVER_AS_STRING, "Hull margin for stuck detection."):GetFloat()*oneVec

-- delay before stuck checks
local delay = CreateConVar("unstuck_tick", 1, FCVAR_NEVER_AS_STRING, "Stuck check interval (lower = more reponsive)."):GetFloat()

-- minimum velocity difference to consider stuck
local velMin = CreateConVar("unstuck_velocity_min", 5, FCVAR_NEVER_AS_STRING, "Minimum velocity difference to consider stuck."):GetFloat()

cvars.RemoveChangeCallback("unstuck_margin",       "default")
cvars.RemoveChangeCallback("unstuck_tick",         "default")
cvars.RemoveChangeCallback("unstick_velocity_min", "default")

cvars.AddChangeCallback("unstuck_margin",       function(cvar, old, new) margin = tonumber(new)*oneVec end, "default")
cvars.AddChangeCallback("unstuck_tick",         function(cvar, old, new) delay  = tonumber(new)        end, "default")
cvars.AddChangeCallback("unstuck_velocity_min", function(cvar, old, new) velMin = tonumber(new)        end, "default")

local function IsStuck(pl, mv)
	-- don't bother with incompatible players
	if pl:OnGround() or pl:GetMoveType() != MOVETYPE_WALK or pl:GetObserverMode() != OBS_MODE_NONE then return false end

	local time       = RealTime()
	local nextStuck  = pl.m_fNextStuck or 0

	-- don't bother if the player shouldn't be checked for being stuck (yet)
	if time < nextStuck then return end

	-- update the next time the player should be checked for being stuck
	pl.m_fNextStuck = time+delay

	local vel    = mv:GetVelocity()
	local oldVel = pl.m_vUnstuckVel or vel

	-- update the player's old velocity
	pl.m_vUnstuckVel = vel

	-- don't bother if the player has no velocity at all
	if vel.x == 0 and vel.y == 0 and vel.z == 0 then return false end

	local pos        = mv:GetOrigin()
	local mins, maxs = pl:GetHull()
	local velDist    = vel:Distance(oldVel)

	-- don't bother if the distance between the current and old velocities is too great
	if velDist > velMin then return false end

	-- now do a hull trace to be certain the player is actually stuck
	if !util.TraceHull{filter=pl,start=pos,endpos=pos,mins=mins+margin,maxs=maxs-margin,mask=MASK_PLAYERSOLID}.Hit then return false end

	-- ok don't panic rescue is on the way
	return true
end

local function SetupHooks()
	hook.Add("Move", "unstuck", function(pl, mv)
		-- player isn't stuck, everybody go home
		if !IsStuck(pl, mv) then return end

		local pos  = pl:GetPos()
		local area = navmesh.GetNearestNavArea(pos, true, 999999, false, false)

		-- an area couldn't be found...?
		if !area:IsValid() then return end

		local mins, maxs = pl:GetHull()
		local areaPos    = area:GetCenter()

		-- rescue the player from purgatory
		mv:SetOrigin(areaPos)
		mv:SetVelocity(Vector())
	end)
end

hook.Add("InitPostEntity", "unstuck", function()
	-- this timer is needed because apparently the navmesh hasn't quite loaded at this point yet
	timer.Simple(1, function()
		-- a navmesh wasn't loaded with the map, we don't even need to do anything
		if !navmesh.IsLoaded() then return end

		-- just kidding we need to setup the system now
		SetupHooks()
	end)
end)

-- uncomment if testing (this will be called once automatically for comptabile maps)
-- SetupHooks()
