local CollectionService = game:GetService("CollectionService")

local ClientEffect = game.ReplicatedStorage.Requests.ClientEffect

local CameraShake = game.ReplicatedStorage.Requests.CameraShake

game.ServerStorage.Requests.TagHumanoid.Event:Connect(function(Character, Target, Properties, Limb)
	local CharacterData, TargetData = Character and game.ReplicatedStorage.AliveData:FindFirstChild(Character.Name), game.ReplicatedStorage.AliveData:FindFirstChild(Target.Name)

	local CharacterRoot, TargetRoot = Character and Character:FindFirstChild("HumanoidRootPart"), Target:FindFirstChild("HumanoidRootPart")

	local CharacterHumanoid, TargetHumanoid = Character and Character:FindFirstChild("Humanoid"), Target:FindFirstChild("Humanoid")

	local Player, TargetPlayer = Character and game.Players:GetPlayerFromCharacter(Character), game.Players:GetPlayerFromCharacter(Target)

	local PlayerData, TargetPlayerData = Player and game.ServerStorage.PlayerData:FindFirstChild(Player.Name), TargetPlayer and game.ServerStorage.PlayerData:FindFirstChild(TargetPlayer.Name)

	local Variables = {
		Damage = Properties.Damage or 0,
		AttackType = Properties.AttackType or "Physical",
		Backstab = false,
		StunMultiplier = Properties.StunMultiplier or 1,
		WeaponType = Properties.WeaponType or "",
		TargetWeaponType = TargetData:FindFirstChild("Has Weapon") and TargetData:FindFirstChild("Has Weapon").Type.Value or "",
		Force = Properties.Force or 5,
		Self = not Character or Character == Target,
		Push = Properties.Push,
		Ragdoll = Properties.Ragdoll or 0,
		Effects = Properties.Effects or {},
		Infusion = false,
		TargetRace = "Human",
		PostureGain = 0
	}

	if TargetHumanoid.Health <= 0 or TargetHumanoid:GetState() == Enum.HumanoidStateType.Dead or Target:FindFirstChild("Dead") then
		return
	end

	if Properties.Uppercut and CharacterData:FindFirstChild("SlamTarget") then
		return
	end

	local CustomRig = Target:FindFirstChild("CustomRig")

	if CustomRig then
		Variables.Ragdoll = 0
	end

	if Character and Character:FindFirstChild("HumanoidRootPart") then
		local Position = TargetRoot.CFrame:ToObjectSpace(Character.HumanoidRootPart.CFrame)

		if Position.Z > 0.5 then
			Variables.Backstab = true
		end
	end

	local function HitBuffs()
		for i,v in pairs(TargetData:children()) do
			if v.Name == "Blocking" or v.Name == "SlamTarget" then
				v:Destroy()
			end
		end

		for i,v in pairs(CharacterData:children()) do
			local RemoveOnHit = v:FindFirstChild("RemoveOnHit")

			if RemoveOnHit then
				game.Debris:AddItem(v, RemoveOnHit.Value)
			end
		end

		local Tag = Instance.new("Folder")
		Tag.Name = "KnockReset"
		Tag.Parent = TargetData
		game.Debris:AddItem(Tag, 0.5)

		if CharacterData and not TargetData:FindFirstChild("Knocked") then
			if not CharacterData:FindFirstChild("Vizard Activated") then
				CharacterData.Bars.Vizard.Value = math.min(CharacterData.Bars.Vizard.MaxValue, CharacterData.Bars.Vizard.Value + (Variables.Damage / 2))
			end

			if not CharacterData:FindFirstChild("Resurrection") and not CharacterData:FindFirstChild("Bankai") then
				CharacterData.Bars.Mode.Value = math.min(CharacterData.Bars.Mode.MaxValue, CharacterData.Bars.Mode.Value + (Variables.Damage / 4))
			end
		end

		if TargetData:FindFirstChild("Vizard Activated") then
			TargetData.Bars.Vizard.Value = math.max(TargetData.Bars.Vizard.MinValue, TargetData.Bars.Vizard.Value - (Variables.Damage / 2))
		end
	end

	local function ApplyBuffs()
		if CharacterData then
			for i,v in pairs(CharacterData:children()) do
				if v.Name == "SlamTarget" then
					v:Destroy()
				end
			end

			local Tag = Instance.new("NumberValue")
			Tag.Name = "Danger"
			Tag.Value = 60
			Tag.Parent = CharacterData
			game.Debris:AddItem(Tag, 60)

			local Tagger = Instance.new("ObjectValue")
			Tagger.Name = "Tagger"
			Tagger.Parent = Tag
			Tagger.Value = Target

			local Tag = Instance.new("NumberValue")
			Tag.Name = "Danger"
			Tag.Value = 60
			Tag.Parent = TargetData
			game.Debris:AddItem(Tag, 60)

			local Tagger = Instance.new("ObjectValue")
			Tagger.Name = "Tagger"
			Tagger.Parent = Tag
			Tagger.Value = Character
		end

		if Variables.Infusion then
			Variables.Damage *= 1.25
		end
	end

	local function TakeDamage(Multiplier)
		local Hit = TargetData.Hit

		local Damage = Variables.Damage * (Multiplier or 1)

		local CharacterTag = Hit:FindFirstChild(Character.Name) or Instance.new("NumberValue")
		CharacterTag.Name = Character.Name
		CharacterTag.Parent = Hit
		CharacterTag.Value += Damage

		local Current = CharacterTag.Value

		coroutine.wrap(function()
			task.wait(60)

			if CharacterTag and CharacterTag.Value == Current then
				CharacterTag:Destroy()
			end
		end)()

		task.spawn(function()
			if TargetData:FindFirstChild("Knocked") and not Properties.DownBypass then
				return
			end

			if TargetData:FindFirstChild("Ragdoll") and not Properties.RagdollBypass then
				return
			end

			if TargetPlayerData and TargetPlayerData.Passives:FindFirstChild("Vasto Rage") and not TargetData.Cooldowns:FindFirstChild("Vasto Rage") and not TargetData:FindFirstChild("Vasto Rage") then
				return
			end

			if (TargetHumanoid.Health - Damage) <= 1 and Properties.Lethal and not Target:FindFirstChild("Dead") and not Target:FindFirstChild("CustomRig") then
				TargetHumanoid.Health = 0

				game.ServerStorage.Requests.Kill:Fire(Target)
			end
		end)

		TargetHumanoid:TakeDamage(Damage)
	end

	local function Stun()
		if TargetData:FindFirstChild("SuperArmor") then
			return
		end

		local StunTime = 0.5 * Variables.StunMultiplier --0.325

		local RagdollTime = Variables.Ragdoll

		if RagdollTime > 0 then
			local Tag = Instance.new("Folder")
			Tag.Name = "Ragdoll"
			Tag.Parent = TargetData
			game.Debris:AddItem(Tag, RagdollTime)
		end

		if StunTime > 0 then
			if TargetData:FindFirstChild("HyperArmor") then
				return
			end

			if not TargetData:FindFirstChild("Downed") then
				for i,v in pairs(TargetHumanoid:GetPlayingAnimationTracks()) do
					if CollectionService:HasTag(v, "Stop") then
						v:Stop(0.05)
					end
				end

				local Name = "Hit"

				if Variables.Backstab then
					Name = "BackHit"
				end

				local Animation = TargetHumanoid:LoadAnimation(script.Animations:FindFirstChild(Name..math.random(1, 3)))
				Animation:Play()
				CollectionService:AddTag(Animation, "Stop")
			end

			local Tag = Instance.new("Folder")
			Tag.Name = "Stun"
			Tag.Parent = TargetData
			game.Debris:AddItem(Tag, StunTime)

			local Tag = Instance.new("Folder")
			Tag.Name = "No Jump"
			Tag.Parent = TargetData
			game.Debris:AddItem(Tag, 1)

			local Tag = Instance.new("Folder")
			Tag.Name = "No Dodge"
			Tag.Parent = TargetData
			game.Debris:AddItem(Tag, 1)
		end
	end

	local function Slam()
		if Properties.Slam then
			local Part, Pos, Norm = workspace:FindPartOnRayWithWhitelist(Ray.new(TargetRoot.Position, Vector3.new(0, -50, 0) + CharacterRoot.CFrame.lookVector*50), {workspace.Map})

			if Part then
				for i,v in pairs(TargetHumanoid:GetPlayingAnimationTracks()) do
					if CollectionService:HasTag(v, "Stop") then
						v:Stop(0.05)
					end
				end

				local Animation = TargetHumanoid:LoadAnimation(script.Animations:FindFirstChild("Slammed"))
				Animation:Play()
				CollectionService:AddTag(Animation, "Stop")

				coroutine.wrap(function()
					TargetRoot.Anchored = true

					coroutine.wrap(function()
						task.wait(0.05)

						game.TweenService:Create(TargetRoot, TweenInfo.new(0.1, Enum.EasingStyle.Exponential), {CFrame = (CFrame.new(Pos, Pos + Norm) * CFrame.Angles(math.rad(90), math.rad(180), math.rad(180))) * CFrame.new(0, 3, 0)}):Play()
					end)()

					game.ReplicatedStorage.Requests.ClientEffect:FireAllClients("Slammed", {Character = Target, Part = Part, Pos = Pos, Norm = Norm})

					task.wait(1)

					TargetRoot.Anchored = false
				end)()

				local Tag = Instance.new("Folder")
				Tag.Name = "No Speed"
				Tag.Parent = TargetData
				game.Debris:AddItem(Tag, 1)

				local Tag = Instance.new("Folder")
				Tag.Name = "Stun"
				Tag.Parent = TargetData
				game.Debris:AddItem(Tag, 1)

				local Tag = Instance.new("Folder")
				Tag.Name = "Downed"
				Tag.Parent = TargetData
				game.Debris:AddItem(Tag, 1)

				local Tag = Instance.new("Folder")
				Tag.Name = "No Rotate"
				Tag.Parent = TargetData
				game.Debris:AddItem(Tag, 1)

				if TargetPlayer then
					ClientEffect:FireClient(TargetPlayer, "Dazed", true)
				end

				if Player then
					for i,v in pairs(CharacterRoot:children()) do
						if v:IsA("BodyMover") and not CollectionService:HasTag(v, "NoRemove") then
							v:Destroy()
						end
					end

					game.ReplicatedStorage.Requests.BodyMover:FireClient(Player, {Type = "BodyVelocity", Velocity = Vector3.new(0, -80, 0) - CharacterRoot.CFrame.lookVector*80, MaxForce = Vector3.new(0, 80000, 0), Duration = 0.02, ClearMovers = true})
				end
			end
		end
	end

	local function Parried()
		for i,v in pairs(TargetData:children()) do
			if v.Name == "Parry Cool" or v.Name == "Parry Stun" then
				v:Destroy()
			end
		end

		if Player then
			ClientEffect:FireClient(Player, "Correction", true)

			CameraShake:FireClient(Player, "Parried")
		end

		if TargetPlayer then
			ClientEffect:FireClient(TargetPlayer, "Correction")

			CameraShake:FireClient(TargetPlayer, "Parried")
		end

		local Animations = game.ReplicatedStorage.Assets.Animations.Weapons:FindFirstChild(Variables.TargetWeaponType)

		if Animations then
			for i,v in pairs(TargetHumanoid:GetPlayingAnimationTracks()) do
				if CollectionService:HasTag(v, "Stop") then
					v:Stop(0.05)
				end
			end

			local Animation = TargetHumanoid:LoadAnimation(Animations:FindFirstChild("Parried"))
			Animation.Priority = Enum.AnimationPriority.Action3
			Animation:Play()
			CollectionService:AddTag(Animation, "Stop")
		end

		if CharacterData and CharacterHumanoid then
			for i,v in pairs(CharacterHumanoid:GetPlayingAnimationTracks()) do
				if CollectionService:HasTag(v, "Stop") then
					v:Stop(0.05)
				end
			end
			
			local animName = "Parried" .. math.random(1, 2)
			local animObj = script.Animations:FindFirstChild(animName)

			if not animObj then
				warn("Animation not found: " .. animName)
			else
				local Animation = CharacterHumanoid:LoadAnimation(animObj)
				Animation:Play()
				CollectionService:AddTag(Animation, "Stop")
			end


			local Tag = Instance.new("Folder")
			Tag.Name = "Parried Stun"
			Tag.Parent = CharacterData
			game.Debris:AddItem(Tag, 0.85) --0.65
		end

		local WeaponModels = {}

		for i, v in pairs(Target:GetDescendants()) do
			if CollectionService:HasTag(v, "Weapon") then
				table.insert(WeaponModels, v)
			end
		end

		ClientEffect:FireAllClients("Parried", {Models = WeaponModels, Character = Target})

		TargetData.Posture.Value = math.max(TargetData.Posture.Value - Variables.PostureGain, TargetData.Posture.MinValue)

		CharacterData.Posture.Value = math.min(CharacterData.Posture.Value + Variables.PostureGain, CharacterData.Posture.MaxValue)
	end

	local function Push()
		if CharacterData:FindFirstChild("SuperArmor") then
			return
		end

		local Force = Variables.Force

		if Force > 0 or Variables.Push then
			local Direction

			local MaxForce = Vector3.new(80000, 0, 80000)

			if Variables.Self then
				Direction = TargetRoot.CFrame.lookVector * -Force
			elseif CharacterRoot then
				Direction = ((TargetRoot.Position - CharacterRoot.Position).Unit * Vector3.new(1, 0, 1)) * Force
			end

			if Variables.Push then
				Direction = Variables.Push
				MaxForce = Vector3.new(Variables.Push.X > 0 and 80000 or 0, Variables.Push.Y > 0 and 80000 or 0, Variables.Push.Z > 0 and 80000 or 0)
			end

			local Duration = 0.3

			if math.abs(Direction.Magnitude) > 20 and Variables.Ragdoll <= 0 then
				local Tag = Instance.new("Folder")
				Tag.Name = "No Jump"
				Tag.Parent = TargetData
				game.Debris:AddItem(Tag, 0.25)

				local Tag = Instance.new("Folder")
				Tag.Name = "Heavy Slow"
				Tag.Parent = TargetData
				game.Debris:AddItem(Tag, 0.25)

				local Tag = Instance.new("Folder")
				Tag.Name = "No Rotate"
				Tag.Parent = TargetData
				game.Debris:AddItem(Tag, 0.25)

				for i, v in pairs(TargetHumanoid:GetPlayingAnimationTracks()) do
					if CollectionService:HasTag(v, "Stop") then
						v:Stop(0.05)
					end
				end

				local Animation = TargetHumanoid:LoadAnimation(script.Animations:FindFirstChild("Knockback"))
				Animation:Play()
				CollectionService:AddTag(Animation, "Stop")

				if not CustomRig then
					game.ReplicatedStorage.Requests.ClientEffect:FireAllClients("Knockback", {Character = Target, Direction = Direction})
				end

				if TargetPlayer then
					CameraShake:FireClient(TargetPlayer, "Knockback")
				end

				Duration = Duration * 1.5

				local function CheckWallBang()
					local Part, Pos, Norm = workspace:FindPartOnRayWithWhitelist(Ray.new(TargetRoot.Position, Direction * 0.1), {workspace.Map})

					if Part and Part.CanCollide and (math.abs(Norm.Y) == 1 or math.abs(Norm.Y) == 0) then
						game.ReplicatedStorage.Requests.ClientEffect:FireAllClients("WallBang", {Character = Target, Part = Part, Pos = Pos, Norm = Norm})

						if TargetData:FindFirstChild("Immortal") then
							return
						end

						if TargetData:FindFirstChild("DodgeFrame") then
							game.ReplicatedStorage.Requests.ClientEffect:FireAllClients("DodgeFX", {Character = Target})
							return
						end

						if TargetData:FindFirstChild("Parry") then
							Parried()
							return
						end

						if TargetPlayer then
							ClientEffect:FireClient(TargetPlayer, "BangDazed", true)
						end

						local Tag = Instance.new("Folder")
						Tag.Name = "Stun"
						Tag.Parent = TargetData
						game.Debris:AddItem(Tag, 0.75)

						local Tag = Instance.new("Folder")
						Tag.Name = "No Speed"
						Tag.Parent = TargetData
						game.Debris:AddItem(Tag, 0.75)

						local Tag = Instance.new("Folder")
						Tag.Name = "No Rotate"
						Tag.Parent = TargetData
						game.Debris:AddItem(Tag, 0.75)

						for i, v in pairs(TargetHumanoid:GetPlayingAnimationTracks()) do
							if CollectionService:HasTag(v, "Stop") then
								v:Stop(0.05)
							end
						end

						local Animation = TargetHumanoid:LoadAnimation(script.Animations.WallBanged)
						Animation:Play()
						CollectionService:AddTag(Animation, "Stop")

						task.spawn(function()
							TargetRoot.Anchored = true

							game.TweenService:Create(TargetRoot, TweenInfo.new(0.1, Enum.EasingStyle.Exponential), {CFrame = (CFrame.new(Pos, Pos + Norm)) * CFrame.new(0, 0, -0.5)}):Play()

							task.wait(0.75)

							TargetRoot.Anchored = false

							Animation:Stop(0.2)
						end)
					end
				end

				CheckWallBang()
			end

			if TargetPlayer and not TargetData:FindFirstChild("Ragdoll") then
				game.ReplicatedStorage.Requests.BodyMover:FireClient(TargetPlayer, {Type = "BodyVelocity", Velocity = Direction, MaxForce = MaxForce, Duration = 0.3, ClearMovers = true})
			else
				for i, v in pairs(TargetRoot:children()) do
					if v:IsA("BodyMover") and not CollectionService:HasTag(v, "NoRemove") then
						v:Destroy()
					end
				end

				local Velocity = Instance.new("BodyVelocity")
				Velocity.Parent = TargetRoot
				Velocity.MaxForce = MaxForce
				Velocity.Velocity = Direction

				game.Debris:AddItem(Velocity, Duration)
			end
		end

		if Properties.Uppercut and not CustomRig then
			if TargetPlayer then
				game.ReplicatedStorage.Requests.BodyMover:FireClient(TargetPlayer, {ClearMovers = true})
			end

			if Player then
				game.ReplicatedStorage.Requests.BodyMover:FireClient(Player, {ClearMovers = true})
			end

			for i, v in pairs(TargetHumanoid:GetPlayingAnimationTracks()) do
				if CollectionService:HasTag(v, "Stop") then
					v:Stop(0.05)
				end
			end

			local Animation = TargetHumanoid:LoadAnimation(script.Animations:FindFirstChild("AirHit"))
			Animation:Play()
			CollectionService:AddTag(Animation, "Stop")

			local Origin = CharacterRoot.Position + Vector3.new(0, 15, 0)

			for i, v in pairs(CharacterRoot:children()) do
				if v:IsA("BodyMover") and not CollectionService:HasTag(v, "NoRemove") then
					v:Destroy()
				end
			end

			for i, v in pairs(TargetRoot:children()) do
				if v:IsA("BodyMover") and not CollectionService:HasTag(v, "NoRemove") then
					v:Destroy()
				end
			end

			local BodyPosition = Instance.new("BodyPosition")
			BodyPosition.MaxForce = Vector3.new(80000, 80000, 80000)
			BodyPosition.P = 15000
			BodyPosition.D = 1000
			BodyPosition.Position = Origin
			BodyPosition.Name = "Uppercut"
			BodyPosition.Parent = CharacterRoot
			game.Debris:AddItem(BodyPosition, 1)

			local BodyPosition = Instance.new("BodyPosition")
			BodyPosition.MaxForce = Vector3.new(80000, 80000, 80000)
			BodyPosition.P = 15000
			BodyPosition.D = 1000
			BodyPosition.Name = "Uppercut"
			BodyPosition.Position = Origin + CharacterRoot.CFrame.lookVector * 4
			BodyPosition.Parent = TargetRoot
			game.Debris:AddItem(BodyPosition, 1)

			local Cooldown = Instance.new("Folder")
			Cooldown.Name = "Uppercut"
			Cooldown.Parent = CharacterData.Cooldowns
			game.Debris:AddItem(Cooldown, 5)

			local Tag = Instance.new("ObjectValue")
			Tag.Name = "SlamTarget"
			Tag.Value = Target
			Tag.Parent = CharacterData
			game.Debris:AddItem(Tag, 1)

			local Tag = Instance.new("Folder")
			Tag.Name = "Action"
			Tag.Parent = CharacterData
			game.Debris:AddItem(Tag, 0.25)

			local Tag = Instance.new("Folder")
			Tag.Name = "No Speed"
			Tag.Parent = CharacterData
			game.Debris:AddItem(Tag, 1)

			local Tag = Instance.new("Folder")
			Tag.Name = "No Jump"
			Tag.Parent = CharacterData
			game.Debris:AddItem(Tag, 1)

			local Tag = Instance.new("Folder")
			Tag.Name = "No Speed"
			Tag.Parent = TargetData
			game.Debris:AddItem(Tag, 1)

			local Tag = Instance.new("Folder")
			Tag.Name = "Stun"
			Tag.Parent = TargetData
			game.Debris:AddItem(Tag, 0.6)

			game.ReplicatedStorage.Requests.ClientEffect:FireAllClients("Uppercut", {Character = Target})

			if Player then
				CameraShake:FireClient(Player, "Parried")
			end
		end
	end

	local function Effect()


		for i,v in pairs(Variables.Effects) do
			ClientEffect:FireAllClients(v, {Character = Target})
		end

		if not Properties.NoEffect then
			ClientEffect:FireAllClients(Variables.WeaponType.."Hit", {Character = Target, Limb = Limb})

			if Variables.WeaponType == "Fist" then
				if TargetHumanoid.Health / TargetHumanoid.MaxHealth <= 0.4 then

				end
			end


		end

		if Variables.Backstab then
			ClientEffect:FireAllClients("Backstab", {Character = Target})
		end
	end

	local function PerfectBlocked()
		for i,v in pairs(TargetData:children()) do
			if v.Name == "Parry Cool" or v.Name == "Parry Stun" then
				v:Destroy()
			end
		end

		if Player then
			ClientEffect:FireClient(Player, "Correction2", true)

			CameraShake:FireClient(Player, "Parried")
		end

		if TargetPlayer then
			ClientEffect:FireClient(TargetPlayer, "Correction2")

			CameraShake:FireClient(TargetPlayer, "Parried")
		end

		local Animations = game.ReplicatedStorage.Assets.Animations.Weapons:FindFirstChild(Variables.TargetWeaponType)

		if Animations then
			for i,v in pairs(TargetHumanoid:GetPlayingAnimationTracks()) do
				if CollectionService:HasTag(v, "Stop") then
					v:Stop(0.05)
				end
			end

			local Animation = TargetHumanoid:LoadAnimation(Animations:FindFirstChild("Parried"..math.random(1, 2)))
			Animation.Priority = Enum.AnimationPriority.Action3
			Animation:Play()
			CollectionService:AddTag(Animation, "Stop")
		end

		if CharacterData and CharacterHumanoid then
			for i,v in pairs(CharacterHumanoid:GetPlayingAnimationTracks()) do
				if CollectionService:HasTag(v, "Stop") then
					v:Stop(0.05)
				end
			end

			local Animation = CharacterHumanoid:LoadAnimation(script.Animations.Parried)
			Animation:Play()
			CollectionService:AddTag(Animation, "Stop")

			local Tag = Instance.new("Folder")
			Tag.Name = "No Speed"
			Tag.Parent = CharacterData
			game.Debris:AddItem(Tag, 1)

			local Tag = Instance.new("Folder")
			Tag.Name = "Stun"
			Tag.Parent = CharacterData
			game.Debris:AddItem(Tag, 1)

			local Tag = Instance.new("Folder")
			Tag.Name = "Parried"
			Tag.Parent = CharacterData
			game.Debris:AddItem(Tag, 1)

			local Tag = Instance.new("Folder")
			Tag.Name = "No Rotate"
			Tag.Parent = CharacterData
			game.Debris:AddItem(Tag, 1)
		end

		ClientEffect:FireAllClients("Parry", {Character = Target})

		TargetData.Posture.Value = math.max(TargetData.Posture.Value - Variables.PostureGain, TargetData.Posture.MinValue)

		CharacterData.Posture.Value = math.min(CharacterData.Posture.Value + Variables.PostureGain, CharacterData.Posture.MaxValue)
	end

	local function Blocked()
		if Player then
			CameraShake:FireClient(Player, "Blocked")
		end

		if TargetPlayer then
			CameraShake:FireClient(TargetPlayer, "Blocked")
		end

		local BlockType = "Blunt"

		if Variables.WeaponType == "Sword" or Variables.WeaponType == "Blades" or Variables.WeaponType == "Dagger" or Variables.WeaponType == "Greataxe" or Variables.WeaponType == "Greatsword" or Variables.WeaponType == "Spear" then
			if Variables.TargetWeaponType == "Fist" or Variables.TargetWeaponType == "" then
				BlockType = "Flesh"
			else
				BlockType = "Clash"
			end
		end

		if BlockType == "Flesh" then
			local WeaponModels = {}

			for i, v in pairs(Target:GetDescendants()) do
				if CollectionService:HasTag(v, "Weapon") then
					table.insert(WeaponModels, v)
				end
			end

			ClientEffect:FireAllClients("FleshBlock", {Models = WeaponModels, Character = Target})

			TakeDamage(0.5)
		end

		if BlockType == "Blunt" then
			local WeaponModels = {}

			for i, v in pairs(Target:GetDescendants()) do
				if CollectionService:HasTag(v, "Weapon") then
					table.insert(WeaponModels, v)
				end
			end

			ClientEffect:FireAllClients("BluntBlock", {Models = WeaponModels, Character = Target})
		end

		if BlockType == "Clash" then
			local WeaponModels = {}

			for i, v in pairs(Target:GetDescendants()) do
				if CollectionService:HasTag(v, "Weapon") then
					table.insert(WeaponModels, v)
				end
			end

			ClientEffect:FireAllClients("BlockSpark", {Models = WeaponModels, Character = Target})
		end

		local Animations = game.ReplicatedStorage.Assets.Animations.Weapons:FindFirstChild(Variables.TargetWeaponType)

		if Animations then
			for i,v in pairs(TargetHumanoid:GetPlayingAnimationTracks()) do
				if CollectionService:HasTag(v, "Stop") then
					v:Stop(0.05)
				end
			end

			local Animation = TargetHumanoid:LoadAnimation(Animations:FindFirstChild("Flinch"..math.random(1, 3)))
			Animation:Play()
			CollectionService:AddTag(Animation, "Stop")
		end
	end

	local function BlockBreak()
		if Player then
			CameraShake:FireClient(Player, "BlockBreak")
		end

		if TargetPlayer then
			CameraShake:FireClient(TargetPlayer, "BlockBreak")
		end

		for i,v in pairs(TargetHumanoid:GetPlayingAnimationTracks()) do
			if CollectionService:HasTag(v, "Stop") then
				v:Stop(0.05)
			end
		end

		local Animation = TargetHumanoid:LoadAnimation(script.Animations.BlockBroken)
		Animation:Play()
		CollectionService:AddTag(Animation, "Stop")

		local Tag = Instance.new("Folder")
		Tag.Name = "No Speed"
		Tag.Parent = TargetData
		game.Debris:AddItem(Tag, 1)

		local Tag = Instance.new("Folder")
		Tag.Name = "Stun"
		Tag.Parent = TargetData
		game.Debris:AddItem(Tag, 1.2)

		local Tag = Instance.new("Folder")
		Tag.Name = "No Rotate"
		Tag.Parent = TargetData
		game.Debris:AddItem(Tag, 1)

		ClientEffect:FireAllClients("BlockBreak", {Character = Target})

		HitBuffs()
		TakeDamage(1.25)
		Slam()

		if TargetPlayer then
			ClientEffect:FireClient(TargetPlayer, "Dazed3", true)
		end
	end

	local function Hit()
		if Player then
			CameraShake:FireClient(Player, "Hit")
		end

		if TargetPlayer then
			CameraShake:FireClient(TargetPlayer, "Hit")
		end

		task.spawn(function()
			if TargetData:FindFirstChild("Knocked") and not Properties.DownBypass then
				return
			end

			if TargetData:FindFirstChild("Ragdoll") and not Properties.RagdollBypass then
				return
			end

			Stun()
			Push()
		end)

		TakeDamage()
		Effect()
		HitBuffs()
		Slam()
	end

	local function Dodged()
		game.ReplicatedStorage.Requests.ClientEffect:FireAllClients("DodgeFX", {Character = Target})
	end

	if Target:FindFirstChildWhichIsA("ForceField") then
		game.ReplicatedStorage.Requests.ClientEffect:FireAllClients("ForceFieldHit", {Character = Target})
		return
	end


	if TargetData:FindFirstChild("Being Carried") or TargetData:FindFirstChild("Being Gripped") then
		return
	end

	if TargetData:FindFirstChild("Immortal") then
		return
	end

	if (TargetData:FindFirstChild("Ragdoll") and not TargetData:FindFirstChild("Knocked")) and not Properties.RagdollBypass then
		return
	end

	if TargetData:FindFirstChild("Downed") and (not Properties.RagdollBypass and not Properties.DownBypass) then
		return
	end

	ApplyBuffs()

	Variables.PostureGain = (Variables.Damage * 3) * (Properties.Weight or 1)

	if TargetData:FindFirstChild("DodgeFrame") then
		Dodged()
		return
	end

	if TargetData:FindFirstChild("Parry") and Properties.BlockBreak then
		PerfectBlocked()
		return
	end

	if TargetData:FindFirstChild("Parry") then
		Parried()
		return
	end

	if TargetData:FindFirstChild("Blocking") and not Variables.Backstab then
		if Properties.BlockBreak then
			BlockBreak()		
			return
		end

		if not Properties.NoBlock then
			if (TargetData.Posture.Value + Variables.PostureGain) > TargetData.Posture.MaxValue then
				TargetData.Posture.Value = TargetData.Posture.MinValue

				BlockBreak()		
				return
			end

			TargetData.Posture.Value = math.min(TargetData.Posture.Value + Variables.PostureGain, TargetData.Posture.MaxValue)

			Blocked()
			return
		end
	end

	Hit()
end)
