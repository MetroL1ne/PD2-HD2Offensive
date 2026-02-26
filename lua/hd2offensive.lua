-- if not SC then
-- 	function ProjectileBase.check_time_cheat(projectile_type, owner_peer_id)
-- 		return true
-- 	end
-- end

--[[

data: {
	projectile_id:string -- 导弹类型
	position:Vector3     -- （必须的）基础轰炸位置
	rotation:Vector3     -- （必须的）旋转角度，会影响轰炸范围，发射偏移等

	range_x:number           -- 轰炸的x随机范围
	range_y:number           -- 轰炸的y随机范围
	bombs:number             -- 总发射的导弹数量
	timer:number             -- 发射完全部导弹的所需的时间
	neatly:boolean           -- 是够整齐发射（如飞鹰空袭）
	delay:number             -- 导弹抵达延迟
	kill_assets_delay:number -- 在导弹发射多久后删除资源（如模型，红线特效）
	random_x:boolean         -- 是否在x范围内随机
	random_y:boolean         -- 是否在y范围内随机

	launch_position:Vector3  -- 发射的基础起始位置，如果没有launch_position则用以下数值计算 : [
		height  -- 发射高度
		launch_angle_x  -- 发射位置的x偏移（默认为position + rotation:x() * height）
		launch_angle_y  -- 发射位置的y偏移（默认为position + rotation:y() * height）
	]

	type -- 轰炸类型: [
		"orbital"  -- 轨道，发射点为一个不变的点
		"fighter"  -- 飞鹰，发射点为扩散的几个点
	]
}

--]]

HD2Offensive = HD2Offensive or {}

function HD2Offensive:throw(data)
	local projectile_id = data.projectile_id or "rocket_ray_frag"
	local base_to_pos = data.position or Vector3()
	local rot = data.rotation or Vector3()
	local save_rot = mvector3.copy(rot)
	local unit = data.unit
	local name_id = data.name_id

	local range_x = data.range_x or 0
	local range_y = data.range_y or 0
	local bombs = data.bombs or 1
	local base_height = data.height or 8000
	local ray_angle_x = data.launch_angle_x or 0 
	local ray_angle_y = data.launch_angle_y or 0
	local type = data.type or "orbital"
	local timer = data.timer or 0
	local neatly_x = data.neatly_x
	local neatly_y = data.neatly_y
	local delay = data.delay or 0
	local delaye_t = timer / bombs
	local kill_assets_delay = data.kill_assets_delay or delay + delaye_t
	local random_x = not (tostring(data.random_x) == "false") and true or false
	local random_y = not (tostring(data.random_y) == "false") and true or false

	local position_fix = data.position_fix and Vector3(0, 0, data.position_fix) or Vector3(0, 0, 0)

	---[[ sync_hd2offensive_throw
	local data = {
		name_id = name_id,
		position = base_to_pos,
		timer = kill_assets_delay,
		time = delay,
		duration = timer,
		progress = type == "orbital",
		x = mvector3.x(base_to_pos),
		y = mvector3.y(base_to_pos),
		z = mvector3.z(base_to_pos)
	}

	HD2OffensiveRedTrail:spawn(data)
	HD2OffensiveHUD:new(data)

	LuaNetworking:SendToPeers("sync_hd2offensive_throw", json.encode(data))
	--]]

	local base_from_pos = (base_to_pos + (rot:x() * ray_angle_x) + (rot:y() * ray_angle_y)) + Vector3(0, 0, base_height)

	if data.launch_position then
		base_from_pos = data.launch_position
	end

	for i = 0, bombs - 1 do
		DelayedCalls:Add("EagleAirstrike:" .. tostring(i) .. tostring(TimerManager:game():time()), delaye_t * i + delay, function()
			if managers.network.session and managers.network:session() then
				local offset_x = 0
				local offset_y = 0
				local d_rot = rot or save_rot
				local function get_neatly_random(_range, _s, _i)
					local min = (_range / 2 - _range) + (_range / _s * (_i - 1))
					local max = (_range / 2 - _range) + (_range / _s * _i)

					return math.random(min, max)
				end

				local function get_neatly_not_random(_range, _s, _i)
					local min = (_range / 2 - _range) + (_range / _s * (_i - 1))
					local max = (_range / 2 - _range) + (_range / _s * _i)

					return (min + max) / 2
				end

				local function get_random(_range)
					local min = _range / 2 - _range
					local max = _range / 2

					return math.random(min, max)
				end

				local function get_not_random(_range)
					local min = _range / 2 - _range
					local max = _range / 2


					return (min + max) / 2
				end

				if neatly_x then
					if random_x then
						offset_x = get_neatly_random(range_x, bombs, i)
					else
						offset_x = get_neatly_not_random(range_x, bombs, i)
					end
				else
					if random_x then
						offset_x = get_random(range_x)
					else
						offset_x = get_not_random(range_x)
					end
				end

				if neatly_y then
					if random_y then
						offset_y = get_neatly_random(range_y, bombs, i)
					else
						offset_y = get_neatly_not_random(range_y, bombs, i)
					end
				else
					if random_y then
						offset_y = get_random(range_y)
					else
						offset_y = get_not_random(range_y)
					end
				end

				local from_pos = Vector3()
				local to_pos = Vector3()
				local mvec_spread_direction = Vector3()

				if type == "orbital" then
					from_pos = base_from_pos
					to_pos = base_to_pos + d_rot:x() * offset_x + d_rot:y() * offset_y
					mvec_spread_direction = ((to_pos - from_pos) + position_fix):normalized()
				elseif type == "fighter" then
					from_pos = base_from_pos + d_rot:x() * offset_x + d_rot:y() * offset_y
					to_pos = base_to_pos
					mvec_spread_direction = ((to_pos - base_from_pos) + position_fix):normalized()
				end

				if Network:is_client() then
					local projectile_type_index = tweak_data.blackmarket:get_index_from_projectile_id(projectile_id)

					managers.network:session():send_to_host("request_throw_projectile", projectile_type_index, from_pos, mvec_spread_direction)
				else
					local local_peer_id = managers.network:session():local_peer():id()
					local unit = ProjectileBase.throw_projectile(projectile_id, from_pos, mvec_spread_direction, local_peer_id)
				end
			end
		end)
	end

	DelayedCalls:Add("HD2OffensiveRedTrail:" .. tostring(TimerManager:game():time()), kill_assets_delay == 0 and 0.01 or kill_assets_delay, function()
		if alive(unit) then
			unit:set_slot(0)
			managers.network:session():send_to_peers("remove_unit", unit)
		end
	end)
end

HD2OffensiveRedTrail = HD2OffensiveRedTrail or {}

function HD2OffensiveRedTrail:spawn(data)
	local effect_id = World:effect_manager():spawn({
		effect = Idstring("effects/particles/weapons/hd2offensive/hd2offensive_red_trail"),
		position = data.position,
		normal = Vector3(0,0,1)
	})

	local delayed_id = "HD2OffensiveRedTrail" .. tostring(effect_id)
	local delay = TimerManager:game():time() + data.timer

	managers.enemy:add_delayed_clbk(delayed_id, callback(self, self, "_kill", effect_id), delay)

	return effect_id
end

function HD2OffensiveRedTrail:_kill(effect_id)
	if World:effect_manager():alive(effect_id) then
		World:effect_manager():kill(effect_id)
	end
end

HD2OffensiveHUD = HD2OffensiveHUD or class()

function HD2OffensiveHUD:init(data)
	-- self._id = tostring(data.id)
	self._id = "HD2oHUD" .. tostring(data.position) .. tostring(TimerManager:main():time())
	self._position = data.position
	self._left_time = data.time
	self._duration = data.duration
	self._progress = data.progress

	self._wait_text = managers.localization:to_upper_text("hud_hd2offensive_inbound") .. " "

	local hud = managers.hud:script(PlayerBase.PLAYER_INFO_HUD_FULLSCREEN_PD2)
	local hud_panel = hud.panel

	self._panel = hud_panel:panel({
		w = 200,
		h = 45
	})

	--- [[ Left
	self._base_panel = self._panel:panel({
		w = 30,
		h = self._panel:h()	
	})

	local base_panel = self._base_panel

	-- base_panel:set_left(0)
	base_panel:set_center_y(self._panel:h() / 2)

	local bg_size_sub = 5
	local bg = base_panel:bitmap({
		render_template = "VertexColorTexturedBlur3D",
		texture = "guis/textures/test_blur_df",
		w = base_panel:w() - bg_size_sub,
		h = base_panel:w() - bg_size_sub,
		color = Color.white
	})

	bg:set_center_x(base_panel:w() / 2)
	bg:set_center_y(bg:h() / 2 + bg_size_sub - 2.5)

	if data.name_id then
		local stratagem_icon = base_panel:bitmap({
			texture = "guis/dlcs/pd2_dlc_hd2o/textures/pd2/hud/icons/" .. data.name_id,
			layer = 2,
			w = 32,
			h = 32
		})

		stratagem_icon:set_center(bg:center_x(), bg:center_y())
	end
	
	local arrow_icon, arrow_texture_rect = tweak_data.hud_icons:get_icon_data("scrollbar_arrow")
	local arrow = base_panel:bitmap({
		visible = true,
		color = Color.yellow,
		rotation = 180,
		texture = arrow_icon,
		texture_rect = arrow_texture_rect,
		w = 12,
		h = 6
	})

	arrow:set_center_x(bg:center_x())
	arrow:set_bottom(base_panel:bottom() - 1)

	self._distance = base_panel:text({
		font = tweak_data.hud_players.ammo_font,
		text = "0",
		vertical = "bottom",
		align = "center",
		font_size = 10
	})

	self._distance:set_center_x(bg:center_x())
	self._distance:set_bottom(arrow:top())
	-- ]]

	--- [[ Right
	local bname = data.name_id and managers.localization:to_upper_text(data.name_id)

	local name_text = nil
	if bname then
		name_text = self._panel:text({
			font = tweak_data.hud_players.ammo_font,
			text = bname,
			-- vertical = "top",
			-- align = "left",
			font_size = 15,
			color = Color.red
		})

		name_text:set_left(base_panel:right())
	end

	self._time_text = self._panel:text({
		font = tweak_data.hud_players.ammo_font,
		text = self._wait_text .. os.date("%M:%S", self._left_time),
		vertical = "top",
		align = "left",
		font_size = 15
	})


	self._time_text:set_left(base_panel:right())

	if name_text then
		self._time_text:set_top(15)
	end
	-- ]]

	-- 添加update
	managers.hud:add_updator(self._id, callback(self, self, "update"))
end

function HD2OffensiveHUD:update(t, dt)
	local camera = managers.viewport:get_current_camera()

	if not camera then
		return
	end

	-- 获取并设置HUD在self._position上的2D空间位置
	local ws = managers.hud._workspace
	local screen_pos = ws:world_to_screen(camera, self._position)
	self._panel:set_left(screen_pos.x - self._base_panel:w() / 2)
	self._panel:set_bottom(screen_pos.y)

	-- 获取并设置玩家距离HUD原点的距离
	local distance = mvector3.distance(camera:position(), self._position)
	local m_text = managers.localization:text("hud_hd2offensive_m")
	self._distance:set_text(tostring(math.floor(distance / 100)) .. m_text)

	-- 检测HUD有没有在视野范围内
	if screen_pos.z > 1 then
		local screen_center = Vector3(ws:panel():center_x(), ws:panel():center_y(), 0)
		local HUDPos = Vector3(screen_pos.x, screen_pos.y, 0)
		local cen_to_hud_dis = mvector3.distance(screen_center, HUDPos)

		local max_alpha_dis = 150  -- 准心低于HUD距离多少开始透明度衰减
		local min_alpha = 0.6  -- 最低透明度
		if cen_to_hud_dis < max_alpha_dis then
			local new_alpha = math.max(cen_to_hud_dis / max_alpha_dis, min_alpha)
			self._panel:set_alpha(new_alpha)
		else
			self._panel:set_alpha(1)
		end
	else
		self._panel:set_alpha(0)
	end

	if self._left_time > 0 then
		self._left_time = self._left_time - dt
		self._time_text:set_text(self._wait_text .. os.date("%M:%S", self._left_time))
	elseif self._duration > 0 then
		self._duration = self._duration - dt

		local text = managers.localization:to_upper_text("hud_hd2offensive_impact")

		if self._progress then
			text = managers.localization:to_upper_text("hud_hd2offensive_ongoing")
			text = text .. " " .. os.date("%M:%S", self._duration)
		end

		self._time_text:set_text(text)
	end

	-- 如果倒计时结束，摧毁HUD
	if (self._left_time + self._duration) <= 0 then
		self:destroy()  -- 摧毁HUD

		managers.hud:remove_updator(self._id)  -- 关闭update
	end
end

function HD2OffensiveHUD:destroy()
	local hud = managers.hud:script(PlayerBase.PLAYER_INFO_HUD_FULLSCREEN_PD2)
	local hud_panel = hud.panel
	hud_panel:remove(self._panel)
end

