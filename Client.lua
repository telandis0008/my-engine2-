-- Preloader
local Service = game:GetService("ContentProvider")

local Loads = {}
local Loads2 = {}
local Loads3 = {}
local Loads4 = {}
for i,v in pairs(game.ReplicatedFirst:GetDescendants()) do
	if v:IsA("Animation") then
		table.insert(Loads, v)
		table.insert(Loads, v.AnimationId)
	end
end
for i,v in pairs(game.ReplicatedFirst:GetDescendants()) do
	if v:IsA("LocalScript") then
		table.insert(Loads2, v)
	end
end
for i,v in pairs(game.ReplicatedFirst:GetDescendants()) do
	if v:IsA("Object") then
		table.insert(Loads3, v)
	end
end
for i,v in pairs(game.ReplicatedFirst:GetDescendants()) do
	if v:IsA("ModuleScript") then
		table.insert(Loads4, v)
	end
end

for i,v in pairs(Loads) do
	task.spawn(function()
		Service:PreloadAsync({v})
	end)
end