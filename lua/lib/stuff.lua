local api = vim.api
local tt = require("toggleterm")
local nn = require("notebook-navigator")
local nn_utils = require("notebook-navigator.utils")
local List = require("lib.list")

local M = {}

local term = require("toggleterm.terminal")
local Terminal = term.Terminal

local repls = {}

--local rlangrepl = { cmd = "R", direction = "horizontal", hidden = false, repl_type = "rlang"}

local replopts = {
    python = {
        cmd = "ipython --no-autoindent",
        direction = "horizontal",
        hidden = false,
        repl_type = "python",
    },
    r = {
        cmd = "R",
        direction = "horizontal",
        hidden = false,
        repl_type = "r",
    },
    default = {
        cmd = "zsh",
        direction = "horizontal",
        hidden = false,
        repl_type = nil,
    },
}

M.active_repl = nil

BFT = vim.bo.filetype

function M.optgen(repl_type)
    local ropts = {}
    for k, v in pairs(replopts[repl_type]) do
        ropts[k] = v
    end
    return ropts
end

function _update_buf_ft(bft)
    if bft ~= "toggleterm" then
        BFT = bft
    end
end

-- Local function from toggleterm.terminal that I needed to copy/paste here to use
-- in giving new terminals the correct index
-- function M.term_next_id()
    -- for index, term in pairs(all) do
    --     print(index)
    --     print(term.id)
    --     if index ~= term.id then
    --         return index
    --     end
    -- end
--     return #repls + 1
-- end

function M.get_term_by(key, value)
    local all = term.get_all(true)
    local matches = {}
    for index, term in pairs(all) do
        if term[key] == value then
            matches[index] = term
        end
    end
    return matches
end

function M.send_line()
    if M.active_repl == nil then
        M.new_ft_repl()
    end
    tt.send_lines_to_terminal("single_line", false, { args = M.active_repl })
end

function M.send_lines()
    if M.active_repl == nil then
        local current_window = api.nvim_get_current_win()
        M.new_ft_repl()
        api.nvim_set_current_win(current_window)
    end
    tt.send_lines_to_terminal("visual_lines", false, { args = M.active_repl }, true)
end

function M.send_visual_selection()
    if M.active_repl == nil then
        local current_window = api.nvim_get_current_win()
        M.new_ft_repl()
        api.nvim_set_current_win(current_window)
    end
    tt.send_lines_to_terminal("visual_selection", false, { args = M.active_repl }, true)
end

function M.run_cell_and_move()
    if M.active_repl == nil then
        local current_window = api.nvim_get_current_win()
        M.new_ft_repl()
        api.nvim_set_current_win(current_window)
    end
    local repl_args = {
        id = M.active_repl,
        -- Trimming spaces here screws up text sent to ipython
        trim_spaces = false,
    }
    nn.run_and_move(repl_args)
end

function M.set_active(id)
    local id = tonumber(id)
    if M.active_repl ~= nil then
        local last_active_term = M.get_term_by("id", M.active_repl)[M.active_repl]
        last_active_term.display_name = string.gsub(last_active_term.display_name, "*$", "")
    end
    local new_active_term = M.get_term_by("id", id)[id]
    if new_active_term == nil then
        print("invalid repl id: " .. id)
        os.exit()
    end
    M.active_repl = id
    new_active_term.display_name = string.format("%s%s", new_active_term.display_name, "*")
end

function M._new_repl(termopts, display_name, make_focused)
    termopts["display_name"] = display_name or "terminal"
    local repl = Terminal:new(termopts)
    if make_focused then
        M.active_repl = repl["id"]
    end
    return repl
end

function M.new_ft_repl(make_focused)
    _update_buf_ft(vim.bo.filetype)
    make_focused = make_focused or true
    local existing_repls = M.get_term_by("repl_type", BFT)
    local repl_display_name = string.format("%s-%s", BFT, #existing_repls + 1)
    local termopts = M.optgen(BFT) or M.optgen("default")
    M._new_repl(termopts, repl_display_name, make_focused):open()
end

function M.new_ft_repl_with_name(display_name, make_focused)
    M.new_ft_repl(M.replopts[BFT], display_name, make_focused)
end

function M.setup_commands()
    local command = api.nvim_create_user_command
    command("ReplSetActive", function(opts)
        M.set_active(opts.fargs[1])
    end, { nargs = 1 })
    command("ReplGetActive", function()
        print(M.active_repl)
    end, {})
    command("ToggleTermFtReplNew", function()
        M.new_ft_repl()
    end, {})
    command("TTNewRepl", function(opts)
        M._new_repl(M.optgen(opts.fargs[1]), opts.fargs[1], true):open()
    end, { nargs = 1 })
end

return M

-- Deprecate
-- function _create_or_toggle_repl()
--     _update_buf_ft(vim.bo.filetype)
--     if BFT == "python" then
--         local pyrepls = M.get_term_by("repl_type", BFT)
--         if #pyrepls == 0 then
--             M._new_repl(pyreplopts(), "ipython", true):open()
--         else
--             if #pyrepls == 1 then
--                 pyrepls[1]:toggle()
--                 M.active_repl = pyrepls[1]["id"]
--             else
--                 vim.cmd("Telescope toggleterm_mananger")
--             end
--         end
--     elseif BFT == "r" then
--         local rlangrepls = M.get_term_by("repl_type", BFT)
--         if #rlangrepls == 0 then
--             M._new_repl(rlangreplopts(), "r", true):open()
--         else
--             if #rlangrepls == 1 then
--                 rlangrepls[1]:toggle()
--                 M.active_repl = rlangrepls[1]["id"]
--             else
--                 vim.cmd("Telescope toggleterm_mananger")
--             end
--         end
--     else
--         tt.toggle_command()
--     end
-- end
--
-- -- shamelessly borrowed from harpoon
-- function M._create_window()
--     local height = 8
--     local width = 69
--     local bufnr = vim.api.nvim_create_buf(false, true)
--     local win_id = vim.api.nvim_open_win(bufnr, true, {
--         relative = "editor",
--         title = "REPLs",
--         --title_pos = toggle_opts.title_pos or "left",
--         row = math.floor(((vim.o.lines - height) / 2) - 1),
--         col = math.floor((vim.o.columns - width) / 2),
--         width = width,
--         height = height,
--         style = "minimal",
--         border = "double",
--         --border = toggle_opts.border or "single",
--     })
--     local repllist = List.ToggleTermReplList
--     repllist.items = { "a", "b", "c", "hi" }
--     local contents = repllist:display()
--     vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, contents)
-- end
