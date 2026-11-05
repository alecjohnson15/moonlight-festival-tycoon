--!strict
-- Runway poses. A walker strikes their chosen pose at the end of the runway.
-- Each joint is turned by { x, y, z } degrees from where it rests, on an R15
-- body (the game is set to R15; on other bodies the pose is skipped).
--
-- Rotations are about the joint, with the character facing -Z: a shoulder's
-- z turns the arm out to the side (right arm +, left arm -), its x lifts the
-- arm forward; an elbow's z bends the forearm in toward the body.
--
-- Free poses come with the game; others cost Sparkles, come with the
-- Supermodel Poses pass (Pass) or a Style Pass tier (Season).

export type Pose = {
	Id: string,
	Name: string,
	Price: number,
	Pass: string?,
	Season: number?,
	Joints: { [string]: { number } },
}

local Poses: { Pose } = {
	{
		Id = "hips",
		Name = "Hands on Hips",
		Price = 0,
		Joints = {
			RightShoulder = { 0, 0, 32 },
			RightElbow = { 0, 0, -82 },
			LeftShoulder = { 0, 0, -32 },
			LeftElbow = { 0, 0, 82 },
			Neck = { 0, 12, 0 },
		},
	},
	{
		Id = "wave",
		Name = "Big Wave",
		Price = 0,
		Joints = {
			RightShoulder = { 0, 0, 155 },
			RightElbow = { 0, 0, 25 },
			LeftShoulder = { 0, 0, -10 },
			Neck = { 0, 0, -8 },
		},
	},
	{
		Id = "peace",
		Name = "Peace Out",
		Price = 0,
		Joints = {
			RightShoulder = { 128, 0, 18 },
			RightElbow = { 72, 0, 0 },
			LeftShoulder = { 0, 0, -32 },
			LeftElbow = { 0, 0, 82 },
			Neck = { 0, 0, -12 },
		},
	},
	{
		Id = "tada",
		Name = "Ta-da!",
		Price = 0,
		Joints = {
			RightShoulder = { 0, 0, 135 },
			LeftShoulder = { 0, 0, -135 },
			Neck = { -8, 0, 0 },
		},
	},
	{
		Id = "kiss",
		Name = "Air Kiss",
		Price = 150,
		Joints = {
			RightShoulder = { 82, 0, -12 },
			RightElbow = { 100, 0, 0 },
			LeftShoulder = { 0, 0, -32 },
			LeftElbow = { 0, 0, 82 },
			Neck = { 0, -10, 8 },
		},
	},
	{
		Id = "cool_lean",
		Name = "Cool Lean",
		Price = 150,
		Joints = {
			Waist = { 0, 18, 8 },
			LeftShoulder = { 0, 0, -32 },
			LeftElbow = { 0, 0, 82 },
			RightShoulder = { 0, 0, 8 },
			Neck = { 0, -16, 0 },
			RightHip = { 0, 0, 8 },
		},
	},
	{
		Id = "point",
		Name = "Point at You",
		Price = 0,
		Season = 18,
		Joints = {
			RightShoulder = { 88, 0, 8 },
			LeftShoulder = { 0, 0, -32 },
			LeftElbow = { 0, 0, 82 },
			Neck = { 0, 0, 10 },
		},
	},
	{
		Id = "superstar",
		Name = "Superstar",
		Price = 0,
		Pass = "supermodel_poses",
		Joints = {
			RightShoulder = { 0, 0, 165 },
			LeftShoulder = { 0, 0, -32 },
			LeftElbow = { 0, 0, 82 },
			Waist = { 0, 0, -8 },
			RightHip = { 0, 0, 14 },
			Neck = { -10, 0, 0 },
		},
	},
	{
		Id = "heart_hands",
		Name = "Heart Hands",
		Price = 0,
		Pass = "supermodel_poses",
		Joints = {
			RightShoulder = { 0, 0, 150 },
			RightElbow = { 0, 0, 90 },
			LeftShoulder = { 0, 0, -150 },
			LeftElbow = { 0, 0, -90 },
		},
	},
	{
		Id = "hair_flip",
		Name = "Hair Flip",
		Price = 0,
		Pass = "supermodel_poses",
		Joints = {
			RightShoulder = { 0, 0, 165 },
			RightElbow = { 0, 0, 60 },
			LeftShoulder = { 0, 0, -32 },
			LeftElbow = { 0, 0, 82 },
			Neck = { 14, 0, 14 },
			Waist = { 0, 0, 10 },
		},
	},
	{
		Id = "victory",
		Name = "Victory",
		Price = 0,
		Pass = "supermodel_poses",
		Joints = {
			RightShoulder = { 0, 0, 140 },
			RightElbow = { 0, 0, -40 },
			LeftShoulder = { 0, 0, -140 },
			LeftElbow = { 0, 0, 40 },
			Neck = { 12, 0, 0 },
		},
	},
	{
		Id = "shy_wave",
		Name = "Shy Wave",
		Price = 0,
		Pass = "supermodel_poses",
		Joints = {
			RightShoulder = { 60, 0, -8 },
			RightElbow = { 64, 0, 0 },
			LeftShoulder = { 18, 0, 10 },
			LeftElbow = { 70, 0, 0 },
			Neck = { -10, 0, -14 },
		},
	},
	{
		Id = "power_lean",
		Name = "Power Lean",
		Price = 0,
		Pass = "supermodel_poses",
		Joints = {
			Waist = { 0, -24, -10 },
			RightShoulder = { 0, 0, 32 },
			RightElbow = { 0, 0, -82 },
			LeftShoulder = { 0, 0, -18 },
			LeftHip = { 0, 0, -12 },
			Neck = { 0, 22, 0 },
		},
	},
	{
		Id = "runway_royalty",
		Name = "Runway Royalty",
		Price = 0,
		Season = 20,
		Joints = {
			RightShoulder = { 0, 0, 55 },
			RightElbow = { 0, 0, 40 },
			LeftShoulder = { 0, 0, -55 },
			LeftElbow = { 0, 0, -40 },
			Neck = { 12, 0, 0 },
			Waist = { 6, 0, 0 },
		},
	},
}

local byId: { [string]: Pose } = {}
for _, pose in Poses do
	byId[pose.Id] = pose
end

return {
	List = Poses,
	Default = "hips",
	get = function(id: string): Pose?
		return byId[id]
	end,
}
