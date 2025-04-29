--[[

= Sonic Onset Adventure Client =

Source: ControlScript/Player.lua
Purpose: Player class
Author(s): Regan "CuckyDev/TheGreenDeveloper" Green

--]]

local player = {}

local assets = script.Parent:WaitForChild("Assets")
local global_sounds = assets:WaitForChild("Sounds")
local obj_assets = assets:WaitForChild("Objects")
local remote = game.ReplicatedStorage.SuperForm
local issuper = script.IsSuper.Value

local ts = game:GetService("TweenService")
local camera=workspace.CurrentCamera
local CameraShaker = require(game.ReplicatedStorage.CommonModules.CameraShaker)
local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCFrame)
	camera.CFrame = camera.CFrame * shakeCFrame
end)
camShake:Start()

local spilled_ring = obj_assets:WaitForChild("SpilledRing")

local speed_shoes_theme = global_sounds:WaitForChild("SpeedShoes")
local speed_shoes_theme_id = string.sub(speed_shoes_theme.SoundId, 14)
local speed_shoes_theme_volume = speed_shoes_theme.Volume

local invincibility_theme = global_sounds:WaitForChild("Invincibility")
local invincibility_theme_id = string.sub(invincibility_theme.SoundId, 14)
local invincibility_theme_volume = invincibility_theme.Volume

local extra_life_jingle = global_sounds:WaitForChild("ExtraLife")

local replicated_storage = game:GetService("ReplicatedStorage")
local common_modules = replicated_storage:WaitForChild("CommonModules")
local switch = require(common_modules:WaitForChild("Switch"))
local automation = require(script:WaitForChild("Automation"))
local vector = require(common_modules:WaitForChild("Vector"))
local cframe = require(common_modules:WaitForChild("CFrame"))
local common_collision = require(common_modules:WaitForChild("Collision"))
local global_reference = require(common_modules:WaitForChild("GlobalReference"))
local camera = require(script:WaitForChild("Camera"))
local player_draw = require(script.Parent:WaitForChild("PlayerDraw"))
local plane_lock = require(script:WaitForChild('PlaneLock'))
local ledge_climb = require(script:WaitForChild('LedgeClimb'))
local sg = require(script:WaitForChild('SphereGravity'))
local constants = require(script.Parent:WaitForChild("Constants"))
local input = require(script:WaitForChild("Input"))
local acceleration = require(script:WaitForChild("Acceleration"))
local movement = require(script:WaitForChild("Movement"))
local collision = require(script:WaitForChild("Collision"))
local rail = require(script:WaitForChild("Rail"))
local homing_attack = require(script:WaitForChild("HomingAttack"))
local lsd = require(script:WaitForChild("LSD"))
local ragdoll = require(script:WaitForChild("Ragdoll"))
local animation = require(script:WaitForChild("Animation"))
local sound = require(script:WaitForChild("Sound"))
local pulley = require(script:WaitForChild("Pulleys"))
local poles = require(script:WaitForChild("Poles"))
--local lerp_camera = require(script:WaitForChild("LerpCamera"))
local ledge = require(script:WaitForChild("WallInteractions"))
local object_reference = global_reference:New(workspace, "Level/Objects")

--local interactables = require(script:WaitForChild("Interactables"))
local mod_settings = require(common_modules:WaitForChild("Settings"))
local mod_settings = mod_settings[1]

shared.Settings = mod_settings

local debris = require(common_modules:WaitForChild("Debris"))

local _jumpads = {}
for i,d in pairs(workspace:WaitForChild("Level"):WaitForChild("JumpPads"):GetDescendants()) do
	if d:IsA("Part") and d.Name == "Hitbox" then
		table.insert(_jumpads, d)
	end
end

workspace:WaitForChild("Level"):WaitForChild("JumpPads").DescendantAdded:Connect(function(d)
	if d:IsA("Part") and d.Name == "Hitbox" then
		table.insert(_jumpads, d)
	end
end)
local _jumppadoverlap = OverlapParams.new()
_jumppadoverlap.FilterType = Enum.RaycastFilterType.Include

local plrrings = 0

local scd = false

--Common functions
function lerp(x, y, z)
	return x + (y - x) * z
end
local ModAddedConnection = nil




--Constructor and destructor
function player:New(character) 
	for i=1, 5 do 
		game["Run Service"].RenderStepped:Wait()
	end
	--Initialize meta reference
	local self = setmetatable({}, {__index = player})

	--Load character's info
	local info = nil
	if character ~= nil then
		self.character = character
		info = require(self.character:WaitForChild("CharacterInfo"))
	else
		error("Player can't be created without character")
		return nil
	end


	--Other
	self.homing_module = homing_attack

	--Use character's info
	self.p = info.physics
	self.assets = info.assets
	self.animations = info.animations
	self.portraits = info.portraits

	--Find common character references
	self.hum = character:WaitForChild("Humanoid")
	self.hrp = character:WaitForChild("HumanoidRootPart")

	constants.state.dropdashcharging = false

	--Create player draw
	self.player_draw = player_draw:New(character, self)
	
-- MODS
	local env = {} -- initial environments
	local env_maps = {0, 1, 2}

	for i,v in pairs(env_maps) do
		local c_env = getfenv(v)
		for i,v in pairs(c_env) do
			if not env[i] then
				env[i] = v
			end
		end
	end

	self.mods = {}
	self.mods_early = {}
	self.mods_late = {}
	self.Overwrite = {}
	
	ModUI = script:WaitForChild("ModSetupWindow"):Clone()
	ModUI.Parent = game.Players.LocalPlayer.PlayerGui
	Template = ModUI:WaitForChild("Main"):WaitForChild("Error")
	Template.Parent = nil
	Errors = 0

	function RegisterMod(v:ModuleScript)
		if v:IsA("ModuleScript") then
			suc, err = pcall(function()
				local mod = require(v).new(self, self.player_draw.model_holder, env)

				mod.Name = v.Name
				self.mods[v.Name] = mod

				--print(mod)

				if mod.ModInfo.Priority == "Before" then
					self.mods_early[v.Name] = mod
				elseif mod.ModInfo.Priority == "After" then
					self.mods_late[v.Name] = mod
				else
					error(`Invalid mod priority! Listed priority {mod.ModInfo.Priority} is not 'Before'|'After'`)
				end
				
				local anims = mod.ModInfo.Animations:GetChildren()
				for i,v:Animation in pairs(anims) do
					if v:IsA("Animation") and not self.animations[v.Name] then
						self.animations[v.Name] = {
							tracks = {
								{
									name = v.Name
								}
							}
						}
					end
				end
			end)

			if not suc or err then
				Errors += 1
				err = `Mod setup failed, {v.Name}: {err}`
				warn(err)
				UI = Template:Clone()
				UI.Parent = ModUI:WaitForChild("Main")
				UI.Text = err
			end
		end
	end

	for i,v in pairs(script.Parent:WaitForChild("Mods"):GetChildren()) do
		RegisterMod(v)
	end
	if ModAddedConnection then
		ModAddedConnection:Disconnect()
	end

	ModAddedConnection = script.Parent:WaitForChild("Mods").ChildAdded:Connect(RegisterMod)

	Template:Destroy()
	if Errors <= 0 then
		task.delay(10, function()
			if ModUI and ModUI:IsDescendantOf(game.Players.LocalPlayer.PlayerGui) then
				ModUI:Destroy()
			end
		end)
	else
		warn(`Mod loading setup encountered {Errors} errors`)
	end

	-- MODS OVER
	--Load animations and sounds
	sound.LoadSounds(self)
	animation.LoadAnimations(self)

	--Disable humanoid
	local enable = {
		[Enum.HumanoidStateType.None] = true,
		[Enum.HumanoidStateType.Dead] = true,
		[Enum.HumanoidStateType.Physics] = true,
	}
	for _,v in pairs(Enum.HumanoidStateType:GetEnumItems()) do
		if enable[v] ~= true then
			self.hum:SetStateEnabled(v, false)
		end
	end
	self.hum:ChangeState(Enum.HumanoidStateType.Physics)

	--Use character's position and angle
	self.pos = self.hrp.Position - self.hrp.CFrame.UpVector * self:GetCharacterYOff()
	self.ang = self:AngleFromRbx(self.hrp.CFrame.Rotation)
	self.vis_ang = self.ang

	--Initialize player state
	self.state = constants.state.idle
	self.spd = Vector3.new()
	self.gspd = Vector3.new()
	self.flag = {
		grounded = true,
		boost_active = false,
	}

	--Power-up state
	self.shield = nil
	self.speed_shoes_time = 0
	self.invincibility_time = 0

	self.invulnerability_time = 0

	--Meme state
	self.v3 = false

	--Physics state
	self.gravity = Vector3.new(0, -1, 0)

	--Collision state
	self.floor_normal = Vector3.new(0, 1, 0)
	self.dotp = 1

	self.floor = nil
	self.floor_off = CFrame.new()
	self.floor_last = nil
	self.floor_move = nil

	--Movement state
	self.frict_mult = 1

	self.jump_timer = 0
	self.doublejump_timer = 0
	self.spring_timer = 0
	self.dashpanel_timer = 0
	self.dashring_timer = 0
	self.rail_debounce = 0
	self.walljump_timer = 0
	self.rail_trick = 0
	self.float_speed = 0
	--self.camera = lerp_camera:New(self, 0.85)

	self.spindash_speed = 0
	self.slide_speed = 0
	self.jump_action = nil
	self.roll_action = nil
	self.secondary_action = nil
	self.tertiary_action = nil
	self.crawl = false
	self.can_boost = false
	--Animation state
	self.animation = nil
	self.prev_animation = nil
	self.reset_anim = false
	self.anim_speed = 0

	--Game state
	local charval = game.Players.LocalPlayer.Character.CharValue
	local AirDashPower = game.Players.LocalPlayer.Character.AirDashPower.Value
	self.score = workspace:GetAttribute("SaveScore") or 0
	self.time = workspace:GetAttribute("SaveTime") or 0
	self.rings = 0
	
	self.boost_charge = 100
	
	self.item_cards = {}

	self.portrait = "Idle"

	--Initialize sub-systems
	input.Initialize(self)
	rail.Initialize(self)

	--Effects
	--self.speed_trail = self.hrp:WaitForChild("SpeedTrail")
	self.rail_speed_trail = self.hrp:WaitForChild("RailSpeedTrail")
	self.air_kick_trails = {
		self.hrp:WaitForChild("KickBeam1"),
		self.hrp:WaitForChild("KickBeam2"),
	}
	local bottom = self.hrp:WaitForChild("Bottom")
	self.skid_effect = bottom:WaitForChild("Skid")
	local effect1 = self.hrp:WaitForChild("Effect")
	self.rail_sparks = bottom:WaitForChild("Sparks")
	self.spark_effect = effect1:WaitForChild("Sparks")

	--Get level music id and volume
	local music_id = workspace:WaitForChild("Level"):WaitForChild("MusicId")
	local music_volume = workspace:WaitForChild("Level"):WaitForChild("MusicVolume")

	self.level_music_id = music_id.Value
	self.level_music_volume = music_volume.Value

	self.level_music_id_conn = music_id:GetPropertyChangedSignal("Value"):Connect(function()
		self.level_music_id = music_id.Value
	end)
	self.level_music_volume_conn = music_volume:GetPropertyChangedSignal("Value"):Connect(function()
		self.level_music_volume = music_volume.Value
	end)

	--Music state
	self.music_id = self.level_music_id
	self.music_volume = self.level_music_volume
	self.music_reset = false


	self.hum.CameraOffset = workspace:WaitForChild("Level"):WaitForChild("NewStuff"):WaitForChild("CameraOffset").Value

	--[[if workspace.Level.NewStuff.SpawnPos.Value == Vector3.new(0,0,0) then
		workspace.Level.NewStuff.SpawnPos.Value = workspace.Level.Map.SpawnLocation.Position
		self.pos = workspace.Level.NewStuff.SpawnPos.Value
	else
		self.pos = workspace.Level.NewStuff.SpawnPos.Value
	end
	]]if workspace.Level.NewStuff.StartingRings.Value then
		self:GiveRings(workspace.Level.NewStuff.StartingRings.Value)
	end
	
	return self
end

function player:Destroy()
	--Disconnect level music events
	if self.level_music_id_conn ~= nil then
		self.level_music_id_conn:Disconnect()
		self.level_music_id_conn = nil
	end
	if self.level_music_volume_conn ~= nil then
		self.level_music_volume_conn:Disconnect()
		self.level_music_volume_conn = nil
	end
	--self.camera:Update()
	
	if ModAddedConnection then
		ModAddedConnection:Disconnect()
	end
	--Quit sub-systems
	input.Quit(self)
	rail.Quit(self)
	
	for i,v in pairs(self.mods) do
		if v.Destroy then
			v.Destroy(self, v)
		end
	end
	--Destroy player draw
	if self.player_draw ~= nil then
		self.player_draw:Destroy()
		self.player_draw = nil
	end

	--Unload animations and sounds
	animation.UnloadAnimations(self)
	sound.UnloadSounds(self)
end

--Character functions
function player:GetCharacterYOff()
	return self.hum.HipHeight + self.hrp.Size.Y / 2
end

--Physics setter
local phys_dump_map = {
	"jump2_timer",
	"pos_error",
	--"doublejump_timer",
	--"doublejumpdash",
	--"homing_max_reach",
	--"dash_ability",
	"lim_h_spd",
	"lim_v_spd",
	"max_x_spd",
	"max_psh_spd",
	"jmp_y_spd",
	"nocon_speed",
	"slide_speed",
	"jog_speed",
	"run_speed",
	"rush_speed",
	"crash_speed",
	"dash_speed",
	"jmp_addit",
	"run_accel",
	"air_accel",
	"slow_down",
	"run_break",
	"air_break",
	"air_resist_air",
	"air_resist",
	"air_resist_y",
	"air_resist_z",
	"grd_frict",
	"grd_frict_z",
	"lim_frict",
	"rat_bound",
	"rad",
	"height",
	"weight",
	"eyes_height",
	"center_height",
}

local physics = script:WaitForChild("Physics")

function player:SetPhysics(game, char)
	local game_mod = physics:FindFirstChild(game)
	if game_mod ~= nil and game_mod:IsA("ModuleScript") then
		local game_pack = require(game_mod)
		local char_phys = game_pack[char]

		if char_phys ~= nil then
			for i, v in pairs(char_phys) do
				local map = phys_dump_map[i]
				self.p[map] = v
			end
			self.p.height /= 2
		end
	end
end


--Player space conversion
function player:ToGlobal(vec)
	return self.ang * vec
end

function player:ToLocal(vec)
	return self.ang:inverse() * vec
end

function player:GetLook()
	return self.ang.RightVector
end

function player:GetRight()
	return -self.ang.LookVector
end

function player:GetUp()
	return self.ang.UpVector
end

function player:AngleFromRbx(ang)
	return ang * CFrame.fromAxisAngle(Vector3.new(0, 1, 0), math.pi / 2)
end

function player:AngleToRbx(ang)
	return ang * CFrame.fromAxisAngle(Vector3.new(0, 1, 0), math.pi / -2)
end

function player:ToWorldCFrame()
	return self:AngleToRbx(self.ang) + self.pos
end

function player:PosToSpd(vec)
	return Vector3.new(-vec.Z, vec.Y, vec.X)
end

function player:SpdToPos(vec)
	return Vector3.new(vec.Z, vec.Y, -vec.X)
end

--Player collision functions
function player:GetMiddle()
	return self.pos + (self:GetUp() * (self.p.height * self.p.scale))
end

function player:GetSphereRadius()
	return ((self.p.height + self.p.rad) / 2) * self.p.scale
end

function player:GetSphere()
	return {
		center = self:GetMiddle(),
		radius = self:GetSphereRadius()
	}
end

function player:GetRegion()
	local mid = self:GetMiddle()
	local rad = self:GetSphereRadius()
	return Region3.new(
		mid - Vector3.new(rad, rad, rad),
		mid + Vector3.new(rad, rad, rad)
	)
end

--Player state functions
function player:IsBlinking()
	return self.invulnerability_time > 0 and self.state ~= constants.state.hurt and self.state ~= constants.state.dead
end




function player:Damage(hurt_origin)
	local charval = game.Players.LocalPlayer.Character.CharValue
	--Do not take damage if invulnerable to damage
		if self.invulnerability_time > 0 or self.invincibility_time > 0 or script.IsSuper.Value == true or charval.Value == "Super" then
		return false
	end

	--Set state
	self:ResetObjectState()
	self:ExitBall()
	self.hurt_time = 1.5 * constants.framerate
	self.invulnerability_time = 2.75 * constants.framerate
	self.state = constants.state.hurt
	self.flag.grounded = false




	
	



	--Play hurt animation
	if math.abs(self.spd.X) >= self.p.dash_speed then
		self.animation = "Hurt2"
	else
		self.animation = "Hurt1"
	end
	if self.spd.X > 10  then
		self.animation = "MachHurt"
	end
	--Set speed and rotation
	local diff = vector.PlaneProject(((hurt_origin ~= nil) and (hurt_origin - self:GetMiddle()) or (self:GetLook())), -self.gravity.unit)

	if diff.magnitude ~= 0 then
		local factor = math.abs(self:ToGlobal(self.spd):Dot(diff.unit)) / 5
		self:SetAngle(cframe.FromToRotation(self:GetLook(), diff.unit) * self.ang)
		self.spd = self:ToLocal((diff.unit * -1.125 * (1 + factor)) + (-self.gravity.unit * 1.675 * (1 + factor / 4)))
	else
		self.spd = self:ToLocal(-self.gravity.unit * 2.125)
	end

	--Damage
	if self.shield ~= nil then
		--Lose shield
		self.shield = nil
	else
		if self.rings > 0 then
			--Prepare to spill rings
			local lose_rings = math.min(self.rings, 20)
			local objects = object_reference:Get()
			local look = self:GetLook()
			local look_ang = math.atan2(look.X, look.Z)

			sound.PlaySound(self, "RingLoss")

			if lose_rings > 0 then
				--Spill first 10 rings in a taller arc
				local circle_rings = math.min(lose_rings, 10)
				local ang_inc = math.pi * 2 / circle_rings
				local ang = look_ang

				for i = 1, circle_rings do
					--Spill ring
					local ring = spilled_ring:Clone()
					ring:SetPrimaryPartCFrame(CFrame.new(self:GetMiddle()))
					ring.PrimaryPart.Velocity = Vector3.new(-math.sin(ang) * 30, 90, -math.cos(ang) * 30)
					ring.Parent = objects

					--Increment angle
					ang += ang_inc
				end
			end

			if lose_rings > 10 then
				--Spill second 10 rings in a shorter arc
				local circle_rings = math.min(lose_rings - 10, 10)
				local ang_inc = math.pi * 2 / circle_rings
				local ang = look_ang

				for i = 1, circle_rings do
					--Spill ring
					local ring = spilled_ring:Clone()
					ring:SetPrimaryPartCFrame(CFrame.new(self:GetMiddle()))
					ring.PrimaryPart.Velocity = Vector3.new(-math.sin(ang) * 45, 60, -math.cos(ang) * 45)
					ring.Parent = objects

					--Increment angle
					ang += ang_inc
				end
			end

			--Lose rings
			self.rings = math.max(self.rings - 150, 0)
		else
			--TODO: die
			--Die
			local charval = game.Players.LocalPlayer.Character.CharValue
			local issonic = charval.Value == "Sonic"
			local isshadow = charval.Value == "Shadow"
			local issilver = charval.Value == "Silver"
			self.state = constants.state.dead
			if self.character:FindFirstChild("FloatAura") then
				self.character:FindFirstChild("FloatAura"):Destroy()
				sound.StopSound(self, "Float_activate")
				sound.StopSound(self, "Float_dash")
				sound.StopSound(self, "Float_move")
			end
			self.spd = Vector3.new(0, 0, 0)
			self.dead_spd = 0.8
			self.animation = "Death"
			local angle = CFrame.lookAt(self.hrp.Position, workspace:WaitForChild('Camera').CFrame.Position)
			self:SetAngle(self:AngleFromRbx(angle - angle.p))
			if issonic then
				sound.PlaySound(self, "No!")
				wait(2.7) self.hum.Health = 0
			else
				if isshadow then
					sound.PlaySound(self, "SHno")
					wait(2.7) self.hum.Health = 0
				else
					if issilver then
						sound.PlaySound(self, "Not Now")
						wait(2.7) self.hum.Health = 0
					else

						local camera_subject = Instance.new("Part")
						camera_subject.Parent = workspace
						camera_subject.Anchored = true
						camera_subject.Transparency = 1
						camera_subject.CFrame = self.hrp.CFrame*CFrame.new(0, 3, 0)
						workspace:WaitForChild('Camera').CameraSubject = camera_subject

						game:GetService("Debris"):AddItem(camera_subject, 12)
						wait(2.7) self.hum.Health = 0
						game.ReplicatedStorage.LoadCharacter:FireServer()
						game.Workspace.Level.NewStuff.Lives.Value = game.Workspace.Level.NewStuff.Lives.Value - 1
						if self.flag.grounded == false then
							self.state = constants.state.airborne
						end
					end
				end
			end
		end
	end
	return true
end







function player:ResetObjectState()
	self.flag.scripted_spring = false
	self.spring_timer = 0
	self.dashpanel_timer = 0
	self.dashring_timer = 0
	self.rail_trick = 0
	rail.SetRail(self, nil)
end

function player:EnterBall()
	self.flag.ball_aura = true
	self.flag.air_kick  =  true
end

function player:ExitBall()
	sound.StopSound(self, "SpindashCharge")
	self.flag.air_kick = false
	self.flag.ball_aura = false
	self.flag.dash_aura = false
end

function player:Land()
	-- Ensure the Effects and LandEffect exist
	local effectsFolder = script:FindFirstChild('Effects')
	if not effectsFolder then
		warn("Effects folder not found!")
		return
	end

	local landEffectTemplate = effectsFolder:FindFirstChild('LandEffect')
	if not landEffectTemplate then
		warn("LandEffect not found!")
		return
	end

	-- Clone the effect and set its parent and position
	local effect = landEffectTemplate:Clone()
	effect.Parent = workspace
	if self.pos then
		effect.Position = self.pos
	else
		warn("self.pos is nil, cannot set effect position!")
		return
	end

	-- Enable particles and configure their rates
	for _, particle in pairs(effect:GetDescendants()) do
		if particle:IsA('ParticleEmitter') then
			local originalRate = particle:GetAttribute('OriginalRate') or particle.Rate
			particle:SetAttribute('OriginalRate', originalRate)
			particle.Rate = originalRate
			particle.Enabled = true
		end
	end

	-- Handle cleanup with a task
	task.spawn(function()
		wait(0.11)
		for _, particle in pairs(effect:GetDescendants()) do
			if particle:IsA('ParticleEmitter') then
				particle.Rate = 0
			end
		end
		wait(2)
		if effect and effect.Parent then
			effect:Destroy()
		end
	end)

	-- Exit ball and reset bounce flag
	self:ExitBall()
	self.flag.bounce2 = false
end

function player:TrailActive()
	if self.flag.grounded then
		return self.flag.ball_aura and self.state ~= constants.state.spindash
	else
		return self.flag.dash_aura or self.state == constants.state.homing or self.state == constants.state.bounce
	end
end

function player:BallActive()
	return self.flag.ball_aura or self.state == constants.state.air_kick
end

function player:Bounce(pwr)
	self.spd = vector.SetY(self.spd, pwr)
end

function player:ObjectBounce()
	--Enter airborne state
	if self.state == constants.state.homing or self.state == constants.state.air_kick then
		self.flag.air_kick = true
	end
	if self:BallActive() then
		self:EnterBall()
		self.animation = "Roll"
		self.flag.dash_aura = false
	end
	self.state = constants.state.airborne

	self.flag.grounded = false

	--Set speed
	self.spd = Vector3.new(0, 3, 0)
	self.anim_speed = self.spd.magnitude
end

function player:UseFloorMove()
	if self.floor_move ~= nil then
		self.spd += self:ToLocal(self.floor_move) / self.p.scale
		self.floor_move = nil
	end
end

function player:Scripted()
	return (self.flag.grounded and (false) or (self.spring_timer > 0 or self.dashring_timer > 0))
end

--Physics functions
function player:GetWeight()
	return self.p.weight * (self.flag.underwater and 0.45 or 1)
end

function player:GetAirResistY()
	return self.p.air_resist_y * (self.flag.underwater and 1.5 or 1)
end

function player:GetMaxXSpeed()
	if self.state == constants.state.crawl then
		return self.p.max_x_spd /4 * ((self.speed_shoes_time > 0) and 2 or 1)
	else
		return self.p.max_x_spd * ((self.speed_shoes_time > 0) and 2 or 1)
	end
end

function player:GetRunAccel()
	return self.p.run_accel * (self.underwater and 0.65 or 1) * ((self.speed_shoes_time > 0) and 2 or 1)
end

--Game functions
function player:GiveScore(score)
	--Give score
	self.score += score
	--self.boost_charge += 0.01*score
end

function player:GiveRings(rings)
	--Give ring and score bonus
	self.rings += rings
	self.boost_charge += 2*rings
end

function player:GiveItem(item)
	--Handle item
	switch(item, {}, {
		["5Rings"] = function()
			self:GiveScore(10 * 5)
			self:GiveRings(5)
		end,
		["10Rings"] = function()
			self:GiveScore(10 * 10)
			self:GiveRings(10)
		end,
		["20Rings"] = function()
			self:GiveScore(10 * 20)
			self:GiveRings(20)
		end,
		["1Up"] = function()
			extra_life_jingle:Play()
		end,
		["Invincibility"] = function()
			self.invincibility_time = 20 * constants.framerate
			self.music_id = invincibility_theme_id
			self.music_volume = invincibility_theme_volume
			self.music_reset = true
		end,
		["SpeedShoes"] = function()
			self.speed_shoes_time = 18 * constants.framerate
			self.music_id = speed_shoes_theme_id
			self.music_volume = speed_shoes_theme_volume
			self.music_reset = true
		end,
		["Shield"] = function()
			self.shield = "Shield"
		end,
		["MagnetShield"] = function()
			self.shield = "MagnetShield"
		end,
		["Walkonwalls"] = function()
			workspace.Level.NewStuff.Walkonwalls.Value = true 
		end,
	})

	--Process item for hud item cards
	table.insert(self.item_cards, item)
end

--Other player global functions
function player:SetAngle(ang)
	if self.flag.grounded and not self.v3 then
		--Set angle
		self.ang = ang
	else
		--Set angle, maintaining middle
		self.pos += self:GetUp() * self.p.height * self.p.scale
		self.ang = ang
		self.pos -= self:GetUp() * self.p.height * self.p.scale
	end

	--Set other angle information
	self.dotp = -self:GetUp():Dot(self.gravity.unit)
	self.floor_normal = self:GetUp()
end

--Player turn functions
function player:Turn(turn)
	if self.v3 and self.dotp < 0.95 then
		local fac = math.min(math.abs(self.spd.X) / self.p.max_x_spd, 1)
		turn *= fac
	end
	if self.state == constants.state.boost or self.state == constants.state.airboost then
		turn = turn*0.2
	end
	if self.state == constants.state.air_kick then
		turn = turn*0.5
	end
	self.ang *= CFrame.fromAxisAngle(Vector3.new(0, 1, 0), turn)
	return turn
end

function player:AdjustAngleY(turn)
	--Get analogue state
	local has_control,_,_ = input.GetAnalogue(self)

	--Remember previous global speed
	local prev_spd = self:ToGlobal(self.spd)

	--Get max turn
	local max_turn = math.abs(turn)

	if max_turn <= math.rad(25) then
		if max_turn <= math.rad(12.5) then
			max_turn /= 10
		else
			max_turn /= 5
		end
	else
		max_turn = math.rad(22.5)
	end

	--Turn
	if not self.v3 then
		turn = math.clamp(turn, -max_turn, max_turn)
	end
	turn = self:Turn(turn)

	--Handle inertia
	if self.v3 ~= true then
		if not self.flag.grounded then
			--90% inertia
			self.spd = self.spd * 0.1 + self:ToLocal(prev_spd) * 0.9
		else
			local inertia
			if has_control then
				if self.dotp <= 0.4 then
					inertia = 0.5
				else
					inertia = 0.01
				end
			else
				inertia = 0.95
			end

			if self.frict_mult < 1 then
				inertia *= self.frict_mult
			end

			self.spd = self.spd * (1 - inertia) + self:ToLocal(prev_spd) * inertia
		end
	end

	return turn
end

function player:AdjustAngleYQ(turn)
	--Turn with full inertia
	local prev_spd = self:ToGlobal(self.spd)

	if not self.v3 then
		turn = math.clamp(turn, math.rad(-45), math.rad(45))
	end
	turn = self:Turn(turn)

	if self.v3 ~= true then
		self.spd = self:ToLocal(prev_spd)
	end

	return turn
end

function player:AdjustAngleYS(turn)
	--Remember previous global speed
	local prev_spd = self:ToGlobal(self.spd)

	--Get max turn
	local max_turn = math.rad(1.40625)
	if self.spd.X > self.p.dash_speed then
		max_turn = math.max(max_turn - (math.sqrt(((self.spd.X - self.p.dash_speed) * 0.0625)) * max_turn), 0)
	end

	--Turn
	if not self.v3 then
		turn = math.clamp(turn, -max_turn, max_turn)
	end
	turn = self:Turn(turn)

	--Handle inertia
	if self.v3 ~= true then
		local inertia
		if self.dotp <= 0.4 then
			inertia = 0.5
		else
			inertia = 0.01
		end

		self.spd = self.spd * (1 - inertia) + self:ToLocal(prev_spd) * inertia
	end

	return turn
end

--Moves
local function GetWalkState(self)
	if math.abs(self.spd.X) > 0.01 then
		return constants.state.walk

	else
		return constants.state.idle
	end
end
local function CheckCrawlCrouch(self)
	if self.input.button_press.tertiary_action and not self.flag.air_kick then
		if self.spd.X < 0.5 then
			self.state = constants.state.crouch
		else
			sound.PlaySound(self, "Slide")
			self.state = constants.state.slide
			self.slide_speed = self.spd.X /1.5 + 1.5
		end
	end
end

local jumppad_connection = nil
local jumppad_last = nil
local last_jump_pad = nil
local jumppadspatial = require(common_modules:WaitForChild("SpatialPartitioning")):New(32)

for i,v in pairs(workspace:WaitForChild("Level"):WaitForChild("JumpPads"):WaitForChild("MainPads"):GetChildren()) do
	jumppadspatial:Add(v.PrimaryPart)
end
workspace:WaitForChild("Level"):WaitForChild("JumpPads"):WaitForChild("MainPads").ChildAdded:Connect(function(v)
	jumppadspatial:Add(v.PrimaryPart)
end)

local function CheckJump(self, alt)
	if self.state == constants.state.jump_pad and not jumppad_last then return end
	--Check for jumping
	
	self.jump_action = "Jump"
	if self.input.button_press.jump then
		local is_on_jumppad = false
		local overlapping = jumppadspatial:GetPartsInRegion(self:GetRegion())
		if #overlapping >= 1 and not self.board then
			is_on_jumppad = true
			local suc = false

			local main = overlapping[1]:FindFirstAncestorOfClass("Model")
			local root = overlapping[1] :: BasePart

			if main and main:FindFirstChild("Next") then
				local next = main:FindFirstChild("Next").Value :: Instance?
				--print(next)

				if next and next:IsA("Part") then
					suc = true
					self.state = constants.state.jump_pad
					local dist = (root.Position - next.Position).Magnitude
					dist /= 600--350
					jumppad_last = nil
					sound.PlaySound(self, "Jump")
					--self.sounds["jumppad_success"]:Play()

					local val = Instance.new("NumberValue", script)
					debris:AddItem(val, dist)

					local old_col = main:WaitForChild("Cylinder.004").Color
					main:WaitForChild("Cylinder.004").Color = Color3.new(1,1,1)
					game:GetService("TweenService"):Create(main:WaitForChild("Cylinder.004"), TweenInfo.new(.25), {Color = old_col}):Play()

					local fx_at = game.ReplicatedStorage.Assets.Effects.JumpPadTriggerEffect:Clone()
					debris:AddItem(fx_at, 2)
					fx_at.Parent = root
					fx_at.jump_1:Emit(1)
					fx_at.use_1:Emit(1)
					fx_at.use_2:Emit(1)

					game:GetService("TweenService"):Create(val, TweenInfo.new(dist, Enum.EasingStyle.Linear), {Value = 1}):Play()


					if jumppad_connection then
						jumppad_connection:Disconnect()
					end

					last_jump_pad = next

					local died = false

					jumppad_connection = val:GetPropertyChangedSignal("Value"):Connect(function()
						if not game.Players.LocalPlayer.Character then
							died = true
							jumppad_last = nil
							is_on_jumppad = false
							last_jump_pad = nil

							jumppad_connection:Disconnect()
							jumppad_connection = nil
							return
						end

						local cur = val.Value
						self.pos = root.Position:Lerp(next.Position, cur) - (self.vis_ang.UpVector * self:GetCharacterYOff())

						workspace.CurrentCamera.CFrame = CFrame.lookAt(workspace.CurrentCamera.CFrame.Position, self.pos)

						-- self:AngleFromRbx(root.CFrame.Rotation:Lerp(next.CFrame.Rotation, cur) * CFrame.Angles(0, math.rad(-90), 0))
						if self.pos + (self.vis_ang.UpVector * self:GetCharacterYOff()) ~= next.Position then
							self.ang = self:AngleFromRbx(CFrame.lookAt(self.pos + (self.vis_ang.UpVector * self:GetCharacterYOff()), next.Position).Rotation)
						else
							self.ang = self:AngleFromRbx(next.CFrame.Rotation)
						end
						self.spd = Vector3.new(0,0,0)
						self.animation = "Roll"
						self.anim_speed = 2

						if cur >= 1 then
							jumppad_connection:Disconnect()
							jumppad_connection = nil
						end
					end)
					self.animation = "AirKick"
					self.anim_speed = 2

					task.delay(dist, function()
						if died then return end

						local fx_at = game.ReplicatedStorage.Assets.Effects.JumpPadTriggerEffect:Clone()
						debris:AddItem(fx_at, 2)
						fx_at.Parent = next
						fx_at.use_1:Emit(1)
						fx_at.use_2:Emit(1)

						--self.sounds["land_click"]:Play()
						--self.sounds["jumppad_land"]:Play()
						jumppad_last = os.clock()
					end)
				elseif not next then
					-- instantly drop off
					local fx_at = game.ReplicatedStorage.Assets.Effects.JumpPadTriggerEffect:Clone()
					debris:AddItem(fx_at, 2)
					fx_at.Parent = root
					fx_at.use_1:Emit(1)
					fx_at.use_2:Emit(1)

					local old_col = main:WaitForChild("Cylinder.004").Color
					main:WaitForChild("Cylinder.004").Color = Color3.new(1,1,1)
					game:GetService("TweenService"):Create(main:WaitForChild("Cylinder.004"), TweenInfo.new(.25), {Color = old_col}):Play()

					--self.sounds["jumppad_launch"]:Play()
					jumppad_last = nil
					if jumppad_connection then
						jumppad_connection:Disconnect()
						jumppad_connection = nil
					end
				end
			end

			if suc then return end
		end
		local effectsFolder = script:FindFirstChild('Effects')
		if not effectsFolder then
			warn("Effects folder not found!")
			return
		end

		local jumpEffectTemplate = effectsFolder:FindFirstChild('JumpEffect')
		if not jumpEffectTemplate then
			warn("JumpEffect not found!")
			return
		end

		-- Clone the effect and set its parent and position
		local effect = jumpEffectTemplate:Clone()
		effect.Parent = workspace
		if self.pos then
			effect.Position = self.pos
		else
			warn("self.pos is nil, cannot set effect position!")
			return
		end

		-- Enable particles and configure their rates
		for _, particle in pairs(effect:GetDescendants()) do
			if particle:IsA('ParticleEmitter') then
				local originalRate = particle:GetAttribute('OriginalRate') or particle.Rate
				particle:SetAttribute('OriginalRate', originalRate)
				particle.Rate = originalRate
				particle.Enabled = true
			end
		end

		-- Handle cleanup with a task
		task.spawn(function()
			wait(0.11)
			for _, particle in pairs(effect:GetDescendants()) do
				if particle:IsA('ParticleEmitter') then
					particle.Rate = 0
				end
			end
			wait(2)
			if effect and effect.Parent then
				effect:Destroy()
			end
		end)
		--Enter jump state
		if self.dotp > 0.9 or not self.v3 then
			self.spd = vector.SetY(self.spd, self.p.jmp_y_spd)
		end
		self:UseFloorMove()
		self.jump_timer = self.p.jump2_timer
		self.flag.grounded = false

		rail.SetRail(self, nil)

		self.state = constants.state.airborne
		self:EnterBall()

		--Play jump animation and sound
		self.animation = "Roll"
		self.anim_speed = self.spd.X
		sound.PlaySound(self, "Jump")









		return true
	end
	return false
end

local function CheckWallJump(self)
	if self.flag.grounded then return end
	local cam = Vector3.new(workspace.CameraLock.Value:ToOrientation())
	--Check for jumping
	self.jump_action = "Jump"
	if self.input.button_press.jump then
		workspace.Level.NewStuff.Walljumping.Value = false
		--Enter jump state
		if self.dotp > 0.9 or not self.v3 then
			self.spd = Vector3.new(4,self.p.jmp_y_spd + 1.5,0)
		end

		self:UseFloorMove()
		self.jump_timer = self.p.jump2_timer
		self.flag.grounded = false

		rail.SetRail(self, nil)

		self.state = constants.state.airborne

		--Play jump animation and sound
		self.animation = "WallJump"
		self.anim_speed = self.spd.X
		sound.PlaySound(self, "Jump")
		return true
	end
	return false
end

local function CheckBoost(self)
	--Check for boosting
	if self.input.button_press.boost and self.boost_charge > 0 then
		camShake:Shake(CameraShaker.Presets.Boost05)
		if self.state == constants.state.airborne then
			self.state = constants.state.airboost
			self.spd = vector.SetX(self.spd, self.p.boost_speed*0.8)
			self.spd = vector.SetY(self.spd, 2)
			sound.PlaySound(self, 'AirBoost')
			sound.PlaySound(self, 'BoostWind')
			sound.PlaySound(self, 'BoostExtra')
			self.boost_charge -= 7.5
			return true
		elseif self.state == constants.state.walk then
			self.state = constants.state.boost
			sound.PlaySound(self, 'Boost')
			sound.PlaySound(self, 'BoostWind')
			sound.PlaySound(self, 'BoostExtra')
			self.boost_charge -= 7.5
	
	
			return true
		end
	end
	return false
	end



local function CheckSpindash(self)
	--Check for spindashing
	self.roll_action = "Spindash"
	if self.input.button_press.roll then


		if workspace.Level.NewStuff.Boost.Value == true then
			--Start spindashing
			sound.StopSound(self, "Boost")
			sound.PlaySound(self, "Boost")
			workspace.Level.MusicFolder.Music.Boosting.Enabled = true
			camShake:Shake(CameraShaker.Presets.Boost)
			self.state = constants.state.spindash
			self.spindash_speed = math.max(self.spd.X, 2)

		else
			--Spindash
			--Start spindashing
			self.state = constants.state.spindash
			self:EnterBall()
			self.spindash_speed = math.max(self.spd.X, 2)
			sound.PlaySound(self, "SpindashCharge")
		end

	end
	return false
end



local peelout = script.Collision.Sound

local function CheckPeelout(self)
	--Check for Peelout
	self.roll_action = "Spindash"
	if self.input.button_press.peelout and workspace.Level.NewStuff.Peelout.Value == true then
		--Start spindashing
		self.state = constants.state.peelout
		self.spindash_speed = math.max(self.spd.X, 2)
		peelout = game.Players.LocalPlayer.Character.Humanoid.Animator:LoadAnimation(script.Peelout)
		peelout:Play()
		sound.PlaySound(self, "SpindashCharge")
		return true
	end
	return false
end

local function CheckUncurl(self)
	--Check for uncurling
	self.roll_action = "Roll"
	if self.input.button_press.roll and not self.flag.ceiling_clip then
		--Uncurl
		self.state = constants.state.walk
		self:ExitBall()
		return true
	end
	return false
end

--[[Epic Super Transform >:V 
c
	local plrrings = self.rings
	local charval = game.Players.LocalPlayer.Character.CharValue
	local players = game.Players
	local LP = players.LocalPlayer
	local char1 = LP.Character
	self.char = char1
	self.hrp = char1:WaitForChild("HumanoidRootPart")
	local remote = game.ReplicatedStorage.SuperForm

	local usrInputService = game:GetService("UserInputService")
	self.super_action = "Super"

	LP.CharacterAdded:Connect(function(newCharacter)
		char1 = newCharacter
		self.char = char1
		self.hrp = char1:WaitForChild("HumanoidRootPart")
		script.IsSuper.Value = false
		scd = false
	end)

	if self.rings >= -1 then
		if self.input.button_press.super_action then
			if script.IsSuper.Value == false then
				if charval.Value == "Sonic" then
					if plrrings > 49 and not self.scd then 
						script.IsSuper.Value = true
						remote:FireServer("SuperOn")
						self.scd = true
						print("Can Super.")

						self.state = constants.state.inactive
						local anim = game.Players.LocalPlayer.Character.Humanoid.Animator:LoadAnimation(script.Transformanim)
						if self.animation_tracks[self.animation] then
							--self.animation_tracks[self.animation]:Stop(0)
							self.animation_tracks[self.animation]:Play(0)
							anim:Play()
						--if self.animation_tracks[self.animation] then
							--self.animation_tracks[self.animation]:Stop(0)
						--end

						--local transformAnimation = Instance.new("Animation")
						--transformAnimation.AnimationId = "rbxassetid://87737086801684" -- your transformation animation ID
						--local anim = char1.Humanoid.Animator:LoadAnimation(transformAnimation)
						--anim:Play()
						--anim.Priority = Enum.AnimationPriority.Action 

						script.Sounds.SuperEnable:Play()
						task.delay(1, function()
							--anim:Stop() 
						end)
						task.delay(0.5, function()
							wait(0.5)
							script.Sounds.SuperCharge:Play()

							-- Activar las partículas del Attachment "SCharge"
							local sChargeAttachment = self.hrp:FindFirstChild("SCharge")
							if sChargeAttachment then
								for _, particle in pairs(sChargeAttachment:GetDescendants()) do
									if particle:IsA("ParticleEmitter") then
										particle.Enabled = true
									end
								end

								-- Desactivar las partículas después de 2 segundos
								task.delay(2, function()
									for _, particle in pairs(sChargeAttachment:GetDescendants()) do
										if particle:IsA("ParticleEmitter") then
											particle.Enabled = false
										end
									end
								end)
							end

							issuper = true
							remote:FireServer("SuperOn")
							local charinfo = require(self.char:FindFirstChild("CharacterInfo"))
							if charinfo and charinfo.physics then
								local physics = charinfo.physics
								physics.scale = 0.455
								physics.jump2_timer = 60
								physics.pos_error = 2
								physics.lim_h_spd = 16
								physics.lim_v_spd = 16
								physics.max_x_spd = 3
								physics.max_psh_spd = 0.6
								physics.jmp_y_spd = 1.66
								physics.nocon_spd = 3
								physics.slide_speed = 0.23
								physics.jog_speed = 0.46
								physics.run_speed = 1.39
								physics.rush_speed = 2.3
								physics.crash_speed = 3.7
								physics.dash_speed = 5.09
								physics.jmp_addit = 0.076
								physics.run_accel = 0.05
								physics.air_accel = 0.05
								physics.slow_down = -0.06
								physics.run_break = -0.18
								physics.air_break = -0.17
								physics.air_resist_air = -0.002
								physics.air_resist = -0.001
								physics.air_resist_y = -0.01
								physics.air_resist_z = -0.4
								physics.grd_frict = -0.1
								physics.grd_frict_z = -0.6
								physics.lim_frict = -0.2825
								physics.rat_bound = 0.3
								physics.rad = 4
								physics.height = 10
								physics.weight = 0.08
								physics.eyes_height = 7
								physics.center_height = 5.4
							end
							local charinfo = require(self.char:FindFirstChild("CharacterInfo"))
							if charinfo and charinfo.physics then
								local physics = charinfo.physics
								-- Physical properties adjustments...
							end
							--self.animation_tracks[self.animation]:Stop(0)
							--animation.UnloadAnimations(self)
							--animation.LoadAnimations(self, game.ReplicatedStorage.Assets.SuperSonic.Animations)
							--self.prev_animation = "Run"
							--self.animation = "Idle"
							--self.animation_tracks[self.animation]:Play(0)
							self.state = constants.state.idle
							self.shield = self.shield

							while wait(1) do
								if issuper then
									self.rings = self.rings - 1
								end
								if self.rings <= 0 then
									script.IsSuper.Value = false
									self.scd = false
									print("Bye Super.")
									script.Sounds.SuperMusic:Pause()

									-- Activar el Attachment "SCharge" en SuperOff
									if sChargeAttachment then
										for _, particle in pairs(sChargeAttachment:GetDescendants()) do
											if particle:IsA("ParticleEmitter") then
												particle.Enabled = true
											end
										end

										-- Desactivar las partículas después de 2 segundos
										task.delay(2, function()
											for _, particle in pairs(sChargeAttachment:GetDescendants()) do
												if particle:IsA("ParticleEmitter") then
													particle.Enabled = false
												end
											end
										end)
									end

									-- Reproducir animación de transformación al desactivarse SuperOff
									local superOffAnimation = Instance.new("Animation")
									superOffAnimation.AnimationId = "rbxassetid://87737086801684" -- your transformation animation ID
									local animOff = char1.Humanoid.Animator:LoadAnimation(superOffAnimation)
									animOff:Play()
									animOff.Priority = Enum.AnimationPriority.Action 

									task.delay(1, function()
										animOff:Stop()
									end)

									issuper = false
									remote:FireServer("SuperOff")
									local charinfo = require(self.char:FindFirstChild("CharacterInfo"))
									if charinfo and charinfo.physics then
										local physics = charinfo.physics
										physics.scale = 0.455
										physics.jump2_timer = 60
										physics.pos_error = 2
										physics.lim_h_spd = 16
										physics.lim_v_spd = 16
										physics.max_x_spd = 3
										physics.max_psh_spd = 0.6
										physics.jmp_y_spd = 1.66
										physics.nocon_spd = 3
										physics.slide_speed = 0.23
										physics.jog_speed = 0.46
										physics.run_speed = 1.39
										physics.rush_speed = 2.3
										physics.crash_speed = 3.7
										physics.dash_speed = 5.09
										physics.jmp_addit = 0.076
										physics.run_accel = 0.05
										physics.air_accel = 0.031
										physics.slow_down = -0.06
										physics.run_break = -0.18
										physics.air_break = -0.17
										physics.air_resist_air = -0.028
										physics.air_resist = -0.008
										physics.air_resist_y = -0.01
										physics.air_resist_z = -0.4
										physics.grd_frict = -0.1
										physics.grd_frict_z = -0.6
										physics.lim_frict = -0.2825
										physics.rat_bound = 0.3
										physics.rad = 3
										physics.height = 5
										physics.weight = 0.08
										physics.eyes_height = 7
										physics.center_height = 5.4
									end
									local charinfo = require(self.char:FindFirstChild("CharacterInfo"))
									if charinfo and charinfo.physics then
										local physics = charinfo.physics
										-- Restore original physical properties...
									end
									--self.animation_tracks[self.animation]:Stop(0)
									--animation.UnloadAnimations(self)
									--animation.LoadAnimations(self, game.ReplicatedStorage.Assets.Sonic.Animations)
									--self.prev_animation = "Run"
									--self.animation = "Idle"
									--self.animation_tracks[self.animation]:Play(0)
									self.shield = false
									break
								end
							end
						end)
end
						return false
					end
				end
			end
		end
	end
end
--]]

								--]]
local function CheckLightSpeedDash(self, object_instance)
	--Check for light speed dash
	self.secondary_action = "LightSpeedDash"
	if self.input.button_press.secondary_action and lsd.CheckStartLSD(self, object_instance) then
		--Start light speed dash
		self.animation = "LSD"
		self.state = constants.state.light_speed_dash
		self:ExitBall()
		self:ResetObjectState()
		return true
	end
	return false
end

local function CheckHomingAttack(self, object_instance)

	--Check for homing attack
	local charval = game.Players.LocalPlayer.Character.CharValue
	local isshadow = charval.Value == "Shadow"
	if self.flag.ball_aura then
		self.jump_action = "HomingAttack"
		if self.input.button_press.jump then
			--if not issuper then
			if homing_attack.CheckStartHoming(self, object_instance) then
				--Homing attack
				self.animation = "Roll"
				self:EnterBall()
			else
				if ledge.Check(self) then
				return
				else
				--Jump dash
				if workspace.Level.NewStuff.CanAirDash.Value == true then

					self.spd = vector.SetX(self.spd, game.Players.LocalPlayer.Character.AirDashPower.Value)
					self.animation = "Fall"
					self:ExitBall()
					self.flag.dash_aura = true
					sound.PlaySound(self, "Dash")
				end
			end
end
			--Enter homing attack state
			self.state = constants.state.homing
			self.homing_timer = 0
			sound.PlaySound(self, "Dash")


			if isshadow then
				self.snapfx = self.hrp:WaitForChild("ChaosSnap")
				--Check for homing attack
				if self.flag.ball_aura then
					self.jump_action = "HomingAttack"
					if self.input.button_press.jump then
						if homing_attack.CheckStartHoming(self, object_instance) then
							--Chaos Snap
							self.animation = "ChaosSnap"
							self.state = constants.state.stop
							for i,v in self.snapfx:GetDescendants() do
								if v:IsA("ParticleEmitter") then
									v:Emit(1)
								end
							end

							sound.PlaySound(self, "Snap")
							task.delay(0.15, function()
								self.flag.ball_aura = true
								self.state = constants.state.airborne
								self.pos = self.homing_obj.root.Position
								self.animation = "Fall"
							end)
						else
							--Jump dash
							self.spd = vector.SetX(self.spd, 10)
							self.animation = "Fall"
							self:ExitBall()
							self.flag.dash_aura = true
							sound.PlaySound(self, "Dash")
							self.state = constants.state.homing
							self.homing_timer = 0
							return true
						end

					end
				end
			end
		end
	end
end
--end

local function CheckDash(self)
	--Check for dash
	self.dash_action = "Dash"
	if self.input.button_press.dash then
		--Dash
		self.state = constants.state.dash
		camShake:Shake(CameraShaker.Presets.Boost)
		self.spd = vector.SetX(self.spd, self.p.dash_ability)
		sound.PlaySound(self, "SpindashRelease")
		return true
	end
	return false
end

local function CheckBounce(self)
	local charval = game.Players.LocalPlayer.Character.CharValue
	--Check for bounce
	if self.flag.ball_aura then
		self.roll_action = "Bounce"
		if self.input.button_press.roll then
			local istails = charval.Value == "Tails"
			local isknuckles = charval.Value == "Knuckles"
			local issilver = charval.Value == "Silver"
			if not istails then
				if not isknuckles then
					
					--Bounce
					self.state = constants.state.bounce
					--self.air_kick_timer = istails and 60 or 50 
					self.animation = "Roll"
					--self.spd = vector.MulX(self.spd, 0.75)
					if self.flag.bounce2 == true then
						self.spd = vector.SetY(self.spd, -7)
					else
						self.spd = vector.SetY(self.spd, -5)
					end
					self.anim_speed = -self.spd.Y
					return true
					end
					--[[Silver
					if issilver then
						if self.boost_charge >= -1 then
							sound.PlaySound(self, "Float_activate")
							sound.PlaySound(self, "Float_dash")
							sound.PlaySound(self, "Float_move")
						self.state = constants.state.float
						self:ExitBall()
						self.boost_charge -= 5
						if input.GetAnalogue_Mag(self) <= 0 then
							self.animation = "Float"
								
							--self.spd = vector.SetY(self.spd, 0)
							self.air_kick_timer = 600000000000000
							--sound.PlaySound(self, "Glide")
						else
							self.animation = "Float"
								sound.PlaySound(self, "Float_move")
							--self.spd = vector.SetY(self.spd, 0)
							self.air_kick_timer = 120000000000000
							if self.input.roll == false then
								self.state = constants.state.airborne
								if self.boost_charge == 0 then
									self.state = constants.state.airborne
							return true
								end
								
				    end
			    end
		     end
				--KnucklesGlide
				--]]if isknuckles then
					self.state = constants.state.air_kick
					self:ExitBall()
					if input.GetAnalogue_Mag(self) <= 0 then
						self.animation = "AirKick"
						self.spd = vector.SetX(self.spd, 6)
						self.air_kick_timer = 600000000000000
						sound.PlaySound(self, "Glide")
					else
						self.animation = "AirKick"
						self.spd = vector.SetX(self.spd, 6)
						self.air_kick_timer = 120000000000000

						return true
					end
					--TailsFlight
					if istails then
								if self.boost_charge >= -1 then
								self.state = constants.state.flight
						--self.air_kick_timer = 60
						--self.animation = "AirKickUp"
						self.flag.ball_aura = false
						self.spd = vector.SetY(self.spd, 3)
						sound.PlaySound(self, "Flying")  
						task.spawn(function()
							task.wait(0.3)
							sound.StopSound(self, "Flying")
							self.flag.ball_aura = true                
							return true
						end)
						

						if workspace.Level.NewStuff.Dropdash.Value == true and workspace.Level.NewStuff.Airboost.Value == false then
							self.state = constants.state.dropcharging
							sound.StopSound(self, "Dropdash")
							sound.PlaySound(self, "Dropdash")
							constants.state.dropdashcharging = true		
							self:EnterBall()
						end
						if workspace.Level.NewStuff.Boost.Value == true and workspace.Level.NewStuff.Dropdash.Value == false then
							self.state = constants.state.airboost
							self.spd = vector.SetX(self.spd, workspace.Level.NewStuff.AirboostPower.Value)
							self.animation = "Mach"
							self:ExitBall()
							self.animation = "Mach"
							sound.PlaySound(self, "Airboost")
							camShake:Shake(CameraShaker.Presets.Boost)
							self.state = constants.state.airborne
						end

						if workspace.Level.NewStuff.Airboost.Value == true and workspace.Level.NewStuff.Dropdash.Value == false then
							self.state = constants.state.airboost
							self.spd = vector.SetX(self.spd, workspace.Level.NewStuff.AirboostPower.Value)
							self.animation = "Attack3"
							self:ExitBall()
							self.animation = "Attack3"
							sound.PlaySound(self, "Airboost")
							camShake:Shake(CameraShaker.Presets.Boost)
							self.state = constants.state.airborne

						end
					end
					return false
				end
			end
		end
	end
	end
	end
	
	
local function CheckAirKick(self)
	local charval = game.Players.LocalPlayer.Character.CharValue
	local issilver = charval.Value == "Silver"
	local issuper = charval.Value == "Super"
	
	
		if self.flag.air_kick then
			self.tertiary_action = "AirKick"
			if self.input.button_press.tertiary_action then
			
				--Air kick
				self:GiveScore(0)
				self.state = constants.state.air_kick
				self:ExitBall()
				if input.GetAnalogue_Mag(self) <= 0 then
					self.animation = "AirKickUp"
					self.spd = Vector3.new(1.5, 3, 0)
					self.air_kick_timer = 35
					--self.p.run_speed += 0.0175
					sound.PlaySound(self, "Jump 2")
				else

					self.animation = "AirKickUp"
					self.spd = vector.SetY(self.spd, 2.6)
					--self.p.run_speed += 0.0175
					self.air_kick_timer = 25
					sound.PlaySound(self, "Jump 2")
					
				if charval.Value == "Super" then
					
					--Air kick
					self:GiveScore(0)
					self.state = constants.state.air_kick
					self:ExitBall()
					if input.GetAnalogue_Mag(self) <= 0 then
						self.animation = "AirKickUp"
						self.spd = Vector3.new(1.5, 3, 0)
						self.air_kick_timer = 35
						--self.p.run_speed += 0.0175
						sound.PlaySound(self, "Jump 2")
					else

						self.animation = "AirKickUp"
						self.spd = vector.SetY(self.spd, 3.2)
						--self.p.run_speed += 0.0175
						self.air_kick_timer = 27
						end
				   end
				end
			return true
		end
	end
	return false
end




local function CheckBackwardsAirKick(self)
	--Check for air kick

	if self.flag.air_kick then
		self.tertiary_action2 = "AirKick"
		if self.input.button_press.tertiary_action3 then
			--Air kick
			self:GiveScore(200)
			self.state = constants.state.air_kick
			self:ExitBall()
			if input.GetAnalogue_Mag(self) <= 0 then
				self.animation = "AirKickUp"
				self.spd = Vector3.new(0.2, 2.65, 0)
				self.air_kick_timer = 60
			else
				self.animation = "AirKick"
				self.spd = Vector3.new(-2.5, 1.425, 0)
				self.air_kick_timer = 120
			end
			return true
		end
	end
	return false
end

local function CheckSkid(self)
	local has_control, analogue_turn, _ = input.GetAnalogue(self)
	if has_control then
		return math.abs(analogue_turn) > math.rad(135)
	end
	return false
end

local function CheckStopSkid(self)
	if self.spd.X <= 0.01 then
		--We've stopped, stop skidding
		self.spd = vector.SetX(self.spd, 0)
		return true
	else
		--If holding forward, stop skidding
		local has_control, analogue_turn, _ = input.GetAnalogue(self)
		if has_control then
			return math.abs(analogue_turn) <= math.rad(135)
		end
		return false
	end
end

local function CheckStartWalk(self)
	local has_control, _, _ = input.GetAnalogue(self)
	if has_control or math.abs(self.spd.X) > self.p.slide_speed then
		if self.state == constants.state.crouch then
			self.state = constants.state.crawl
		else
			self.state = constants.state.walk
		end
		return true
	end
	return false
end

local function CheckStopWalk(self)
	local has_control, _, _ = input.GetAnalogue(self)
	if has_control or math.abs(self.spd.X) > 0.01 then
		return false
	end

	self.state = constants.state.idle
	return true
end
local OverwrittenFunctions = {}
local OriginalFunctions = {}

function Mod_OverwriteFunction(FunctionName, NewFunction, Mode)
	local CurrentEnv = getfenv(1)
	local OldFunction = CurrentEnv[FunctionName]

	if OldFunction then
		if not OverwrittenFunctions[FunctionName] then
			OverwrittenFunctions[FunctionName] = NewFunction
			OriginalFunctions[FunctionName] = OldFunction
		else
			OldFunction = OriginalFunctions[FunctionName]
			CurrentEnv[FunctionName] = OldFunction

			OverwrittenFunctions[FunctionName] = NewFunction
			OriginalFunctions[FunctionName] = OldFunction
		end

		local Before = Mode == "Before"
		local Overwrite = Mode == "Overwrite"
		if Overwrite then
			CurrentEnv[FunctionName] = NewFunction
		else
			CurrentEnv[FunctionName] = function(...)
				local ret_args = nil
				if Before then
					ret_args = NewFunction(...)
				end

				local n_args = OldFunction(...)

				if not ret_args then
					ret_args = n_args
				end

				if not Before then -- After
					local f_args = NewFunction({ret_args}, ...)

					if not ret_args then
						ret_args = f_args
					end
				end

				return ret_args
			end
		end

		setfenv(1, CurrentEnv)
	end

	return OldFunction, NewFunction
end

local function CheckMoves(self, object_instance)
	if self.do_ragdoll then
		self.state = constants.state.ragdoll
		self.do_ragdoll = false
		return true
	end
	local function stomp()
		if self.input.button_press.stomp then
			self:ExitBall()
			self.animation = "Fall2"
			self.spd = vector.SetY(self.spd, -5)
		end
	end

	--local function summer()
		--if self.input.button_press.summer then
			--self.animation = "AirKickUp"
			--self:ExitBall()
			--self.spd = vector.SetX(self.spd, 5)
		--end
	--end

	return switch(self.state, {}, {
		[constants.state.jump_pad] = function()
			return CheckJump(self)
		end,
		[constants.state.idle] = function()
			return CheckLightSpeedDash(self, object_instance) or CheckJump(self) or CheckSpindash(self) or CheckStartWalk(self) or CheckCrawlCrouch(self) --or CheckSuper(self)
		end,
		[constants.state.walk] = function()
			if CheckLightSpeedDash(self, object_instance) or CheckJump(self) or CheckBoost(self) or CheckSpindash(self) or CheckStopWalk(self) or CheckCrawlCrouch(self) or CheckDash(self) --[[or CheckSuper(self) --]]then
				return true
			else

				--Check if we should start skidding
				if self.spd.X > self.p.jog_speed and CheckSkid(self) then
					--Start skidding
					self.state = constants.state.skid
					sound.PlaySound(self, "Skid")
					return true

				end
			end
			return false
		end,
		[constants.state.crawl] = function()
			if CheckJump(self) then
				return true
			else
				if self.input.button.tertiary_action then
					self.state = constants.state.crawl
					self.p.height = 2.5
				else
					self.state = constants.state.walk
				end
			end
			return false
		end,
		[constants.state.slide] = function()
    -- Check if the player attempts to jump during the slide
    if CheckJump(self) then
        return true
    else
        -- Enter the slide state
        self.state = constants.state.slide
        self.spark_effect:Emit(1) -- Emit particles for the slide effect
        
        -- Adjust sliding speed and mechanics for anti-gravity effect
        local anti_gravity_factor = 0.98 -- Scale speed to simulate gliding
        self.slide_speed = self.slide_speed * anti_gravity_factor

        -- Set animation and player height
        self.animation = "Slide"
        self.p.height = 3 -- Adjust for low-profile sliding

        -- Transition to walking state if speed is too low
        if self.slide_speed <= 0.25 then
            self.state = constants.state.walk
            self.animation = "Walk"
        end

        -- Transition to airborne state if ungrounded
        if not self.flag.grounded then
            self.state = constants.state.airborne
            self.animation = "Fall"
        end
    end
end,
		[constants.state.crouch] = function()
			if CheckJump(self) or CheckSpindash(self) or CheckStartWalk(self) then
				return true
			else
				if self.input.button.tertiary_action then
					self.state = constants.state.crawl
					self.animation = "CrawlIdle"
					self.p.height = 3
				else
					self.state = constants.state.idle
				end
			end

			return false
		end,
		
		[constants.state.skid] = function()
			if CheckLightSpeedDash(self, object_instance) or CheckJump(self) or CheckSpindash(self)or CheckPeelout(self)  then
				return true
			else
				--Check if we should stop skidding
				if CheckStopSkid(self) then
					--Stop skidding
					self.state = GetWalkState(self)
					return true
				end
			end
			return false
		end,
		[constants.state.boost] = function()
			if CheckJump(self) or CheckLightSpeedDash(self) or CheckStopWalk(self) then
				return true
			else
				if not self.input.button.boost or self.boost_charge <= 0 then
					self.state = constants.state.walk
					sound.StopSound(self, 'Boost')
					sound.StopSound(self, 'BoostWind')
					sound.StopSound(self, 'BoostExtra')
					return true
				end
			end
		end,
		[constants.state.roll] = function()
			if CheckLightSpeedDash(self, object_instance) or CheckJump(self) or CheckUncurl(self) then
				return true
			else
				if self.spd.X < self.p.run_speed then
					if self.flag.ceiling_clip then
						--Force us to keep rolling
						self.spd = vector.SetX(self.spd, self.p.run_speed)
					else
						--Uncurl if moving too slow
						self.state = GetWalkState(self)
						self:ExitBall()
						return true
					end
				end
			end
			return false
		end,
		[constants.state.spindash] = function()
			local charval = game.Players.LocalPlayer.Character.CharValue
			local isshadow = charval.Value == "Shadow"
			local isuper = charval.Value == "Super"

			-- Check for Light Speed Dash
			if CheckLightSpeedDash(self, object_instance) then
				return true
			else

			-- Check if Boost is disabled
			if not workspace.Level.NewStuff.Boost.Value then
				self.roll_action = "Spindash"

				if self.input.button.roll then
					self:EnterBall()

					-- Increase spindash speed
					local max_speed = isuper and 11.25 or 10 -- Set max speed based on character
					local speed_increment = isuper and 0.1125 or 0.225 -- Increment for Super and normal

					if self.spindash_speed < max_speed or self.v3 then
						self.spindash_speed += ((self.v3 and 0.1) or 0.4)

						task.delay(0.85, function()
							if self.input.button.roll and self.boost_charge > 0 then
								self.boost_charge = math.max(self.boost_charge - 0.75, 0) -- Prevent negative charge
								self.spindash_speed = math.min(self.spindash_speed + speed_increment, max_speed) -- Cap spindash speed
							end
						end)
					end
				else
					-- Release spindash
					workspace.Level.MusicFolder.Music.Boosting.Enabled = false
					self:ExitBall()
					sound.StopSound(self, "SpindashCharge")
					self.state = constants.state.roll
					self:EnterBall()
					self.spd = vector.SetX(self.spd, self.spindash_speed)
					sound.PlaySound(self, "SpindashRelease")
					return true
				end
			end

			return false
			end
		end,
		[constants.state.peelout] = function()
			if CheckLightSpeedDash(self, object_instance) then
				return true
			else
				self.roll_action = "Spindash"
				if self.input.button.peelout then
					--Increase spindash speed
					if self.spindash_speed < 10 or self.v3 == true then
						self.spindash_speed += ((self.v3 == true) and 0.1 or 0.4)
					end
				else
					--Release spindash
					workspace.Level.MusicFolder.Music.Boosting.Enabled = false
					self.state = constants.state.walk
					self.spd = vector.SetX(self.spd, self.spindash_speed)
					sound.StopSound(self, "SpindashCharge")
					sound.PlaySound(self, "SpindashRelease")
					workspace.Level.MusicFolder.Music.Boosting.Enabled = false
					return true
				end
			end
			return false
			
		end,
		[constants.state.airborne] = function()
			return CheckLightSpeedDash(self, object_instance) or CheckHomingAttack(self, object_instance) or CheckBounce(self) or CheckAirKick(self)  or stomp(self)
		end,
		
		
		[constants.state.homing] = function()
			if self.homing_obj == nil then
				if CheckLightSpeedDash(self, object_instance) then
					return true
				end
			else
				self.jump_action = "Jump"
			end
			return false
		end,
		[constants.state.bounce] = function()
			self.roll_action = "Bounce"
			return CheckLightSpeedDash(self, object_instance) or CheckHomingAttack(self, object_instance)
		end,
		[constants.state.light_speed_dash] = function()
			self.secondary_action = "LightSpeedDash"
			return false
		end,
		[constants.state.air_kick] = function()
			return CheckLightSpeedDash(self, object_instance)
		end,
		[constants.state.charge] = function()
			if self.rings > 99 then
				task.delay(3, function()
					self.state = constants.state.inactive
				end)
				self.state = constants.state.charge
			self.animation = "Charge"
			
			end
		end,
		[constants.state.rail] = function()
			--mark2
			--local function CheckRailGrind(self)
			self.jump_action = "Jump"
			self.tertiary_action = "Grind"
			self.roll_action = "Crouch"
			if self.input.button_press.tertiary_action then
				self.animation = "RailGrind"
				
						
					
				end
			
			
			if self.input.button_press.jump then
				if rail.CheckSwitch(self) then
					--Rail switch jump
					sound.PlaySound(self, "Jump")
					return true
				elseif rail.CheckTrick(self) then
					--Trick jump
					sound.PlaySound(self, "Jump")
					return true
				else
					--Normal jump
					return CheckJump(self)
					
				end
				
			end
			return false
		end,
	}) or false
end

--Player update
local admins = {
	[103205204] = true, --Telandis08
}

local newcamera = workspace:WaitForChild("CameraLock")
function player:Update(object_instance, dt)
	debug.profilebegin("player:Update")

	if self.character and self.character:FindFirstChild("HumanoidRootPart") then
		self.character.HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(0,0,0)
		self.character.HumanoidRootPart.AssemblyAngularVelocity = Vector3.new(0,0,0)
	end
	--self.camera = lerp_camera:New(self)
	--self.camera:Destroy()
	--self.camera:Update()
	--Update input
	
	self.dt = dt

	local old_cam = self.prev_testing_cam

	

	
	
	local env = {} -- initial environments
	local env_maps = {0, 1, 2}

	for i,v in pairs(env_maps) do
		local c_env = getfenv(v)
		for i,v in pairs(c_env) do
			if not env[i] then
				env[i] = v
			end
		end
	end
	local function UpdateMods(table, funcind)
		funcind = funcind or "Update"
		for i,v in pairs(table) do
			if v[funcind] then
				task.spawn(function()
					v[funcind](self, v, dt, sound, object_instance, env) -- Prevent bad code from haulting the thread
				end)
			end
		end
	end

	UpdateMods(self.mods, "UpdateBeforeInput")
	input.Update(self)
	--Update input
	plane_lock.Update(self)  
	ledge_climb.Update(self)
	sg.Update(self) 
	camera.Update(self, dt)
	UpdateMods(self.mods_early)
	
	
	
	--Debug input
	if admins[game:GetService("Players").LocalPlayer.UserId] then
		
		if self.input.button_press.dbg then
			self.gravity = -self.gravity
			self.flag.grounded = false
			self:SetAngle(self.ang * CFrame.Angles(math.pi, 0, 0))
			self.spd *= Vector3.new(1, -1, 0)
		end
	end
	
	_jumppadoverlap.FilterDescendantsInstances = _jumpads
	self.upd_dt = dt

	if jumppad_last then
		self.spd = Vector3.new(0,0,0)
		self.state = constants.state.jump_pad
		self.flag.grounded = true
		self.pos = last_jump_pad.Position - (self.vis_ang.UpVector * self:GetCharacterYOff()) + (last_jump_pad.CFrame.RightVector * .5)
		pcall(function()
			local next = last_jump_pad:FindFirstAncestorOfClass("Model"):FindFirstChild("Next").Value :: Instance?

			if next then
				self.cam_override_pos = self.hrp.Position + (self.hrp.CFrame.LookVector * 5)
				workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame:Lerp(CFrame.lookAt(workspace.CurrentCamera.CFrame.Position, next.Position), .15)
			end
		end)

		--self:UpdateCamera()
		self.ang = self:AngleFromRbx(last_jump_pad.CFrame.Rotation * CFrame.Angles(0,math.rad(-90), 0))
		self.animation = "Crouch"

		local diff = os.clock() - jumppad_last

		self.homing_attack_action = "Jump"
		self.jump_action = "Jump"

		if diff >= 1.5 or (self.input.button_press.trickUp) then
			-- drop player
			local old_col = last_jump_pad:FindFirstAncestorOfClass("Model"):WaitForChild("Cylinder.004").Color
			last_jump_pad:FindFirstAncestorOfClass("Model"):WaitForChild("Cylinder.004").Color = Color3.new(1, 0, 0)
			game:GetService("TweenService"):Create(last_jump_pad:FindFirstAncestorOfClass("Model"):WaitForChild("Cylinder.004"), TweenInfo.new(.25), {Color = old_col}):Play()

			jumppad_last = nil
			self.state = constants.state.airborne
			self.animation = "Fall"
			--self.sounds["jumppad_fail"]:Play()
		end
	end
	--[[function player:UpdateBoostCharge()
		if self.rings >= 125 then
			self.boost_charge += 0.0015
			if self.score < 10000 then
				self.boost_charge += 0.01
				if self.score > 10000 then
					self.boost_charge += 0.0005
					if self.score > 20000 then
						self.boost_charge += 0.0005
						-- Add other conditions here
						local charval = game.Players.LocalPlayer.Character.CharValue
						if charval.Value == "Super" then 
							self.boost_charge -= 0.04

							if self.rings >= 25 then
								self.boost_charge += 0.0015

								if self.rings >= 50 then
									self.boost_charge += 0.002

									if self.rings >= 75 then
										self.boost_charge += 0.00215

										if self.rings >= 99 then
											self.boost_charge += 0.0055

											if self.rings >= 125 then
												self.boost_charge += 0.0015
											end
										end
									end
								end
							end
						end
					end

				end
			end
		end
	end
	]]
	if self.score < 10000 then
	self.boost_charge += 0.01
	end
	if self.score > 10000 then
		self.boost_charge += 0.0005
	end
	if self.score > 20000 then
		self.boost_charge += 0.0005
	end
	
	local charval = game.Players.LocalPlayer.Character.CharValue
	if charval.Value == "Super" then 
		self.boost_charge -= 0.04
		
		if self.rings >= 25 then
			self.boost_charge += 0.0015
		end
		if self.rings >= 50 then
			self.boost_charge += 0.002
		end
		if self.rings >= 75 then
			self.boost_charge += 0.00215
		end
		if self.rings >= 99 then
			self.boost_charge += 0.0055
			end
			if self.rings >= 125 then
				self.boost_charge += 0.0015
		
			end
			end
		if admins[game:GetService("Players").LocalPlayer.UserId] then
			if charval.Value == "Super" then 
				self.boost_charge += 0.028
			end
		end
	
	--markRETURN


	--Handle power-ups
	self.invincibility_time = math.max(self.invincibility_time - 1, 0)
	self.speed_shoes_time = math.max(self.speed_shoes_time - 1, 0)

	if self.invincibility_time > 0 then
		self.music_id = string.sub(invincibility_theme.SoundId, 14)
		self.music_volume = invincibility_theme.Volume
	elseif self.speed_shoes_time > 0 then
		self.music_id = string.sub(speed_shoes_theme.SoundId, 14)
		self.music_volume = speed_shoes_theme.Volume
	else
		self.music_id = self.level_music_id
		self.music_volume = self.level_music_volume
	end

	--Shield idle abilities
	switch(self.shield, {}, {
		["Shield"] = function()

		end,
		["MagnetShield"] = function()
			--Get attracting rings
			local attract_range = 35
			local attract_region = Region3.new(self.pos - Vector3.new(attract_range, attract_range, attract_range), self.pos + Vector3.new(attract_range, attract_range, attract_range))
			local rings = object_instance:GetObjectsInRegion(attract_region, function(v)
				return v.class == "Ring" and v.collected ~= true and v.attract_player == nil
			end)

			--Attract rings
			for _,v in pairs(rings) do
				if (v.root.Position - self.pos).magnitude < attract_range then
					v:Attract(self)
				end
			end

			--Disappear when underwater
			if self.flag.underwater then
				self.shield = nil
			end
		end,
	})

	--Reset per frame state
	self.last_turn = 0

	--Handle player moves
	self.jump_action = nil
	self.roll_action = nil
	self.secondary_action = nil
	self.tertiary_action = nil

	if not self:Scripted() then
		CheckMoves(self, object_instance)
	end

	--Water drag
	if self.v3 ~= true and self.flag.underwater then
		if self.state == constants.state.roll then
			self.spd = vector.AddX(self.spd, self.spd.X * -0.06)
		else
			self.spd = vector.AddX(self.spd, self.spd.X * -0.03)
		end
	end

	--Handle timers
	if self.spring_timer > 0 then
		self.spring_timer -= 1
		if self.spring_timer <= 0 then
			self.spring_timer = 0
			self.flag.scripted_spring = false
		end
	end

	if self.invulnerability_time > 0 and self:IsBlinking() then
		self.invulnerability_time = math.max(self.invulnerability_time - 1, 0)
	end

	if self.dashpanel_timer > 0 then
		self.dashpanel_timer = math.max(self.dashpanel_timer - 1, 0)
	end

	if self.dashring_timer > 0 then
		self.dashring_timer = math.max(self.dashring_timer - 1, 0)
	end

	if self.rail_debounce > 0 then
		self.rail_debounce = math.max(self.rail_debounce - 1, 0)
	end

	if self.rail_trick > 0 then
		self.rail_trick = math.max(self.rail_trick - 0.015, 0)
	end
	--Run character state
	switch(self.state, {}, {
		[constants.state.idle] = function()
			--self.ball_trail:Disable()
			if workspace.Level.MusicFolder:FindFirstChild("Music") ~= nil then
				workspace.Level.MusicFolder.Music.Boosting.Enabled = false
			end
			self.p.height = 5
			if workspace.Level.NewStuff.Started.Value == false then
				self.state = constants.state.inactive
			end

			--Movement and collision
			movement.GetRotation(self)
			movement.RotatedByGravity(self)
			acceleration.GetAcceleration(self)
			collision.Run(self)

			if not rail.CollideRails(self) then
				if not self.flag.grounded then
					--Ungrounded
					self.state = constants.state.airborne
					self.animation = "Fall"

				else
					--Set animation
					if self.animation ~= "Land" then
						self.animation = "Idle"
					end
				end
			end
			self.tertiary_action = "Slide"
			if self.input.button_press.tertiary_action then
				self.state = constants.state.slide
			end
			if self.state == constants.state.slide then
				if self.input.button_press.tertiary_action then
					self.animation = "Kick"
				end
			end
		end,
		[constants.state.crouch] = function()
			--Movement and collision
			movement.RotatedByGravity(self)
			collision.Run(self)
			if self.spd.X > 0.25 then
				self.state = constants.state.walk
			end
			if not rail.CollideRails(self) then
				if not self.flag.grounded then
					--Ungrounded
					self.state = constants.state.airborne
					self.animation = "Fall"
				else
					--Set animation
					if self.animation ~= "Land" then
						self.animation = "Idle"
					end
				end
			end
		end,
		[constants.state.slide] = function()
			-- Handle movement, rotation, and collision
			movement.GetRotation(self)
			movement.GetInertia(self)
			collision.Run(self)

			-- Check for air kick or other actions
			if self.flag.air_kick ~= false then
				self.tertiary_action = "Slide"

				if self.input.button_press.tertiary_action then
					self.state = constants.state.slide

					-- Check for rail collision
					if not rail.CollideRails(self) then
						-- Transition to airborne state if ungrounded
						if not self.flag.grounded then
							self.state = constants.state.airborne
							self.animation = "Fall"
						else
							-- Apply anti-gravity sliding mechanics
							self.animation = "Slide"

							local slip_factor = math.sqrt(self.frict_mult) * 0.5 -- Reduced friction for smooth sliding
							local acc_factor = math.min(math.abs(self.spd.X) / self.p.crash_speed, 1)
							self.anim_speed = lerp(self.spd.X / slip_factor + (1 - slip_factor) * 2, self.spd.X, acc_factor)

							-- Gradually reduce speed for a gliding effect
							self.spd = vector.SetX(self.spd, self.spd.X * 0.98)
						end
					end
				end
			end
		end,
		[constants.state.spinkick] = function()
			-- Handle rotation and inertia (spinning in place)
			movement.GetRotation(self)
			movement.GetInertia(self)

			-- Transition into the Spin Kick state
			if self.input.button_press.tertiary_action then
				self.state = constants.state.spinkick
				self.animation = "SpinKick" -- Set the Spin Kick animation

				-- Apply spin visuals (particles, effects, etc.)
				self.spin_effect:Emit(10) -- Emit spinning particles for visual effect

				-- Apply radial damage to nearby enemies
				local attack_radius = 5 -- Radius of the Spin Kick's area of effect
				local attack_power = 10 -- Damage inflicted by the Spin Kick
				local enemies = game.Workspace:FindPartsInRegion3(
					Region3.new(
						self.p.Position - Vector3.new(attack_radius, attack_radius, attack_radius),
						self.p.Position + Vector3.new(attack_radius, attack_radius, attack_radius)
					),
					nil, -- No specific part whitelist
					10 -- Max number of parts to check
				)
				for _, enemy in ipairs(enemies) do
					if enemy:IsA("Humanoid") and enemy.Parent ~= self.Character then
						enemy:TakeDamage(attack_power) -- Inflict damage on enemies
					end
				end

				-- Apply slight forward movement for the spinning effect
				self.spd = vector.SetX(self.spd, self.spd.X * 0.9)
				self.spd = vector.SetZ(self.spd, self.spd.Z * 0.9)

				-- Exit Spin Kick state after a short duration or when grounded
				local spin_duration = 1.5 -- Duration of the Spin Kick in seconds
				task.delay(spin_duration, function()
					if self.state == constants.state.spinkick then
						self.state = constants.state.walk
						self.animation = "Walk"
					end
				end)

				-- Transition to airborne state if ungrounded
				if not self.flag.grounded then
					self.state = constants.state.airborne
					self.animation = "Fall"
				end
			end
		end,
		
		[constants.state.crawl] = function()
			--Movement and collision
			acceleration.GetAcceleration(self)
			collision.Run(self)
			if not rail.CollideRails(self) then
				if not self.flag.grounded then
					--Ungrounded
					self.state = constants.state.airborne
					self.animation = "Fall"
				else
					--Set animation
					if self.spd.X > 0.1 then
						self.animation = "Crawl"
					else
						self.animation = "CrawlIdle"
					end

					local slip_factor = math.sqrt(self.frict_mult)
					local acc_factor = 1
					self.anim_speed = lerp(self.spd.X / slip_factor + (1 - slip_factor) * 2, self.spd.X, acc_factor)
				end
			end
		end,
		[constants.state.walk] = function()
			if self.character:FindFirstChild("FloatAura") then
				self.character:FindFirstChild("FloatAura"):Destroy()
				sound.StopSound(self, "Float_activate")
				sound.StopSound(self, "Float_dash")
				sound.StopSound(self, "Float_move")
			end
			-- Movement and collision
			acceleration.GetAcceleration(self)
			self.flag.boost_active = false
			collision.Run(self)
			
			if CheckStartWalk(self) then
				if self.spd.X > 0.07 then
				
				if self.spd.X < 0.08 then
					self.spd = vector.SetX(self.spd, 0.2)
				end
	        end
	    end
	
	
			if not rail.CollideRails(self) then
				if not self.flag.grounded then
					-- Ungrounded
					self.state = constants.state.airborne
					self.animation = "Fall"
				else
					-- Set animation
					
					if self.animation ~= "LandRun" then
					self.animation = "Run"

					local slip_factor = math.sqrt(self.frict_mult)
					local acc_factor = math.min(math.abs(self.spd.X) / self.p.crash_speed, 1)
					self.anim_speed = lerp(self.spd.X / slip_factor + (1 - slip_factor) * 2, self.spd.X, acc_factor)
					self.p.height = 5
					self.tertiary_action = "Slide"
					if self.input.button_press.tertiary_action then
						self.state = constants.state.slide
					end
					if self.spd.X > 10 and self.state == constants.state.walk then 
						self.animation = "Mach"
						--	self.state = constants.state.mach
							
					end
					-- RunEffect logic
					if math.abs(self.spd.X) > 6 then -- Check if the player is moving
						-- Ensure the Effects folder and RunEffect exist
local effectsFolder = script:FindFirstChild("Effects")
if not effectsFolder then
    warn("Effects folder not found!")
    return
end

local runEffectTemplate = effectsFolder:FindFirstChild("RunEffect")
if not runEffectTemplate then
    warn("RunEffect not found!")
    return
end

-- Clone the effect and set its parent and position
local effect = runEffectTemplate:Clone()
effect.Parent = workspace
if self.pos then
    effect.Position = self.pos
else
    warn("self.pos is nil, cannot set effect position!")
    return
end

-- Configure particles
for _, particle in pairs(effect:GetDescendants()) do
    if particle:IsA("ParticleEmitter") then
        local originalRate = particle:GetAttribute("OriginalRate") or particle.Rate
        particle:SetAttribute("OriginalRate", originalRate)
        particle.Rate = math.max(1, originalRate * 0.5) -- Reduce particle rate
        particle.Enabled = true
    end
end

-- Handle cleanup
task.spawn(function()
    wait(0.2)
    for _, particle in pairs(effect:GetDescendants()) do
        if particle:IsA("ParticleEmitter") then
            particle.Rate = 0
        end
    end
    wait(2)
    if effect and effect.Parent then
        effect:Destroy()
    end
end)
					end
				end
			end
		end
	end,
		[constants.state.skid] = function()
			--Movement and collision
			movement.GetSkidSpeed(self)
			collision.Run(self)

			if not rail.CollideRails(self) then
				if not self.flag.grounded then
					--Ungrounded
					self.state = constants.state.airborne
					self.animation = "Fall"
				else
					--Set animation and check if should stop skidding
					self.animation = "Skid"
				end
			end
		end,
		[constants.state.spindash] = function()
			if workspace.Level.NewStuff.Boost.Value == true then
				acceleration.GetAcceleration(self)
				collision.Run(self)
				self.jump_action = "Jump"
				CheckJump(self)
				self:EnterBall()
				--nost
				self.jump_action = "Jump"


				self.spd = vector.SetX(self.spd,workspace.Level.NewStuff.BoostPower.Value)



				if not rail.CollideRails(self) then
					if not self.flag.grounded then
						--Ungrounded
						self.state = constants.state.airborne
						self.animation = "Fall"
					else
						--Set animation

						self.animation = "TrickRail4"	
					end
				end

			else
				--Movement and collision
				movement.GetRotation(self)
				movement.GetSkidSpeed(self)
				collision.Run(self)

				if not rail.CollideRails(self) then
					if not self.flag.grounded then
						--Ungrounded
						self.state = constants.state.airborne
						sound.StopSound(self, "SpindashCharge")

						--Set animation
						self.animation = "Roll"
						self.anim_speed = self.spd.magnitude

					else
						--Set animation
						self.animation = "Spindash"
						self.anim_speed = self.spindash_speed
					end
				end
			end
		end,
		[constants.state.peelout] = function()
			--Movement and collision
			movement.GetRotation(self)
			movement.GetSkidSpeed(self)
			collision.Run(self)

			if not rail.CollideRails(self) then
				if not self.flag.grounded then
					--Ungrounded
					self.state = constants.state.airborne
					sound.StopSound(self, "SpindashCharge")

				else

				end
			end
		end,
		[constants.state.roll] = function()
			--Movement and collision
			movement.GetRotation(self)
			movement.GetInertia(self)
			collision.Run(self)

			if not rail.CollideRails(self) then
				if not self.flag.grounded then
					--Ungrounded
					self.state = constants.state.airborne
				end

				--Set animation
				self.animation = "Roll"
				if self.flag.grounded then
					self.anim_speed = self.spd.X
				else
					self.anim_speed = self.spd.magnitude
				end
			end
		end,
		[constants.state.airborne] = function()
			local charval = game.Players.LocalPlayer.Character.CharValue
			local issilver = charval.Value == "Silver"
			local istails = charval.Value == "Tails"
			local issuper = charval.Value == "Super"
			self.flag.boost_active = false
			if self.character:FindFirstChild("FloatAura") then
				self.character:FindFirstChild("FloatAura"):Destroy()
				sound.StopSound(self, "Float_activate")
				sound.StopSound(self, "Float_dash")
				sound.StopSound(self, "Float_move")
			end
			--Movement
			if workspace.Level and workspace.Level.MusicFolder and workspace.Level.MusicId then
				workspace.Level.MusicFolder.Music.Boosting.Enabled = false
			else
				warn("The Music object does not exist.")
			end
			self.p.height = 5
			acceleration.GetAirAcceleration(self)
			if self.spring_timer <= 0 and self.dashring_timer <= 0 then
				movement.AlignToGravity(self)
				
			end
			local prev_spd = self:ToGlobal(self.spd)
--mark8888
			
				--self.trickrampdb = true	

			--Keep using previous speed
			self.spd = self:ToLocal(prev_spd)
			--Handle collision
			local fall_ysp = -self.spd.Y
			self.flag.grounded = false
			collision.Run(self)


			if not rail.CollideRails(self) then
				if self.flag.grounded then
					--self.character:FindFirstChild("FloatAura"):Destroy()
					sound.StopSound(self, "Float_activate")
					sound.StopSound(self, "Float_dash")
					sound.StopSound(self, "Float_move")
					--Landed
					if math.abs(self.spd.X) < self.p.jog_speed then
						if fall_ysp > 2 then
							self.animation = "Land"
						else
							self.animation = "Idle"
						end
						self.spd = vector.SetX(self.spd, 0)
						self.state = constants.state.idle
					else
						self.state = GetWalkState(self)
						self.animation = "LandRun"
					end
					self:Land()
					

					--Play land sound
					if fall_ysp > 0 then
						sound.SetSoundVolume(self, "Land", fall_ysp / 5)
						sound.PlaySound(self, "Land")
					end
				else
					if self.spd.Y > -3.5 then
						if self.animation == "Fall2" then
							self.animation = "Fall"
						end
					else
						if self.animation == "Fall" then
							self.animation = "Fall2"
						end
						--if self.input.button_press.trick then
							--self.ExitBall()
							--player.state = constants.state.freestyletrick
						--end
					end
					if issilver then
						if self.boost_charge >= 1 then
					if self.input.button_press.super_action and self.flag.grounded == false then
								
								self.boost_charge -= 7.5
						self.state = constants.state.float
								sound.PlaySound(self, "Float_activate")
								sound.PlaySound(self, "Float_dash")
								sound.PlaySound(self, "Float_move")
						local PlayerAura = assets:FindFirstChild("Silver"):FindFirstChild("FloatAura"):Clone()
								
						
					
							
									
											
							end
					end
					end
				end
			end
			
		end,
		[constants.state.dropcharging] = function()
			--Movement
			self.homing_timer = 0
			acceleration.GetAirAcceleration(self)
			if self.spring_timer <= 0 and self.dashring_timer <= 0 then
				movement.AlignToGravity(self)
			end

			--Handle collision
			local fall_ysp = -self.spd.Y
			self.flag.grounded = false
			collision.Run(self)

			if not rail.CollideRails(self) then
				if self.flag.grounded then
					--Landed
					if math.abs(self.spd.X) < self.p.jog_speed then
						if fall_ysp > 2 then
							self.animation = "Land"
						else
							self.animation = "Idle"
						end
						self.spd = vector.SetX(self.spd, 0)
						self.state = constants.state.idle
					else
						self.state = GetWalkState(self)
					end
					self:Land()

					--Play land sound
					if fall_ysp > 0 then
						sound.SetSoundVolume(self, "Land", fall_ysp / 5)
						sound.PlaySound(self, "Land")

						if constants.state.dropdashcharging == true then
							constants.state.dropdashcharging = false
							sound.PlaySound(self, "SpindashRelease")								
							sound.StopSound(self, "SpindashCharge")
							self.state = constants.state.roll
							self:EnterBall()
							self.spd = vector.SetX(self.spd, 10)		
							sound.StopSound(self, "DropdashCharge")
						end
					end
				end
			end
		end,
		[constants.state.pulley] = function()
			return CheckJump(self)
		end,
		[constants.state.pole] = function()
			return CheckJump(self)
		end,
		[constants.state.boost] = function()
			
			--Movement and collision
			acceleration.GetAcceleration(self)
			self.spd = vector.SetX(self.spd, self.p.boost_speed)
			self.flag.boost_active = true
			collision.Run(self)
			movement.GetRotation(self)
			movement.AlignToGravity(self)
			--Decreament of boost charge
			self.boost_charge -= 0.2

			--Fix boost space bug
			if self.spd.X > 12 then
				self.spd = vector.SetX(self.spd, 0)
			elseif self.spd.X > 8 then
				self.spd = vector.SetX(self.spd, self.spd.X-0.01)
			end

			if not rail.CollideRails(self) then
				if not self.flag.grounded then
					--Ungrounded
					self.state = constants.state.airborne
					self.animation = "Fall"
				else
					--Set animation
					self.animation = "Mach"

					local slip_factor = math.sqrt(self.frict_mult)
					local acc_factor = math.min(math.abs(self.spd.X) / self.p.crash_speed, 1)
					self.anim_speed = self.spd.magnitude
					--Reset idle timer
					self.idle_timer = 0
				end
			end
		end,
		[constants.state.airboost] = function()
			--Movement and collision
			acceleration.GetAcceleration(self)
			movement.AlignToGravity(self)
			movement.GetRotation(self)
			movement.RotatedByGravity(self)
			collision.Run(self)
			self.flag.dash_aura = false
			self.flag.ball_aura = false

			if not rail.CollideRails(self) then
				if not self.flag.grounded and self.input.button_press.boost then
					--Ungrounded
					self.animation = "AirBoost"
					self.flag.boost_active = true
				elseif not self.flag.grounded and not self.input.button_press.boost then
					self.state = constants.state.airboost
					self.animation = "Fall"
					self.flag.boost_active = false
				else
					self.state = constants.state.boost
					self.flag.boost_active = true
				end
			end
		end,
		[constants.state.homing] = function()
			--Handle homing
			local stop_homing = homing_attack.RunHoming(self, object_instance)
			self.anim_speed = self.spd.X

			--Handle collision
			self.flag.grounded = false
			movement.AlignToGravity(self)
			collision.Run(self)

			if not rail.CollideRails(self) then
				--Check for homing attack to be cancelled
				if self.flag.grounded then
					--Land on the ground
					self.state = GetWalkState(self)
					self:Land()
				else
					--Stop homing attack if wall is hit or was told to stop
					if stop_homing or (self.homing_obj ~= nil and self.spd.magnitude < 2.5) then
						self.state = constants.state.airborne
						self:ExitBall()
						self.animation = "Fall"
						--wait(1.35)
						--if self.state == constants.state.airborne then
						--self.animation = "Fall2"
						--self.anim_speed = self.spd.X
						--end

					end
				end
			end
		end,
		[constants.state.inactive] = function()
			self.animation = "Idle"
		end,
		[constants.state.stop] = function()
			self.animation = "ChaosSnap"
		end,
		[constants.state.bounce] = function()
			--Movement
			acceleration.GetAirAcceleration(self)

			--Handle collision
			self.flag.grounded = false
			movement.AlignToGravity(self)
			collision.Run(self)

			if not rail.CollideRails(self) then
				if self.flag.grounded then
					local effect = script:WaitForChild('Effects'):WaitForChild('BounceEffect'):Clone()
					effect.Parent = workspace
					effect.Position = self.pos
					for _,particle in pairs(effect:GetDescendants()) do
						if particle:IsA('ParticleEmitter') then
							if particle:GetAttribute('OriginalRate') then
								particle.Rate = particle:GetAttribute('OriginalRate')
							else
								particle:SetAttribute('OriginalRate', particle.Rate)
							end
							particle.Enabled = true
						end
					end

					coroutine.wrap(function()
						wait(0.11)
						for _,particle in pairs(effect:GetDescendants()) do
							if particle:IsA('ParticleEmitter') then
								particle.Rate = 0
							end
						end
						wait(2)
						effect:Destroy()
					end)()

					--Unground and play sound
					if workspace.Level.NewStuff.Stomp.Value == false and workspace.Level.NewStuff.Dropdash.Value == false then
						if self.flag.grounded then
							--Unground and play sound
							self.state = constants.state.airborne
							sound.PlaySound(self, "Bounce")
							--player_draw:Draw("JumpBall")

							--Set upwards velocity
							self.jump_timer = 0
							if self.v3 ~= true or (math.random() < 0.5) then
								local fac = 1 + (math.abs(self.spd.X) / 16)
								if self.flag.bounce2 == true then
									self.spd = vector.SetY(self.spd, 3.575 * fac)
								else
									self.spd = vector.SetY(self.spd, 2.825 * fac)
									self.flag.bounce2 = true
								end
								self:UseFloorMove()
							end
						end
					elseif workspace.Level.NewStuff.Stomp.Value == true then
						if self.flag.grounded then
							sound.PlaySound(self, "Stomp")
							self.state = constants.state.walk
						end
					end
				end
			end
		end,
		[constants.state.mach] = function()
			--Movement and collision
			acceleration.GetAcceleration(self)
			self.trail_active = false
			self.flag.grounded = false
			collision.Run(self)

			if not rail.CollideRails(self) then
				if not self.flag.grounded then
					--Ungrounded
					if workspace.Level and workspace.Level.MusicFolder and workspace.Level.MusicId then
						workspace.Level.MusicFolder.Music.Boosting.Enabled = false
					else
						warn("The Music object does not exist.")
					end

					acceleration.GetAirAcceleration(self)

					if self.spring_timer <= 0 and self.dashring_timer <= 0 then
						movement.AlignToGravity(self)
					end

					self.animation = "Fall"
				else
					if workspace.Level and workspace.Level.MusicFolder and workspace.Level.MusicId then
						workspace.Level.MusicFolder.Music.Boosting.Enabled = false
					else
						warn("The Music object does not exist.")
					end

					if self.input.button_press.jump then
						self.spd = vector.SetY(self.spd, 5)
						self.flag.grounded = false
					end

					--Landed
					local fall_ysp = -self.spd.Y
					if fall_ysp > .5 then
						if math.abs(self.spd.X) < self.p.jog_speed then
							if fall_ysp > 2 then
								self.animation = "Land"
							else
								self.animation = "Idle"
							end

							self.spd = vector.SetX(self.spd, 0)
							self.state = constants.state.idle
						end
						self:Land()
					end

					if self.input.stick_mag >= .5 then
						self.spd = vector.SetX(self.spd, 12 * self.input.stick_mag)
					else
						self.spd = vector.MulX(self.spd, .8)
					end

					if self.spd.X <= 2 then
						if self.spd.X == 0 then
							self.state = constants.state.idle
							self.animation = "Idle"
						else
							self.animation = "Run"
							self.state = constants.state.walk
						end
					end

					--Play land sound
					if fall_ysp > 0 then
						if self.spd.X > 0.3 then
							self.rollal_triggered = os.clock()
							self.state = constants.state.rollal
						end
						sound.SetSoundVolume(self, "Land", fall_ysp / 5)
						sound.PlaySound(self, "Land")
					end

					--Set animation
					movement.GetRotation(self)
					movement.GetSkidSpeed(self)

					self.animation = "Mach"

					local slip_factor = math.sqrt(self.frict_mult)
					local acc_factor = math.min(math.abs(self.spd.X) / self.p.crash_speed, 1)
					self.anim_speed = lerp(self.spd.X / slip_factor + (1 - slip_factor) * 2, self.spd.X, acc_factor)
				end
			end
		end,
		[constants.state.trickwait] = function()
			self.animation = "DashRamp"
		end,
		
		[constants.state.board] = function()
			-- Movement and collision
			movement.GetRotation(self)
			movement.GetInertia(self)
			collision.Run(self)
			acceleration.GetAirAcceleration(self)
			movement.AlignToGravity(self)
			

			-- Handle jumping
			if self.flag.grounded and self.input.button_press.jump then
				self.animation = "SnowBoard2"
				self.spd += Vector3.new(0, 8, 0) -- Higher jump velocity for better airtime
				self.flag.grounded = false -- Set the state to airborne
			end

			-- Handle speed decay if moving too slowly
			if self.spd.X < 0.12 then -- If moving too slowly
				self.state = constants.state.walk -- Transition back to walking state
				if workspace:FindFirstChild("BOARDVISUAL") then
					workspace.BOARDVISUAL:Destroy() -- Remove the board visual
				end
				return
			end

			-- Handle rail collision
			if not rail.CollideRails(self) then
				if self.flag.grounded then
					-- Set grounded animations and physics
					self.animation = "SnowBoard"
					self.anim_speed = math.abs(self.spd.X) -- Animation speed tied to horizontal velocity

					-- Adjust speed based on input
					if self.input.button.roll then
						self.spd = vector.SetY(self.spd, -4) -- Allow a quick drop while rolling
						self.p.max_x_spd = 7 -- Increase max speed when rolling
						self.animation = "SnowBoard"
					else
						-- Apply friction to slow down gradually if no input
						self.spd = self.spd * 0.98
					end

				
				else
					-- Handle airborne state
					self.anim_speed = self.spd.magnitude
					self.animation = "SnowBoard2"
					self.spd = self.spd * 0.99 -- Apply slight air resistance
				end
			end

			-- Handle landing
			if self.flag.grounded and self.spd.Y < 0 then
				self.animation = "SnowBoard"
				sound.PlaySound(self, "Land")
			end

			-- Cap maximum speed
			local max_speed = 15 -- Define a max speed for the board
			if self.spd.magnitude > max_speed then
				self.spd = self.spd.Unit * max_speed -- Normalize and cap speed
			end
		end,
		[constants.state.goalring] = function()
			self.animation = "GoalLong"
			
			if self.animation == "GoalLong" then
				--wait(2.17)
				task.delay(3.4, function()
					self.state = constants.state.goalring2
				end)
			end
			
			--2.17
		end,
		[constants.state.goalring2] = function()
			self.animation = "GoalRing"

		end,
		[constants.state.rail] = function()
			self.tertiary_action = "Slide"
			self.rail_bonus_time -= 1
			--Perform rail movement
			if rail.Movement(self) then
				--Become airborne in fall animation (came off rail)
				self.state = constants.state.airborne
				self.animation = "Fall"
				wait(1.35)
				--if self.state == constants.state.airborne then
				--self.animation = "Fall2"
			else
				if self.input.button_press.roll and workspace.Level.NewStuff.Boost.Value and not workspace.Level.MusicFolder.Music.Boosting.Enabled then
					sound.StopSound(self, "Boost")
					sound.PlaySound(self, "Boost")
				end

				if self.input.button.roll and workspace.Level.NewStuff.Boost.Value then
					workspace.Level.MusicFolder.Music.Boosting.Enabled = true
					self.spindash_speed = math.max(self.spd.X, 2)
					if self.spd.X < 8 then
						self.spd = vector.SetX(self.spd, 8)
					end
				else
					workspace.Level.MusicFolder.Music.Boosting.Enabled = false
					--end
				end
				if self.input.button.tertiary_action and constants.state.rail then
				self.animation = "RailGrind"
					task.delay(0, function()
						
						if self.rail_bonus_time == 1 then
							--self.rail_bonus_time += 1 == false
							--self.spd = vector.AddX(self.spd, self.spd.X * 0.008) == false
						
					end
					self.rail_bonus_time += 1
						if self.spd.X < 7 then
						self.spd = vector.AddX(self.spd, self.spd.X * 0.0125)
						
						if self.spd.X > 7 then
								self.spd = vector.AddX(self.spd, self.spd.X * 0)
							if self.spd.X < 7.01 then
									if self.rail_bonus_time == 0 then
										--self.spd = (self.spd * Vector3.new(0,1,1)) + Vector3.new(8,0,0)
							--self.spd = vector.SetY(self.spd, 0.085)
							--acceleration.GetAcceleration(self)
							end
						end
						end
							
						--math.max(self.spd.X, 6)
						--if self.spd.X > 7 then
							--self.spd = vector.SetX(self.spd, 6.25)
						end
					end)
					--self.spd.X = self.spd.X + 1.5
					--self.spd = vector.AddX(self.spd, self.spd.X * 0.01)
					--self.spd.X = math.max(self.spd.X, 2)
				--if self.input.button.tertiary_action then
				
					--self.spd.x += 1
					--self.spd =  self.spd + 1
					--self.spd *= -1
					--self.walljump_timer = 60
					--self.rail_bonus_time += 15 
					
					
						--self.spd = vector.AddX(self.spd, self.spd.X * 0.01)

					--local function CheckRailGrind(self)
					--workspace.Level.Rails.Grind.Value = true
					--if workspace.Level.Rails.Grind.Value == true then
					--self.spd = vector.AddX(self.spd, self.spd.X * 0.01)
						--self.animation = "RailGrind"
						--if self.animation ~= "RailGrind" then
							--self.animation = "Rail"
							--if self.animation ~= "RailGrind" then
								--workspace.Level.Rails.Grind.Value = false
					--mark point
						--self.walljump_timer -= 1
						--if self.walljump_timer == 0 then
						--if self.rail_bonus_time == 15 then

						--self.rail_bonus_time = 0
						--workspace.Level.Rails.Grind.Value = false

					
					--self.walljump_timer -= 1
					--if self.walljump_timer == 0 then
					--if self.rail_bonus_time == 15 then
						
						--self.rail_bonus_time = 0
					--workspace.Level.Rails.Grind.Value = false
						
						--end
						   --end
						--end
					--end
	end
			end
		end,
		[constants.state.light_speed_dash] = function()
			--Run light speed dash
			if lsd.RunLSD(self, object_instance) then
				--Stop light speed dash
				self.state = constants.state.airborne
				self.animation = "Fall"
			end

			--Handle collision
			self.flag.grounded = false
			collision.Run(self)

			if not rail.CollideRails(self) then
				--Stop light speed dash if wall is hit
				if self.spd.magnitude < 1 then
					self.state = constants.state.airborne
					self.animation = "Fall"
				end
			end
		end,
		[constants.state.air_kick] = function()
			local charval = game.Players.LocalPlayer.Character.CharValue
			local issilver = charval.Value == "Silver"
			--Handle movement
			local has_control, analogue_turn, analogue_mag = input.GetAnalogue(self)
			self.spd += self.spd * Vector3.new(self.p.air_resist_air * (0), self:GetAirResistY(), self.p.air_resist_z)
			self.spd += self:ToLocal(self.gravity) * self:GetWeight() * 0
			self:AdjustAngleYS(analogue_turn)

			--Handle collision
			local fall_ysp = -self.spd.Y
			self.flag.grounded = false
			movement.AlignToGravity(self)
			collision.Run(self)

			if not rail.CollideRails(self) then
				if self.flag.grounded then
					--Landed
					self.state = GetWalkState(self)
					self:Land()

					--Play land sound
					if fall_ysp > 0 then
						sound.SetSoundVolume(self, "Land", fall_ysp / 5)
						sound.PlaySound(self, "Land")
					end
				else
					--Stop air kick after timer's run out or we've lost all our speed
					self.air_kick_timer -= 1
					if self.air_kick_timer <= 0 or self.spd.magnitude < 0.35 then
						self.state = constants.state.airborne
						self.animation = "Fall"
						--if self:BallActive() == false then
						--wait(1.35)
						--if self.state == constants.state.airborne then
						--self.animation = "Fall2"
						--end
					end

					return true
				end
				if issilver then
					self.boost_charge -= 5
				end
			end
		end,
		[constants.state.fan] = function()
			--Movement
			acceleration.GetAirAcceleration(self)
			movement.AlignToGravity(self)

			--Handle collision
			local fall_ysp = -self.spd.Y
			self.flag.grounded = false
			collision.Run(self, dt)
			self.animation = "Fall"

			if self.spd.Y <= -1 and not self.flag.grounded then
				self.state = constants.state.airborne
				self.animation = "Fall"
			end

			if not rail.CollideRails(self) then
				if self.flag.grounded then
					--Landed
					self.state = GetWalkState(self)
					self:Land()
					self:LandAnimation(fall_ysp, GetWalkState)

					--Play land sound
					if fall_ysp > 0 then
						sound.SetSoundVolume(self, "Land", fall_ysp / 5)
						sound.PlaySound(self, "Land")
					end
				end
			end
		end,
		[constants.state.walljump] = function()
			--Add your animations here,  you should probably add it into the animation table in characterinfo
			--self.animation = "walljump" or something
			--for now i will use the idle anim
			self.animation = "WallHold"
			self.jump_timer = 60
			self.walljump_timer -= 1
			
			if self.jump_timer == 0 then
				self.state = constants.state.airborne
			end


			return CheckWallJump(self)
		end,
		[constants.state.float] = function()
			-- Perform initial movement updates
			movement.GetRotation(self)
			movement.GetInertia(self)
			self.spd = vector.AddX(self.spd, self.spd.X * 0.006)
			acceleration.GetAirAcceleration(self)
			self.spd = vector.MulY(self.spd, 0) -- Nullify vertical speed

			-- Deplete boost charge
			self.boost_charge = math.max(self.boost_charge - 0.25, 0) -- Ensure it doesn't go below 0

			-- Set animation and manage aura
			self.animation = "Float"
			local charval = game.Players.LocalPlayer.Character:FindFirstChild("CharValue")
			local issilver = charval and charval.Value == "Silver"

			if not self.character:FindFirstChild("FloatAura") then
				local PlayerAura = assets:FindFirstChild("Silver"):FindFirstChild("FloatAura"):Clone()
				PlayerAura.Parent = self.character
				PlayerAura.Enabled = true
			end

			-- Handle movement
			local has_control, analogue_turn, analogue_mag = input.GetAnalogue(self)
			self.spd += self.spd * Vector3.new(self.p.air_resist_air * 0, self:GetAirResistY(), self.p.air_resist_z)
			self.spd += self:ToLocal(self.gravity) * self:GetWeight() * 0
			self:AdjustAngleYS(analogue_turn)

			-- Handle collision
			local fall_ysp = -self.spd.Y
			self.flag.grounded = false
			movement.AlignToGravity(self)
			collision.Run(self)

			if not rail.CollideRails(self) then
				if self.flag.grounded then
					-- Landed
					self.state = GetWalkState(self)
					self:Land()

					-- Play landing sound
					if fall_ysp > 0 then
						sound.SetSoundVolume(self, "Land", fall_ysp / 5)
						sound.PlaySound(self, "Land")
					end

					-- Remove FloatAura
					if self.character:FindFirstChild("FloatAura") then
						self.character.FloatAura:Destroy()
					end
				else
					-- Check for conditions to exit float state
					if self.boost_charge <= 0 or not self.input.button.super_action or self.spd.Magnitude < 0.35 then
						self.state = constants.state.airborne
						self.animation = "Fall"
						sound.StopSound(self, "Float_move")

						-- Remove aura when exiting float
						if self.character:FindFirstChild("FloatAura") then
							self.character.FloatAura:Destroy()
						end
					end

					-- Allow re-entry to float state
					if self.input.button_press.super_action and not self.flag.grounded and self.boost_charge > 0 then
						self.state = constants.state.float
						sound.PlaySound(self, "Float_move")
						if not self.character:FindFirstChild("FloatAura") then
							local PlayerAura = assets:FindFirstChild("Silver"):FindFirstChild("FloatAura"):Clone()
							PlayerAura.Parent = self.character
							PlayerAura.Enabled = true
						end
					end
				end
			end

			return true
		end,
		[constants.state.float2] = function()
			-- Perform initial movement updates
			movement.GetRotation(self)
			movement.GetInertia(self)
			self.spd = vector.AddX(self.spd, self.spd.X * 0.008)
			self.animation = "Float"

			-- Adjust vertical and horizontal speed based on conditions
			if self.state == constants.state.float2 then
				self.spd = vector.SetY(self.spd, -0.66)
				if self.spd.X > 6.75 then
					self.spd = vector.SetY(self.spd, -1.01)
					if self.spd.X > 8.1 then
						self.spd = vector.SetX(self.spd, 8.09) -- Cap horizontal speed at 8.09
					end
				end
			end

			-- Handle movement
			local has_control, analogue_turn, analogue_mag = input.GetAnalogue(self)
			self.spd += self.spd * Vector3.new(self.p.air_resist_air * 0, self:GetAirResistY(), self.p.air_resist_z)
			self.spd += self:ToLocal(self.gravity) * self:GetWeight() * 0
			self:AdjustAngleYS(analogue_turn)

			-- Handle collision
			local fall_ysp = -self.spd.Y
			self.flag.grounded = false
			movement.AlignToGravity(self)
			collision.Run(self)

			if not rail.CollideRails(self) then
				if self.flag.grounded then
					-- Landed
					self.flag.grounded = true
					self.state = GetWalkState(self)
					self:Land()

					-- Play landing sound
					if fall_ysp > 0 then
						sound.SetSoundVolume(self, "Land", fall_ysp / 5)
						sound.PlaySound(self, "Land")
					end
				else
					-- Conditions to exit float2 state
					if self.boost_charge <= 0 or not self.input.button.super_action or self.spd.Magnitude < 0.35 then
						self.state = constants.state.airborne
						self.animation = "Fall"
						sound.StopSound(self, "SFloat_move")

						

					-- Allow re-entry to float2 state
					if self.input.button_press.super_action and not self.flag.grounded and self.boost_charge > 0 then
						self.state = constants.state.float2
						self.animation = "Float"
						sound.PlaySound(self, "SFloat_move")

						
						end
					end
				end
			end

			return true
		end,
		[constants.state.freefall] = function()
			return CheckLightSpeedDash(self, object_instance)
		end,

		[constants.state.freefall] = function()
			--Movement and collision
			acceleration.GetAcceleration(self)
			collision.Run(self)

			if not rail.CollideRails(self) then
				local slip_factor = math.sqrt(self.frict_mult)
				local acc_factor = math.min(math.abs(self.spd.X) / self.p.crash_speed, 1)
				self.spd = vector.SetY(self.spd, -3)
				self.animation = "Skydive"	
				self.p.max_x_spd = 3
				if self.input.button.roll then
					self.spd = vector.SetY(self.spd, -6)
					self.p.max_x_spd = 5
					self.animation = "Skydive"
				else	
					self.spd = vector.SetY(self.spd, -3)
					self.p.max_x_spd = 3
					self.animation = "Skydive"	
				end				



				if self.flag.grounded then
					self.state = GetWalkState(self)
					self.flag.ball_aura = false
				end
			end

		end,
		[constants.state.ragdoll] = function()
			--Run ragdoll
			if ragdoll.Physics(self) then
				self.state = constants.state.airborne
				self.animation = "Fall"
				return
			end

			--Handle collision
			self.flag.grounded = false
			collision.Run(self)
		end,
		[constants.state.skydive] = function()
			local has_control, analogue_turn, analogue_mag = input.GetAnalogue(self)
			acceleration.GetAirAcceleration(self)
			self.animation = "Skydive"
			self.gravity = Vector3.new(0, -1.5, 0)
			if self.input.button.roll then
				self.gravity = Vector3.new(0, -2, 0)
				self.animation = "Skydive2"
				if self.input.button.roll == false then
					self.gravity = Vector3.new(0, -0.5, 0)
				end
			end

			--Handle collision
			local fall_ysp = -self.spd.Y
			self.flag.grounded = false
			movement.AlignToGravity(self)
			collision.Run(self)

			if self.flag.grounded then
				self.gravity = Vector3.new(0, -1, 0)
				self.state = GetWalkState(self)
				self.flag.ball_aura = false
			end
		end,	
		[constants.state.hurt] = function()
			--Handle movement
			movement.GetInertia(self)

			--Handle collision
			self.flag.grounded = false
			movement.AlignToGravity(self)
			collision.Run(self)

			if not rail.CollideRails(self) then
				if self.flag.grounded then
					--Land on the ground
					self.state = GetWalkState(self)
					self:Land()
					self.animation = "Land"
					self.spd = self.spd:Lerp(Vector3.new(), math.abs(self.dotp))
				elseif self.hurt_time > 0 then
					--Exit hurt state after cooldown
					self.hurt_time = math.max(self.hurt_time - 1, 0)
					if self.hurt_time <= 0 then
						self.state = constants.state.airborne
						self.animation = "Fall"
						--wait(1.35)
						--if self.state == constants.state.airborne then
						--self.animation = "Fall2"

					end
					if self.animation == "MachHurt" then

						self.state = constants.state.mach
						self.animation = "MachHurt"


						--end
					end
				end
			end
		end,

		[constants.state.dead] = function()
			--collision.Run(self)
			movement.AlignToGravity(self)
			--movement.GetRotation(self)
			
			--if self.flag.grounded == false then
				--self.spd = vector.SetY(self.spd, -4)
			--end
			
			if self.flag.grounded == true then
				self.flag.grounded = true
				self.spd = vector.SetY(self.spd, 0)
			end
		end,
		[constants.state.drown] = function()

		end,
		
		--[constants.state.charge] = function()
			--self.animation = "Charge"
		--end,
		[constants.state.freestyletrick] = function()
			-- Movement and collision
			self.tertiary_action = "AirKick"
			acceleration.GetAirAcceleration(self)
			collision.Run(self)


			if self.flag.grounded then
				self.state = constants.state.airborne
			end

			self.trickrampdb = false
			sound.PlaySound(self, "trick1")
			if self.input.button_press.trickRight and not self.trickrampdb then
				self.animation = `Attack{math.random(1,3)}`
				self.trickrampdb = true	
				self:GiveScore(50)
				self.boost_charge += 5
				task.delay(1, function()
					self.trickrampdb = false
				end)
			elseif self.input.button_press.trickUp and not self.trickrampdb then
				self.animation = `Attack{math.random(1,3)}`
				self.trickrampdb = true
				self:GiveScore(50)
				self.boost_charge += 5
				task.delay(1, function()
					self.trickrampdb = false
				end)
			elseif self.input.button_press.trickLeft and not self.trickrampdb then
				self.animation = `Attack{math.random(1,3)}`
				self.trickrampdb = true	
				self:GiveScore(50)
				self.boost_charge += 5
				task.delay(1, function()
					self.trickrampdb = false
				end)
			elseif self.input.button_press.trickDown and not self.trickrampdb then
				self.animation = `Attack{math.random(1,3)}`
				self.trickrampdb = true
				self:GiveScore(50)
				self.boost_charge += 5
				task.delay(1, function()
					self.trickrampdb = false
				end)
			elseif self.input.button_press.tertiary_action and not self.trickrampdb then
				self.animation = `Attack{math.random(1,3)}`
				self.trickrampdb = true
				self:GiveScore(50)
				self.boost_charge += 5
				task.delay(1, function()
					self.trickrampdb = false
				end)
			end
		end,
	})
	
	UpdateMods(self.mods_late)
	if self.state == constants.state.freestyletrick then
		print("PLAYER CAN NOW DO AMAZING TRICKS WATCH OUT FOR HIS STYLE")
	end
	

	--Get portrait to use
	if self.state == constants.state.hurt or self.state == constants.state.dead then
		self.portrait = "Hurt"
	else
		self.portrait = "Idle"
	end

	--Increment game time
	if workspace.Level.NewStuff.Timer.Value == true then
		self.time += 1 / constants.framerate
	else
		--do nothing , the timer is paused...
	end

	--TEMP: Die when below death barrier
	if self.pos.Y <= workspace.FallenPartsDestroyHeight then
		self.hum.Health = 0
	end
	if self.hum.Health <= 0 and not self.dead_debounce then
		workspace.Level.NewStuff.Lives.Value = workspace.Level.NewStuff.Lives.Value - 1
		if workspace.Level.NewStuff.Lives.Value < 0 then
			--Game Over.
			game.Players.LocalPlayer.PlayerGui.GameOver.Enabled = true
			self.state = constants.state.inactive
		else
			self.dead_debounce = true
			replicated_storage:WaitForChild("LoadCharacter"):FireServer()
		end
	end

	--[[local charval = game.Players.LocalPlayer.Character.CharValue
	local issonic = charval.Value == "Sonic"
	local isshadow = charval.Value == "Shadow"
	local issilver = charval.Value == "Silver"
	--mark9999999
	if self.rings > 99 then
		--camShake:Shake(CameraShaker.Presets.Super2)
		
	

	
		
		if issonic then
			
			local sChargeAttachment = self.hrp:FindFirstChild("SCharge")
			if sChargeAttachment then
				for _, particle in pairs(sChargeAttachment:GetDescendants()) do
					if particle:IsA("ParticleEmitter") then
						particle.Enabled = false
						
						
						--camShake:Shake(CameraShaker.Presets.Super2)
						
						--self.animation = "TransForm"
					end
				end

				-- Desactivar las partículas después de 2 segundos
				task.delay(2, function()
					for _, particle in pairs(sChargeAttachment:GetDescendants()) do
						if particle:IsA("ParticleEmitter") then
							particle.Enabled = false
							
							--self.animation = "TransForm" == false
						end
					end
				end)
			end
			task.delay(0, function()
			end)
			remote:FireServer("SuperOn")
			

			-- Activar las partículas del Attachment "SCharge"
			local sChargeAttachment = self.hrp:FindFirstChild("Super")
			if sChargeAttachment then
				for _, particle in pairs(sChargeAttachment:GetDescendants()) do
					if particle:IsA("ParticleEmitter") then
						
						particle.Enabled = true
						
						

						_G.charinfo = require(game:GetService("Players").LocalPlayer.Character.CharacterInfo);
						_G.charinfo.physics.jog_speed = 0.008
						_G.charinfo.physics.run_speed = 0.00135
						_G.charinfo.physics.run_accel = 0.11
						_G.charinfo.physics.rush_speed += 0
						_G.charinfo.physics.crash_speed += 0
						_G.charinfo.physics.dash_speed = 5.09
						_G.charinfo.physics.jmp_addit = 0.08
						_G.charinfo.physics.slow_down += 0
						_G.charinfo.physics.run_break += 0
						_G.charinfo.physics.air_break += 0
						_G.charinfo.physics.air_resist_air += 0
						_G.charinfo.physics.air_resist += 0
						_G.charinfo.physics.air_resist_y += 0
						_G.charinfo.physics.air_resist_z += 0
						_G.charinfo.physics.grd_frict += 0
						_G.charinfo.physics.grd_frict_z += 0
						_G.charinfo.physics.lim_frict += 0
						_G.charinfo.physics.rat_bound += 0
						_G.charinfo.physics.rad  += 0
						_G.charinfo.physics.height  += 0
						_G.charinfo.physics.weight += 0
						_G.charinfo.physics.eyes_height += 0
						_G.charinfo.physics.center_height += 0
					end
				end
			end
		end
		if self.rings < 99 then
			--issuper = false
			remote:FireServer("SuperOff")
			_G.charinfo = require(game:GetService("Players").LocalPlayer.Character.CharacterInfo);
			_G.charinfo.physics.jog_speed = 0.9
			_G.charinfo.physics.run_speed = 1.9
			_G.charinfo.physics.run_accel = 0.1
			_G.charinfo.physics.rush_speed += 0
			_G.charinfo.physics.crash_speed += 0
			_G.charinfo.physics.dash_speed += 0
			_G.charinfo.physics.jmp_addit += 0
			_G.charinfo.physics.slow_down += 0
			_G.charinfo.physics.run_break += 0
			_G.charinfo.physics.air_break += 0
			_G.charinfo.physics.air_resist_air += 0
			_G.charinfo.physics.air_resist += 0
			_G.charinfo.physics.air_resist_y += 0
			_G.charinfo.physics.air_resist_z += 0
			_G.charinfo.physics.grd_frict += 0
			_G.charinfo.physics.grd_frict_z += 0
			_G.charinfo.physics.lim_frict += 0
			_G.charinfo.physics.rat_bound += 0
			_G.charinfo.physics.rad  += 0
			_G.charinfo.physics.height  += 0
			_G.charinfo.physics.weight += 0
			_G.charinfo.physics.eyes_height += 0
			_G.charinfo.physics.center_height += 0
			-- Activar las partículas del Attachment "SCharge"
			local sChargeAttachment = self.hrp:FindFirstChild("Super")
			if sChargeAttachment then
				for _, particle in pairs(sChargeAttachment:GetDescendants()) do
					if particle:IsA("ParticleEmitter") then
						particle.Enabled = false
					end
				end
			end
		end
	end
	local charval = game.Players.LocalPlayer.Character.CharValue
	local isshadow = charval.Value == "Shadow"

	if isshadow then
		task.delay(1, function()

		end)
		remote:FireServer("SuperOn")

		-- Activar las partículas del Attachment "SCharge"
		local sChargeAttachment = self.hrp:FindFirstChild("Super")
		if sChargeAttachment then
			for _, particle in pairs(sChargeAttachment:GetDescendants()) do
				if particle:IsA("ParticleEmitter") then
					particle.Enabled = true

					_G.charinfo = require(game:GetService("Players").LocalPlayer.Character.CharacterInfo);

					_G.charinfo.physics.jog_speed = 0.0065
					_G.charinfo.physics.run_speed = 0.00115
					_G.charinfo.physics.run_accel = 0.105
					_G.charinfo.physics.rush_speed += 0
					_G.charinfo.physics.crash_speed += 0
					_G.charinfo.physics.dash_speed = 5.09
					_G.charinfo.physics.jmp_addit = 0.076
					_G.charinfo.physics.slow_down += 0
					_G.charinfo.physics.run_break += 0
					_G.charinfo.physics.air_break += 0
					_G.charinfo.physics.air_resist_air += 0
					_G.charinfo.physics.air_resist += 0
					_G.charinfo.physics.air_resist_y += 0
					_G.charinfo.physics.air_resist_z += 0
					_G.charinfo.physics.grd_frict += 0
					_G.charinfo.physics.grd_frict_z += 0
					_G.charinfo.physics.lim_frict += 0
					_G.charinfo.physics.rat_bound += 0
					_G.charinfo.physics.rad  += 0
					_G.charinfo.physics.height  += 0
					_G.charinfo.physics.weight += 0
					_G.charinfo.physics.eyes_height += 0
					_G.charinfo.physics.center_height += 0
				end
			end
		end
	end
	if self.rings < 99 then
		remote:FireServer("SuperOff")
		_G.charinfo = require(game:GetService("Players").LocalPlayer.Character.CharacterInfo);
		_G.charinfo.physics.jog_speed = 0.85
		_G.charinfo.physics.run_speed = 1.73
		_G.charinfo.physics.run_accel = 0.0825
		_G.charinfo.physics.rush_speed += 0
		_G.charinfo.physics.crash_speed += 0
		_G.charinfo.physics.dash_speed += 0
		_G.charinfo.physics.jmp_addit += 0
		_G.charinfo.physics.slow_down += 0
		_G.charinfo.physics.run_break += 0
		_G.charinfo.physics.air_break += 0
		_G.charinfo.physics.air_resist_air += 0
		_G.charinfo.physics.air_resist += 0
		_G.charinfo.physics.air_resist_y += 0
		_G.charinfo.physics.air_resist_z += 0
		_G.charinfo.physics.grd_frict += 0
		_G.charinfo.physics.grd_frict_z += 0
		_G.charinfo.physics.lim_frict += 0
		_G.charinfo.physics.rat_bound += 0
		_G.charinfo.physics.rad  += 0
		_G.charinfo.physics.height  += 0
		_G.charinfo.physics.weight += 0
		_G.charinfo.physics.eyes_height += 0
		_G.charinfo.physics.center_height += 0
		-- Activar las partículas del Attachment "SCharge"
		local sChargeAttachment = self.hrp:FindFirstChild("Super")
		if sChargeAttachment then
			for _, particle in pairs(sChargeAttachment:GetDescendants()) do
				if particle:IsA("ParticleEmitter") then
					particle.Enabled = false
				end
			end
		end
	end
	if issilver then
		task.delay(1, function()

		end)
		remote:FireServer("SuperOn")

		-- Activar las partículas del Attachment "SCharge"
		local sChargeAttachment = self.hrp:FindFirstChild("Super")
		if sChargeAttachment then
			for _, particle in pairs(sChargeAttachment:GetDescendants()) do
				if particle:IsA("ParticleEmitter") then
					particle.Enabled = true

					_G.charinfo = require(game:GetService("Players").LocalPlayer.Character.CharacterInfo);

					_G.charinfo.physics.jog_speed = 0.0065
					_G.charinfo.physics.run_speed = 0.00115
					_G.charinfo.physics.run_accel = 0.105
					_G.charinfo.physics.rush_speed += 0
					_G.charinfo.physics.crash_speed += 0
					_G.charinfo.physics.dash_speed = 5.09
					_G.charinfo.physics.jmp_addit = 0.076
					_G.charinfo.physics.slow_down += 0
					_G.charinfo.physics.run_break += 0
					_G.charinfo.physics.air_break += 0
					_G.charinfo.physics.air_resist_air += 0
					_G.charinfo.physics.air_resist += 0
					_G.charinfo.physics.air_resist_y += 0
					_G.charinfo.physics.air_resist_z += 0
					_G.charinfo.physics.grd_frict += 0
					_G.charinfo.physics.grd_frict_z += 0
					_G.charinfo.physics.lim_frict += 0
					_G.charinfo.physics.rat_bound += 0
					_G.charinfo.physics.rad  += 0
					_G.charinfo.physics.height  += 0
					_G.charinfo.physics.weight += 0
					_G.charinfo.physics.eyes_height += 0
					_G.charinfo.physics.center_height += 0
				end
			end
		end
	end
	if self.rings < 99 then
		remote:FireServer("SuperOff")
		_G.charinfo = require(game:GetService("Players").LocalPlayer.Character.CharacterInfo);
		_G.charinfo.physics.jog_speed = 0.805
		_G.charinfo.physics.run_speed = 1.6
		_G.charinfo.physics.run_accel = 0.075
		_G.charinfo.physics.rush_speed += 0
		_G.charinfo.physics.crash_speed += 0
		_G.charinfo.physics.dash_speed += 0
		_G.charinfo.physics.jmp_addit += 0
		_G.charinfo.physics.slow_down += 0
		_G.charinfo.physics.run_break += 0
		_G.charinfo.physics.air_break += 0
		_G.charinfo.physics.air_resist_air += 0
		_G.charinfo.physics.air_resist += 0
		_G.charinfo.physics.air_resist_y += 0
		_G.charinfo.physics.air_resist_z += 0
		_G.charinfo.physics.grd_frict += 0
		_G.charinfo.physics.grd_frict_z += 0
		_G.charinfo.physics.lim_frict += 0
		_G.charinfo.physics.rat_bound += 0
		_G.charinfo.physics.rad  += 0
		_G.charinfo.physics.height  += 0
		_G.charinfo.physics.weight += 0
		_G.charinfo.physics.eyes_height += 0
		_G.charinfo.physics.center_height += 0
		-- Activar las partículas del Attachment "SCharge"
		local sChargeAttachment = self.hrp:FindFirstChild("Super")
		if sChargeAttachment then
			for _, particle in pairs(sChargeAttachment:GetDescendants()) do
				if particle:IsA("ParticleEmitter") then
					particle.Enabled = false
				end
			end
		end
	end]]
	


	
	--self.camera:Destroy(); self.camera = nil
	--self.camera:Update()
	--if remote:FireServer("SuperOn") then
		--sound.PlaySound(self, "Electricity")
	--end
    local charval = game.Players.LocalPlayer.Character.CharValue
	local issonic = charval.Value == "Sonic"
	local isshadow = charval.Value == "Shadow"
	local issilver = charval.Value == "Silver"
	local issuper = charval.Value == "Super"
	--mark9999999
	if self.rings > 99 then
		--camShake:Shake(CameraShaker.Presets.Super2)
		
	

	
		
		if  charval.Value == "Sonic" then
			
			local sChargeAttachment = self.hrp:FindFirstChild("SCharge")
			if sChargeAttachment then
				for _, particle in pairs(sChargeAttachment:GetDescendants()) do
					if particle:IsA("ParticleEmitter") then
						particle.Enabled = false
						
						
						--camShake:Shake(CameraShaker.Presets.Super2)
						
						--self.animation = "TransForm"
					end
				end

				-- Desactivar las partículas después de 2 segundos
				task.delay(2, function()
					for _, particle in pairs(sChargeAttachment:GetDescendants()) do
						if particle:IsA("ParticleEmitter") then
							particle.Enabled = false
							
							--self.animation = "TransForm" == false
						end
					end
				end)
			end
			task.delay(0, function()
			end)
			remote:FireServer("SuperOn")
			

			-- Activar las partículas del Attachment "SCharge"
			local sChargeAttachment = self.hrp:FindFirstChild("Super")
			if sChargeAttachment then
				for _, particle in pairs(sChargeAttachment:GetDescendants()) do
					if particle:IsA("ParticleEmitter") then
						
						particle.Enabled = true
						
						

						_G.charinfo = require(game:GetService("Players").LocalPlayer.Character.CharacterInfo);
						_G.charinfo.physics.jog_speed = 0.008
						_G.charinfo.physics.run_speed = 0.00135
						_G.charinfo.physics.run_accel = 0.11
						_G.charinfo.physics.rush_speed += 0
						_G.charinfo.physics.crash_speed += 0
						_G.charinfo.physics.dash_speed = 5.09
						_G.charinfo.physics.jmp_addit = 0.08
						_G.charinfo.physics.slow_down += 0
						_G.charinfo.physics.run_break += 0
						_G.charinfo.physics.air_break += 0
						_G.charinfo.physics.air_resist_air += 0
						_G.charinfo.physics.air_resist += 0
						_G.charinfo.physics.air_resist_y += 0
						_G.charinfo.physics.air_resist_z += 0
						_G.charinfo.physics.grd_frict += 0
						_G.charinfo.physics.grd_frict_z += 0
						_G.charinfo.physics.lim_frict += 0
						_G.charinfo.physics.rat_bound += 0
						_G.charinfo.physics.rad  += 0
						_G.charinfo.physics.height  += 0
						_G.charinfo.physics.weight += 0
						_G.charinfo.physics.eyes_height += 0
						_G.charinfo.physics.center_height += 0
					end
				end
			end
		end
		if self.rings < 99 then
			if  charval.Value == "Sonic" then
			--issuper = false
			remote:FireServer("SuperOff")
			_G.charinfo = require(game:GetService("Players").LocalPlayer.Character.CharacterInfo);
			_G.charinfo.physics.jog_speed = 0.9
			_G.charinfo.physics.run_speed = 1.9
			_G.charinfo.physics.run_accel = 0.1
			_G.charinfo.physics.rush_speed += 0
			_G.charinfo.physics.crash_speed += 0
			_G.charinfo.physics.dash_speed += 0
			_G.charinfo.physics.jmp_addit += 0
			_G.charinfo.physics.slow_down += 0
			_G.charinfo.physics.run_break += 0
			_G.charinfo.physics.air_break += 0
			_G.charinfo.physics.air_resist_air += 0
			_G.charinfo.physics.air_resist += 0
			_G.charinfo.physics.air_resist_y += 0
			_G.charinfo.physics.air_resist_z += 0
			_G.charinfo.physics.grd_frict += 0
			_G.charinfo.physics.grd_frict_z += 0
			_G.charinfo.physics.lim_frict += 0
			_G.charinfo.physics.rat_bound += 0
			_G.charinfo.physics.rad  += 0
			_G.charinfo.physics.height  += 0
			_G.charinfo.physics.weight += 0
			_G.charinfo.physics.eyes_height += 0
			_G.charinfo.physics.center_height += 0
			-- Activar las partículas del Attachment "SCharge"
			local sChargeAttachment = self.hrp:FindFirstChild("Super")
			if sChargeAttachment then
				for _, particle in pairs(sChargeAttachment:GetDescendants()) do
					if particle:IsA("ParticleEmitter") then
						particle.Enabled = false
					end
				end
			end
		end
		end
		end
	local charval = game.Players.LocalPlayer.Character.CharValue
	local isshadow = charval.Value == "Shadow"

	if  charval.Value == "Shadow" then
		task.delay(1, function()

		end)
		remote:FireServer("SuperOn")

		-- Activar las partículas del Attachment "SCharge"
		local sChargeAttachment = self.hrp:FindFirstChild("Super")
		if sChargeAttachment then
			for _, particle in pairs(sChargeAttachment:GetDescendants()) do
				if particle:IsA("ParticleEmitter") then
					particle.Enabled = true

					_G.charinfo = require(game:GetService("Players").LocalPlayer.Character.CharacterInfo);

					_G.charinfo.physics.jog_speed = 0.0065
					_G.charinfo.physics.run_speed = 0.00115
					_G.charinfo.physics.run_accel = 0.105
					_G.charinfo.physics.rush_speed += 0
					_G.charinfo.physics.crash_speed += 0
					_G.charinfo.physics.dash_speed = 5.09
					_G.charinfo.physics.jmp_addit = 0.076
					_G.charinfo.physics.slow_down += 0
					_G.charinfo.physics.run_break += 0
					_G.charinfo.physics.air_break += 0
					_G.charinfo.physics.air_resist_air += 0
					_G.charinfo.physics.air_resist += 0
					_G.charinfo.physics.air_resist_y += 0
					_G.charinfo.physics.air_resist_z += 0
					_G.charinfo.physics.grd_frict += 0
					_G.charinfo.physics.grd_frict_z += 0
					_G.charinfo.physics.lim_frict += 0
					_G.charinfo.physics.rat_bound += 0
					_G.charinfo.physics.rad  += 0
					_G.charinfo.physics.height  += 0
					_G.charinfo.physics.weight += 0
					_G.charinfo.physics.eyes_height += 0
					_G.charinfo.physics.center_height += 0
				end
			end
		end
	end
	if self.rings < 99 then
		if  charval.Value == "Shadow" then
		remote:FireServer("SuperOff")
		_G.charinfo = require(game:GetService("Players").LocalPlayer.Character.CharacterInfo);
		_G.charinfo.physics.jog_speed = 0.85
		_G.charinfo.physics.run_speed = 1.73
		_G.charinfo.physics.run_accel = 0.083
		_G.charinfo.physics.rush_speed += 0
		_G.charinfo.physics.crash_speed += 0
		_G.charinfo.physics.dash_speed += 0
		_G.charinfo.physics.jmp_addit += 0
		_G.charinfo.physics.slow_down += 0
		_G.charinfo.physics.run_break += 0
		_G.charinfo.physics.air_break += 0
		_G.charinfo.physics.air_resist_air += 0
		_G.charinfo.physics.air_resist += 0
		_G.charinfo.physics.air_resist_y += 0
		_G.charinfo.physics.air_resist_z += 0
		_G.charinfo.physics.grd_frict += 0
		_G.charinfo.physics.grd_frict_z += 0
		_G.charinfo.physics.lim_frict += 0
		_G.charinfo.physics.rat_bound += 0
		_G.charinfo.physics.rad  += 0
		_G.charinfo.physics.height  += 0
		_G.charinfo.physics.weight += 0
		_G.charinfo.physics.eyes_height += 0
		_G.charinfo.physics.center_height += 0
		-- Activar las partículas del Attachment "SCharge"
		local sChargeAttachment = self.hrp:FindFirstChild("Super")
		if sChargeAttachment then
			for _, particle in pairs(sChargeAttachment:GetDescendants()) do
				if particle:IsA("ParticleEmitter") then
					particle.Enabled = false
				end
			end
		end
		end
		end
	if issilver then
		task.delay(1, function()

		end)
		remote:FireServer("SuperOn")

		-- Activar las partículas del Attachment "SCharge"
		local sChargeAttachment = self.hrp:FindFirstChild("Super")
		if sChargeAttachment then
			for _, particle in pairs(sChargeAttachment:GetDescendants()) do
				if particle:IsA("ParticleEmitter") then
					particle.Enabled = true

					_G.charinfo = require(game:GetService("Players").LocalPlayer.Character.CharacterInfo);

					_G.charinfo.physics.jog_speed = 0.0065
					_G.charinfo.physics.run_speed = 0.00115
					_G.charinfo.physics.run_accel = 0.105
					_G.charinfo.physics.rush_speed += 0
					_G.charinfo.physics.crash_speed += 0
					_G.charinfo.physics.dash_speed = 5.09
					_G.charinfo.physics.jmp_addit = 0.076
					_G.charinfo.physics.slow_down += 0
					_G.charinfo.physics.run_break += 0
					_G.charinfo.physics.air_break += 0
					_G.charinfo.physics.air_resist_air += 0
					_G.charinfo.physics.air_resist += 0
					_G.charinfo.physics.air_resist_y += 0
					_G.charinfo.physics.air_resist_z += 0
					_G.charinfo.physics.grd_frict += 0
					_G.charinfo.physics.grd_frict_z += 0
					_G.charinfo.physics.lim_frict += 0
					_G.charinfo.physics.rat_bound += 0
					_G.charinfo.physics.rad  += 0
					_G.charinfo.physics.height  += 0
					_G.charinfo.physics.weight += 0
					_G.charinfo.physics.eyes_height += 0
					_G.charinfo.physics.center_height += 0
				end
			end
		end
	end
	if self.rings < 99 then
		if issilver then
		remote:FireServer("SuperOff")
		_G.charinfo = require(game:GetService("Players").LocalPlayer.Character.CharacterInfo);
			_G.charinfo.physics.jog_speed = 0.70
		_G.charinfo.physics.run_speed = 1.6
		_G.charinfo.physics.run_accel = 0.065
		_G.charinfo.physics.rush_speed += 0
		_G.charinfo.physics.crash_speed += 0
		_G.charinfo.physics.dash_speed += 0
		_G.charinfo.physics.jmp_addit += 0
		_G.charinfo.physics.slow_down += 0
		_G.charinfo.physics.run_break += 0
		_G.charinfo.physics.air_break += 0
		_G.charinfo.physics.air_resist_air += 0
		_G.charinfo.physics.air_resist += 0
		_G.charinfo.physics.air_resist_y += 0
		_G.charinfo.physics.air_resist_z += 0
		_G.charinfo.physics.grd_frict += 0
		_G.charinfo.physics.grd_frict_z += 0
		_G.charinfo.physics.lim_frict += 0
		_G.charinfo.physics.rat_bound += 0
		_G.charinfo.physics.rad  += 0
		_G.charinfo.physics.height  += 0
		_G.charinfo.physics.weight += 0
		_G.charinfo.physics.eyes_height += 0
		_G.charinfo.physics.center_height += 0
		-- Activar las partículas del Attachment "SCharge"
		local sChargeAttachment = self.hrp:FindFirstChild("Super")
		if sChargeAttachment then
			for _, particle in pairs(sChargeAttachment:GetDescendants()) do
				if particle:IsA("ParticleEmitter") then
					particle.Enabled = false
				end
			end
		end
		end
	end
	
	
	if self.rings < 99 then
		if issilver then
			remote:FireServer("SuperOff")
			_G.charinfo = require(game:GetService("Players").LocalPlayer.Character.CharacterInfo);
			_G.charinfo.physics.jog_speed = 0.805
			_G.charinfo.physics.run_speed = 1.6
			_G.charinfo.physics.run_accel = 0.075
			_G.charinfo.physics.rush_speed += 0
			_G.charinfo.physics.crash_speed += 0
			_G.charinfo.physics.dash_speed += 0
			_G.charinfo.physics.jmp_addit += 0
			_G.charinfo.physics.slow_down += 0
			_G.charinfo.physics.run_break += 0
			_G.charinfo.physics.air_break += 0
			_G.charinfo.physics.air_resist_air += 0
			_G.charinfo.physics.air_resist += 0
			_G.charinfo.physics.air_resist_y += 0
			_G.charinfo.physics.air_resist_z += 0
			_G.charinfo.physics.grd_frict += 0
			_G.charinfo.physics.grd_frict_z += 0
			_G.charinfo.physics.lim_frict += 0
			_G.charinfo.physics.rat_bound += 0
			_G.charinfo.physics.rad  += 0
			_G.charinfo.physics.height  += 0
			_G.charinfo.physics.weight += 0
			_G.charinfo.physics.eyes_height += 0
			_G.charinfo.physics.center_height += 0
			-- Activar las partículas del Attachment "SCharge"
			local sChargeAttachment = self.hrp:FindFirstChild("Super")
			if sChargeAttachment then
				for _, particle in pairs(sChargeAttachment:GetDescendants()) do
					if particle:IsA("ParticleEmitter") then
						particle.Enabled = false
					end
				end
			end
		end
	end
	if charval.Value == "Super" then
		if self.rings > 275 then
			task.delay(1, function()

			end)
			remote:FireServer("SuperOn")

			-- Activar las partículas del Attachment "SCharge"
			local sChargeAttachment = self.hrp:FindFirstChild("Super")
			if sChargeAttachment then
				for _, particle in pairs(sChargeAttachment:GetDescendants()) do
					if particle:IsA("ParticleEmitter") then
						particle.Enabled = true

						_G.charinfo = require(game:GetService("Players").LocalPlayer.Character.CharacterInfo);

						_G.charinfo.physics.jog_speed = 0.0065
						_G.charinfo.physics.run_speed = 0.00115
						_G.charinfo.physics.run_accel = 0.1865
						_G.charinfo.physics.rush_speed += 0
						_G.charinfo.physics.crash_speed += 0
						_G.charinfo.physics.dash_speed = 5.09
						_G.charinfo.physics.jmp_addit = 0.076
						_G.charinfo.physics.slow_down += 0
						_G.charinfo.physics.run_break += 0
						_G.charinfo.physics.air_break += 0
						_G.charinfo.physics.air_resist_air += 0
						_G.charinfo.physics.air_resist += 0
						_G.charinfo.physics.air_resist_y += 0
						_G.charinfo.physics.air_resist_z += 0
						_G.charinfo.physics.grd_frict += 0
						_G.charinfo.physics.grd_frict_z += 0
						_G.charinfo.physics.lim_frict += 0
						_G.charinfo.physics.rat_bound += 0
						_G.charinfo.physics.rad  += 0
						_G.charinfo.physics.height  += 0
						_G.charinfo.physics.weight += 0
						_G.charinfo.physics.eyes_height += 0
						_G.charinfo.physics.center_height += 0
					end
				end
			end
		end
	end
	if self.rings < 275 then
		if charval.Value == "Super" then
		remote:FireServer("SuperOff")
		_G.charinfo = require(game:GetService("Players").LocalPlayer.Character.CharacterInfo);
		_G.charinfo.physics.jog_speed = 1.1
		_G.charinfo.physics.run_speed = 2.2
		_G.charinfo.physics.run_accel = 0.1465
		_G.charinfo.physics.rush_speed += 0
		_G.charinfo.physics.crash_speed += 0
		_G.charinfo.physics.dash_speed += 0
		_G.charinfo.physics.jmp_addit += 0
		_G.charinfo.physics.slow_down += 0
		_G.charinfo.physics.run_break += 0
		_G.charinfo.physics.air_break += 0
		_G.charinfo.physics.air_resist_air += 0
		_G.charinfo.physics.air_resist += 0
		_G.charinfo.physics.air_resist_y += 0
		_G.charinfo.physics.air_resist_z += 0
		_G.charinfo.physics.grd_frict += 0
		_G.charinfo.physics.grd_frict_z += 0
		_G.charinfo.physics.lim_frict += 0
		_G.charinfo.physics.rat_bound += 0
		_G.charinfo.physics.rad  += 0
		_G.charinfo.physics.height  += 0
		_G.charinfo.physics.weight += 0
		_G.charinfo.physics.eyes_height += 0
		_G.charinfo.physics.center_height += 0
		-- Activar las partículas del Attachment "SCharge"
		local sChargeAttachment = self.hrp:FindFirstChild("Super")
		if sChargeAttachment then
			for _, particle in pairs(sChargeAttachment:GetDescendants()) do
				if particle:IsA("ParticleEmitter") then
					particle.Enabled = false
				end
			end
		end
		end
		end
	if issonic then
		task.delay(1, function()

		end)
		remote:FireServer("SuperOn")

		-- Activar las partículas del Attachment "SCharge"
		local sChargeAttachment = self.hrp:FindFirstChild("Super")
		if sChargeAttachment then
			for _, particle in pairs(sChargeAttachment:GetDescendants()) do
				if particle:IsA("ParticleEmitter") then
					particle.Enabled = true

					_G.charinfo = require(game:GetService("Players").LocalPlayer.Character.CharacterInfo);
					_G.charinfo.physics.jog_speed = 0.008
					_G.charinfo.physics.run_speed = 0.00135
					_G.charinfo.physics.run_accel = 0.11
					_G.charinfo.physics.rush_speed += 0
					_G.charinfo.physics.crash_speed += 0
					_G.charinfo.physics.dash_speed = 5.09
					_G.charinfo.physics.jmp_addit = 0.08
					_G.charinfo.physics.slow_down += 0
					_G.charinfo.physics.run_break += 0
					_G.charinfo.physics.air_break += 0
					_G.charinfo.physics.air_resist_air += 0
					_G.charinfo.physics.air_resist += 0
					_G.charinfo.physics.air_resist_y += 0
					_G.charinfo.physics.air_resist_z += 0
					_G.charinfo.physics.grd_frict += 0
					_G.charinfo.physics.grd_frict_z += 0
					_G.charinfo.physics.lim_frict += 0
					_G.charinfo.physics.rat_bound += 0
					_G.charinfo.physics.rad  += 0
					_G.charinfo.physics.height  += 0
					_G.charinfo.physics.weight += 0
					_G.charinfo.physics.eyes_height += 0
					_G.charinfo.physics.center_height += 0
				end
			end
		end
	end
	if self.rings < 99 then
		if  charval.Value == "Sonic" then
		remote:FireServer("SuperOff")
		_G.charinfo = require(game:GetService("Players").LocalPlayer.Character.CharacterInfo);
		_G.charinfo.physics.jog_speed = 0.805
		_G.charinfo.physics.run_speed = 1.805
		_G.charinfo.physics.run_accel = 0.0825
		_G.charinfo.physics.rush_speed += 0
		_G.charinfo.physics.crash_speed += 0
		_G.charinfo.physics.dash_speed += 0
		_G.charinfo.physics.jmp_addit += 0
		_G.charinfo.physics.slow_down += 0
		_G.charinfo.physics.run_break += 0
		_G.charinfo.physics.air_break += 0
		_G.charinfo.physics.air_resist_air += 0
		_G.charinfo.physics.air_resist += 0
		_G.charinfo.physics.air_resist_y += 0
		_G.charinfo.physics.air_resist_z += 0
		_G.charinfo.physics.grd_frict += 0
		_G.charinfo.physics.grd_frict_z += 0
		_G.charinfo.physics.lim_frict += 0
		_G.charinfo.physics.rat_bound += 0
		_G.charinfo.physics.rad  += 0
		_G.charinfo.physics.height  += 0
		_G.charinfo.physics.weight += 0
		_G.charinfo.physics.eyes_height += 0
		_G.charinfo.physics.center_height += 0
		-- Activar las partículas del Attachment "SCharge"
		local sChargeAttachment = self.hrp:FindFirstChild("Super")
		if sChargeAttachment then
			for _, particle in pairs(sChargeAttachment:GetDescendants()) do
				if particle:IsA("ParticleEmitter") then
					particle.Enabled = false
				end
			end
		end
	end
end
	
	plrrings = self.rings
	
	
	
	--Super Transform.
	self.super_action = "Super"
	
	
	if self.input.button_press.super_action then
	if self.rings >= 50 and scd == false then 
		
		if charval.Value == "Sonic" then 
		
			
				
				-- Activar las partículas del Attachment "SCharge"
				local sChargeAttachment = self.hrp:FindFirstChild("SCharge")
				if sChargeAttachment then
					for _, particle in pairs(sChargeAttachment:GetDescendants()) do
						if particle:IsA("ParticleEmitter") then
							particle.Enabled = true
			local savepos = self.pos
			
								
				scd = true
				print("Can Super.")
				self:EnterBall()
				self.state = constants.state.inactive
				local anim = game.Players.LocalPlayer.Character.Humanoid.Animator:LoadAnimation(script.Transformanim)
							script.Sounds.ShowYou:Play()	
								
				
								--camShake:Shake(CameraShaker.Presets.Super)
				anim:Play()
				self:ExitBall()
				script.Sounds.SuperCharge:Play()
							task.delay(2.2, function()
								--camShake:Shake(CameraShaker.Presets.Super2)
								--sound.PlaySound(self, "hah!")
								remote:FireServer("BSuperOn")
								
								
							end)
								task.delay(2.65, function()
									script.Sounds["hah!"]:Play()
									
									--sound.PlaySound(self, "hah!")
								end)
				task.delay(2.7, function()
				
					script.Sounds.SuperEnable:Play()
					self.spd = Vector3.new(0,0,0)
					self.state = constants.state.airborne
					scd = false
					game.ReplicatedStorage.ChooseCharacter:FireServer("Super")
								script.Sounds.SuperCharge:Stop()
								
					
				 end)
			 end
		end
	end
				end
				
			end
			

--local charval = game.Players.LocalPlayer.Character.CharValue
--if charval.Value == "Super" then


	
		--self.rings = self.rings - 1
		--self.rings = self.rings - 1 == false
		--if self.rings == 0 then
			--game.ReplicatedStorage.LoadCharacter:FireServer()

		--end
	--end
--end

		local charval = game.Players.LocalPlayer.Character.CharValue
		if charval.Value == "Super" then
			self.shield = true
			if self.state == constants.state.airborne then
				if self.input.button.super_action and self.flag.grounded == false then
					self.state = constants.state.float2
				if self.flag.grounded then
					self.flag.grounded = true
					self.state = GetWalkState(self)
					self:Land()
				end
				end
			end
		end
	local charval = game.Players.LocalPlayer.Character.CharValue
	if charval.Value == "Super" then
			
		self.shield = true
		if self.boost_charge < 0 then
			game.ReplicatedStorage.LoadCharacter:FireServer()
			scd = false
		    
		end
	end
end
end








--Player draw

function player:Draw(dt)
	debug.profilebegin("player:Draw")
	
	--Force ball
	for _, part in pairs(workspace:GetPartBoundsInRadius(self.pos, 3)) do
		if part:IsDescendantOf(workspace:WaitForChild("Level"):WaitForChild("Objects"):WaitForChild("Forceball")) or part.Name == "Forceball" then
			if self.state ~= constants.state.roll then
				sound.PlaySound(self, "Roll")
				if self.spd.X < self.p.run_speed then
					self.spd = vector.SetX(self.spd, self.p.run_speed+0.2)
				end
			end
			self.state = constants.state.roll
			self:EnterBall()
			if self.spd.X < 0.05 then
				self.spd = vector.SetX(self.spd, 0.2)
				sound.PlaySound(self, "SpindashRelease") --You know what that means, FISH!
			end
		end
	end
	if self.player_draw and self.player_draw.Draw then
		--[nadiatimer]debug.profilebegin("player:Draw:Main")
		pcall(function()
			local hrp_cframe = (self.vis_ang + self.pos ) + (self.vis_ang.UpVector * self:GetCharacterYOff())
			self.hrp:PivotTo(hrp_cframe)
		end)
		--[nadiatimer]debug.profileend()
	end

	--(FOR CHAOS SNAP MOD) Visibility modifier and relative variables
	self.parts = {}
	for _,v in pairs(self.character:GetChildren()) do
		if v:IsA("BasePart") then
			table.insert(self.parts, v)
		end
	end
	local function ApplyVisible(self, vis)
		if vis ~= self.last_vis then
			for _,v in pairs(self.parts) do
				v.LocalTransparencyModifier = vis
			end
			self.last_vis = vis
		end
	end

	--(FOR CHAOS SNAP MOD) Disable this code if you don't want your character to disappear when snapping
	if self.animation == "ChaosSnap" then
		ApplyVisible(self, 1)
	else
		ApplyVisible(self, 0)
	end
	
	--Update animation and dynamic tilt
	animation.Animate(self)
	--animation.DynTilt(self, dt)
	pulley.Update(self)	
	poles.Update(self)

	--Update automation
	automation.FloorCheck(self, dt)

	
	
		
	--Get character position
	local balance = self.state == constants.state.rail and self.rail_balance or 0
	local off = self.state == constants.state.rail and self.rail_off or Vector3.new()
	self.vis_ang = (self:AngleToRbx(self.ang) * CFrame.Angles(0, 0, -balance)):Lerp(self.vis_ang, (0.675 ^ 60) ^ dt)

	local hrp_cframe = (self.vis_ang + self.pos + off) + (self.vis_ang.UpVector * self:GetCharacterYOff())

	--Set Player Draw state
	local ball_form, ball_spin
	if self.animation == "Roll" then
		ball_form = "JumpBall"
		ball_spin = animation.GetAnimationRate(self) * math.pi * 2
	elseif self.animation == "Spindash" then
		ball_form = "SpindashBall"
		ball_spin = animation.GetAnimationRate(self) * math.pi * 2
	else
		ball_form = nil
		ball_spin = 0
	end
	for i,v in pairs(self.mods) do -- No drawing priority, always draw at the same time as player_draw.
		if v.Draw then
			task.spawn(function()
				v.Draw(self, v, dt, hrp_cframe) -- Prevent thread halting
			end)
		end
	end
	self.player_draw:Draw(dt, hrp_cframe, ball_form, ball_spin, self:TrailActive(), self.shield, self.invincibility_time > 0, self:IsBlinking(), self.flag.boost_active, self)

	--Update sound source
	sound.UpdateSource(self)
	
	--Speed trail
	
		
	
				--keeprings = self.rings
				--keepscore = self.score
				--keeplives = UserSettings.lives
				--workspace:SetAttribute("SuperSwapCooldown", true)
				--task.delay(.25, function()
					--workspace:SetAttribute("SuperSwapCooldown", false)
				--end)

				--game.ReplicatedStorage.SuperSonic:FireServer(false, self.hrp.CFrame)
			--end
		--end
	--end
	--Speed trail
	--[[if math.abs(self.spd.X) >= (self.p.rush_speed + self.p.crash_speed) / 2 then
		self.speed_trail.Enabled = true
		self.speed_trail.TextureLength = math.abs(self.spd.X) * 0.875
	else
		self.speed_trail.Enabled = false
	end--]]
-- HIDE WARNINGS
	--if self.spd.X < 3 or self.state ~= constants.state.walk then
		--self.flag.last_valid_dash = os.clock()
	--end
	
	--function player:UpdateCamera(dt)
		--[nadiatimer]debug.profilebegin(`Player:UpdateCamera`)
		--if mod_settings["New Camera"] then
			--camera.update(self, dt)
		--end
		--[nadiatimer]debug.profileend()
	--end
	
	
	 local charval = game.Players.LocalPlayer.Character.CharValue
    if charval.Value == "Super" then
        self.shield = true
        if self.boost_charge < 0 then
            game.ReplicatedStorage.LoadCharacter:FireServer()
            scd = false
        end
    end



	--Rail speed trail
	if rail.GrindActive(self) and math.abs(self.spd.X) >= self.p.crash_speed then
		self.rail_speed_trail.Enabled = true
	else
		self.rail_speed_trail.Enabled = false
	end

	--Air kick trails
	if self.animation == "AirKick" then
		for _,v in pairs(self.air_kick_trails) do
			v.Enabled = false
		end
	else
		for _,v in pairs(self.air_kick_trails) do
			v.Enabled = false
		end
	end

	--Skid trail
	if self.animation == "Skid" then
		self.skid_effect.Enabled = true
	else
		self.skid_effect.Enabled = false
	end
	--Skid trail
	if self.animation == "Skid" then
		self.skid_effect.Enabled = true
	else
		self.skid_effect.Enabled = false
	end

	--Rail sparks
	if rail.GrindActive(self) and math.abs(self.spd.X) >= self.p.run_speed then
		self.rail_sparks.Enabled = true
		self.rail_sparks.Rate = math.abs(self.spd.X) * 90
		self.rail_sparks.EmissionDirection = (self.spd.X >= 0) and Enum.NormalId.Back or Enum.NormalId.Front
	else
		self.rail_sparks.Enabled = false
	end

	debug.profileend()
	
end

replicated_storage:WaitForChild('PlayerReplicate').OnClientEvent:Connect(function(Player,hrp_cframe)
	workspace:FindFirstChild(Player.Name).HumanoidRootPart.CFrame = hrp_cframe
end)
local IgnoreWarningList = {ModUI,Template,Errors,suc,err,UI,RegisterMod}
return player
