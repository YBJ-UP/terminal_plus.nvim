local state = {
	buf = nil,
	win = nil,
	is_open = false
}

local api = vim.api

local spawn_on_bottom = {
	close_on_leave = false,
	term_opts = {
		split = 'below',
		win = -1,
		height = 20
	}
}

local spawn_floating = {
	close_on_leave = true,
	floating_opts = {
		pos = 'center',
		width = 0.6,
		height = 0.5
	},
	term_opts = {
		relative = 'editor',
		border = 'single'
	}
}

local default_opts = {
	preset = "spawn_floating"
}

local current_opts = {}

local G = {}

local function get_floating_size(pos) -- pq no tiene switch el lua como me cae mal
	local posx, posy = 0.5, 0.5
	if pos == 'center' then
		posx, posy = 0.5, 0.5
	elseif pos == 'topcenter' then
		posx, posy = 0.5, 0
	elseif pos == 'bottocenter' then
		posx, posy = 0.5, 1.0
	elseif pos == 'topleft' then
		posx, posy = 0.0, 0.0
	elseif pos == 'topright' then
		posx, posy = 1.0, 0
	elseif pos == 'bottomleft' then
		posx, posy = 0.0, 1.0
	elseif pos == 'bottomright' then
		posx, posy = 1.0, 0.0
	else
		vim.notify("Posición inválida o no soportada: " .. pos .. "\nPosicionando en el centro", vim.log.levels.WARN)
		posx, posy = 0.5, 0.5
	end
	return posx, posy
end

local function set_config(preset)
	if preset == "spawn_on_bottom" then
		return spawn_on_bottom
	elseif preset == "spawn_floating" then
		return spawn_floating
	else
		vim.notify("Preset inválido: " .. preset .. "\nUtilizando el preset 'spawn_on_bottom' como alternativa",
			vim.log.levels.WARN)
		return spawn_on_bottom
	end
end

local function open_term(opts, cmd)
	-- se cierra si ya está abierta y es válida, para que sea como toggle
	if state.is_open and api.nvim_win_is_valid(state.win) then
		api.nvim_win_close(state.win, false)
	end

	if not state.buf or not api.nvim_buf_is_valid(state.buf) then
		state.buf = api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_keymap(state.buf, "n", "q", ":close<CR>", { noremap = true, silent = true })
		vim.bo[state.buf].bufhidden = 'hide'
	end

	if opts.floating_opts ~= nil then
		local posx, posy = get_floating_size(opts.floating_opts.pos)
		opts.term_opts.width = math.max(math.floor(vim.o.columns * opts.floating_opts.width), 64)
		opts.term_opts.height = math.floor(vim.o.lines * opts.floating_opts.height)

		opts.term_opts.col = math.floor((vim.o.columns - opts.term_opts.width) * posx)
		opts.term_opts.row = math.floor((vim.o.lines - opts.term_opts.height) * posy)

		vim.api.nvim_create_autocmd('VimResized', {
			callback = function()
				vim.defer_fn(function()
					if not api.nvim_win_is_valid(state.win) then
						return
					end
					opts.term_opts.width = math.max(math.floor(vim.o.columns * opts.floating_opts.width), 64)
					opts.term_opts.height = math.floor(vim.o.lines * opts.floating_opts.height)

					opts.term_opts.col = math.floor((vim.o.columns - opts.term_opts.width) * posx)
					opts.term_opts.row = math.floor((vim.o.lines - opts.term_opts.height) * posy)
					api.nvim_win_set_config(state.win, opts.term_opts)
				end, 20)
			end
		})
	end

	state.win = api.nvim_open_win(state.buf, true, opts.term_opts)

	local has_term = false
	local lines = api.nvim_buf_get_lines(state.buf, 0, -1, false)
	for _, line in ipairs(lines) do
		if line ~= "" then
			has_term = true
			break
		end
	end

	if not has_term then
		if cmd ~= nil then
			vim.fn.termopen(os.getenv("SHELL") .. ' -c ' .. cmd)
		else
			vim.fn.termopen(os.getenv("SHELL"))
		end
	end

	state.is_open = true
	vim.cmd("startinsert")

	if opts.close_on_leave then
		api.nvim_create_autocmd("BufLeave", {
			buffer = state.buf,
			callback = function()
				if state.is_open and api.nvim_win_is_valid(state.win) then
					api.nvim_win_close(state.win, false)
					state.is_open = false
				end
			end,
			once = true
		})
	end
end

local function setup_user_commands(opts)
	if opts == nil then
		opts = default_opts
	end
	if opts.preset ~= nil then
		opts = set_config(opts.preset)
	else
		opts = vim.tbl_deep_extend("force", default_opts, opts or {})
	end

	current_opts = opts

	api.nvim_create_user_command("OpenTerm", function()
		open_term(current_opts)
	end, {})

	vim.keymap.set("t", "<Esc>", function()
		if state.is_open then
			api.nvim_win_close(state.win, false)
			state.is_open = false
		end
	end, { noremap = true, silent = true })
end

G.setup = function(opts)
	setup_user_commands(opts)
end

G.exec = function(cmd)
	open_term(current_opts, cmd)
end

G.new = function()
	open_term(current_opts)
end

return G
