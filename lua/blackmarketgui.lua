Hooks:PostHook(BlackMarketGui, "update_info_text", "hd2offensive_BMG_uit_set_text", function(self)
	local tab_data = self._tabs[self._selected]._data
	local identifier = tab_data.identifier

	if identifier == self.identifiers.grenade then
		local text_panel = self._info_texts[4]
		local start_find = "%$hd2o{"
		local end_find = "}"
		local color_ranges = {}
		local search_pos = 1

		while true do
			local org_text = text_panel:text()
			local find_pos, open_pos = org_text:find(start_find, search_pos)

			if not find_pos then
				break
			end

			local start_pos = open_pos + 1
			local close_pos = org_text:find(end_find, start_pos)

			if not close_pos then
				break
			end

			search_pos = close_pos + 1
			local end_pos = close_pos - 1
			local keys = org_text:sub(start_pos, end_pos)

			local grenade_tb = tweak_data.blackmarket.projectiles[self._slot_data.name]
			for i, key in ipairs(string.split(keys, "%.")) do
				grenade_tb = grenade_tb[key]
			end

			grenade_tb = tostring(grenade_tb)

			local org_find_text = start_find .. keys .. end_find
			local new_text = org_text:gsub(org_find_text, grenade_tb)

			text_panel:set_text(new_text)

			-- 存储文本范围颜色，也就是数值的颜色
			table.insert(color_ranges, {
				start = utf8.len(new_text:sub(1, find_pos)) - 1,
				stop = utf8.len(new_text:sub(1, find_pos)) + utf8.len(grenade_tb) - 1,
				color = Color(255, 254, 93, 99) / 255
			})
		end

		-- 设置数值的颜色
		for _, data in ipairs(color_ranges) do
			text_panel:set_range_color(data.start, data.stop, data.color)
		end
	end
end)