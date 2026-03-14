local M = {
	defaults = {
		jumping_letters = "ASDFGHJKL",
		highlight = {
			jump_label = { fg = "#FFFFFF", bg = "#DB461D", bold = true },
			search_str = { fg = "#D0CADB", bg = "#47784C", bold = false },
		},
	},
}

local ns_id = vim.api.nvim_create_namespace("jumper_highlights")

local TERM_CODES = {
	ENTER = vim.api.nvim_replace_termcodes("<CR>", true, true, true),
	ESCAPE = vim.api.nvim_replace_termcodes("<ESC>", true, true, true),
	BACKSPACE = vim.api.nvim_replace_termcodes("<BS>", true, true, true),
	CTRL_W = vim.api.nvim_replace_termcodes("<C-W>", true, true, true),
	CTRL_BS = vim.api.nvim_replace_termcodes("<C-BS>", true, true, true),
}

local function find_matches_in_win(win_id, search_str)
	local matches = {}
	local bufnr = vim.api.nvim_win_get_buf(win_id)

	local row_start, row_end = table.unpack(vim.api.nvim_win_call(win_id, function()
		return { vim.fn.line("w0") - 1, vim.fn.line("w$") }
	end))

	local lines = vim.api.nvim_buf_get_lines(bufnr, row_start, row_end, false)

	if #search_str == 0 then
		return
	end

	for row, line in ipairs(lines) do
		local col = 1
		while true do
			local col_start, col_end = string.find(line:lower(), search_str:lower(), col, true)
			if not col_start then
				break
			end
			local next_char = line:sub(col_end + 1, col_end + 1)
			table.insert(matches, {
				win_id = win_id,
				bufnr = bufnr,
				row = row + row_start,
				col_start = col_start,
				col_end = col_end,
				next_char = next_char,
			})
			col = col_end + 1
		end
	end
	return matches
end

local function assign_labels(matches, labels)
	if #matches > #labels.single then
		labels = labels.double
	else
		labels = labels.single
	end

	local next_chars = {}
	for _, m in ipairs(matches) do
		next_chars[m.next_char:upper()] = true
	end

	local label_queue = {}
	for _, l in ipairs(labels) do
		if not next_chars[l:sub(1, 1)] then
			table.insert(label_queue, l)
		end
	end

	for _, m in ipairs(matches) do
		m.label = table.remove(label_queue, 1)
	end
end

local function any_label_stars_with(matches, char)
	for _, m in ipairs(matches) do
		if m.label and m.label:sub(1, 1):lower() == char:lower() then
			return true
		end
	end
	return false
end

local function render_matches(matches)
	for _, m in ipairs(matches) do
		vim.api.nvim_buf_add_highlight(m.bufnr, ns_id, "JumperSearchStr", m.row - 1, m.col_start - 1, m.col_end)

		if m.label then
			local label = m.label

			local vcol = vim.fn.virtcol({ m.row, m.col_start })
			local label_vcol = vcol - 1 - #label

			vim.api.nvim_buf_set_extmark(m.bufnr, ns_id, m.row - 1, 0, {
				virt_text = { { label, "JumperLabel" } },
				virt_text_pos = "overlay",
				virt_text_win_col = label_vcol,
			})
		end
	end

	vim.cmd("redraw")
end

local function label_input(matches, starting_char)
	local ok, char = true, starting_char

	while true do
		local filtered_matches = {}
		for _, m in ipairs(matches) do
			if m.label and m.label:sub(1, 1) == char:upper() then
				m.label = m.label:sub(2)
				table.insert(filtered_matches, m)
			end
		end
		matches = filtered_matches

		if #matches == 1 then
			local m = matches[1]
			vim.api.nvim_set_current_win(m.win_id)
			vim.api.nvim_win_set_cursor(m.win_id, { m.row, m.col_start - 1 })
			break
		elseif #matches == 0 then
			break
		end

		render_matches(matches)

		ok, char = pcall(vim.fn.getcharstr)

		if not ok or char == TERM_CODES.ESCAPE then
			break
		end
	end
end

function M.setup(user_config)
	M.config = vim.tbl_deep_extend("force", M.defaults, user_config or {})

	vim.api.nvim_set_hl(0, "JumperLabel", M.config.highlight.jump_label)
	vim.api.nvim_set_hl(0, "JumperSearchStr", M.config.highlight.search_str)

	local letters = M.config.jumping_letters
	local labels = {
		single = {},
		double = {},
	}
	for i = 1, #letters do
		table.insert(labels.single, letters:sub(i, i))
	end
	for i = 1, #letters do
		for j = 1, #letters do
			table.insert(labels.double, letters:sub(i, i) .. letters:sub(j, j))
		end
	end
	M.config.labels = labels
end

local function clear_namepace_and_cmd_line()
	local current_tab = vim.api.nvim_get_current_tabpage()
	local wins = vim.api.nvim_tabpage_list_wins(current_tab)

	for _, win in ipairs(wins) do
		local bufnr = vim.api.nvim_win_get_buf(win)
		vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
	end

	vim.api.nvim_echo({ { "", "" } }, false, {})
end

function M.interactive_search()
	local search_str = ""
	local matches = {}
	local current_tab = vim.api.nvim_get_current_tabpage()

	while true do
		clear_namepace_and_cmd_line()
		vim.api.nvim_echo({ { "[Jumper] Search: " .. search_str, "Question" } }, false, {})

		local ok, char = pcall(vim.fn.getcharstr)

		if not ok or char == TERM_CODES.ESCAPE or char == TERM_CODES.ENTER then
			break
		elseif char == TERM_CODES.BACKSPACE then
			search_str = search_str:sub(1, -2)
		elseif char == TERM_CODES.CTRL_W or char == TERM_CODES.CTRL_BS then
			search_str = ""
		elseif any_label_stars_with(matches, char) then
			clear_namepace_and_cmd_line()
			label_input(matches, char)
			break
		else
			search_str = search_str .. char
		end

		local wins = vim.api.nvim_tabpage_list_wins(current_tab)
		matches = {}

		for _, win in ipairs(wins) do
			local win_matches = find_matches_in_win(win, search_str)
			for _, wm in ipairs(win_matches) do
				table.insert(matches, wm)
			end
		end

		assign_labels(matches, M.config.labels)
		render_matches(matches)
	end

	clear_namepace_and_cmd_line()
end

return M
