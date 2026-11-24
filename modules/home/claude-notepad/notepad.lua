-- nvim's half of claude-notepad.sh: the prompt for one Claude, sent with Enter in NORMAL
local dir, term = vim.env.CLAUDE_NOTEPAD_DIR, vim.env.CLAUDE_NOTEPAD_TERM
local buf = vim.api.nvim_get_current_buf()
local IMAGE = "%[Image #%d+%]"

vim.fn.writefile({ vim.env.HC_TERMINAL_ID }, dir .. "/term")
vim.bo[buf].swapfile = false
-- Not filetype markdown: its linters and formatters have no business in a prompt
vim.bo[buf].filetype = "claude-prompt"
pcall(vim.treesitter.start, buf, "markdown")
vim.wo.wrap, vim.wo.linebreak, vim.wo.conceallevel = true, true, 0
-- A completion menu would cover the few rows there are
vim.b[buf].completion = false

local function exists(name)
  return vim.uv.fs_stat(dir .. "/" .. name) ~= nil
end

local function read(name)
  return exists(name) and table.concat(vim.fn.readfile(dir .. "/" .. name), "\n") or ""
end

local function write(name, lines)
  vim.fn.writefile(lines, dir .. "/" .. name .. ".tmp", "b")
  vim.uv.fs_rename(dir .. "/" .. name .. ".tmp", dir .. "/" .. name)
end

local function text()
  return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end

-- noautocmd: no formatter may touch a prompt
local function save()
  vim.api.nvim_buf_call(buf, function()
    vim.cmd("silent! noautocmd write")
  end)
end

local function hc_get(terminal)
  local ok, info = pcall(vim.json.decode, vim.system({ "hc", "get", terminal or term, "--json" }, { text = true }):wait().stdout)
  return ok and info or {}
end

-- Types into Claude's terminal. `hc keys` would first wait for 3 s without a key from the person.
-- Attached only while typing: the terminal has the size of who typed last
local function keys(bytes)
  local info, seen = hc_get(), ""
  local job = vim.fn.jobstart({ "hc", "attach", term }, {
    pty = true,
    width = info.cols,
    height = info.rows,
    env = { TERM = "xterm-256color" },
    on_stdout = function(_, data)
      seen = seen .. table.concat(data, "\n")
    end,
  })
  if job <= 0 then
    return
  end
  -- hc asks the terminal what it is and listens once it has an answer
  vim.wait(500, function() return seen:find("\27[c", 1, true) ~= nil end, 5)
  local asked = #seen
  vim.fn.chansend(job, "\27[?62;22c")
  vim.wait(500, function() return #seen > asked end, 5)
  vim.fn.chansend(job, bytes)
  vim.wait(40)
  vim.fn.jobstop(job)
end

local CTRL_G, ENTER = "\7", "\r"

-- The pane is as tall as the text. herdr moves borders by pixels, as at zoom 1, where a row is 1.3
-- font sizes; the border is Claude's lower one to shrink and this pane's upper one to grow
local MIN_ROWS, MAX_ROWS = 2, 20
local win = vim.api.nvim_get_current_win()

local function herdr(...)
  local ok, value = pcall(vim.json.decode, vim.system({ "herdr-app", ... }, { text = true }):wait().stdout)
  return ok and value or {}
end

local function find_pane(node, terminal)
  if type(node) ~= "table" then
    return nil
  end
  if node.terminal == terminal then
    return node.pane
  end
  for _, child in pairs(node) do
    local pane = find_pane(child, terminal)
    if pane then
      return pane
    end
  end
end

local spaces, look = herdr("ls"), herdr("status")
local claude_pane, own_pane = find_pane(spaces, term), find_pane(spaces, vim.env.HC_TERMINAL_ID)
local row_px = (look.font_size or 14) / (look.zoom or 1) * 1.3

-- Claude keeps at least half of what the two have
local function claude_rows()
  return hc_get().rows or MAX_ROWS
end

local is_moving, tries = false, 0
-- Claude's rows without this pane
local before = tonumber(vim.env.CLAUDE_NOTEPAD_ROWS)

local function fit()
  local rows = math.min(MAX_ROWS, math.max(MIN_ROWS, vim.api.nvim_win_text_height(win, {}).all))
  if rows > vim.o.lines then
    rows = math.max(vim.o.lines, math.min(rows, math.floor((claude_rows() + vim.o.lines) / 2)))
  end
  if is_moving or (rows == vim.o.lines and not before) then
    return
  end
  -- A new size reaches nvim later than herdr-core
  local now = hc_get(vim.env.HC_TERMINAL_ID).rows or vim.o.lines
  local delta = rows - now
  if delta == 0 and before then
    -- For the next claude-notepad
    local lost = before - claude_rows() - now
    vim.fn.writefile({ tostring(math.min(12, math.max(1, lost))) }, dir .. "/../lost")
    before = nil
  end
  if delta == 0 or tries >= 4 or not claude_pane or not own_pane then
    return
  end
  is_moving, tries = true, tries + 1
  local move = {
    direction = delta > 0 and "up" or "down",
    pane = delta > 0 and own_pane or claude_pane,
    px = math.abs(delta) * row_px,
  }
  vim.system({ "herdr-app", "do", "pane.resize", vim.json.encode(move) }, {}, function()
    -- The new size arrives a little later
    vim.defer_fn(function()
      is_moving = false
      fit()
    end, 100)
  end)
end

local function refit()
  tries = 0
  fit()
end

-- A taller window keeps its first line and would show emptiness below the text
local function show_top()
  if vim.api.nvim_win_text_height(win, {}).all <= vim.o.lines then
    vim.fn.winrestview({ topline = 1 })
  end
end

-- A popup has no room either: warnings go under the line, gone with the next change
local ns = vim.api.nvim_create_namespace("claude-notepad")
local warned_text

local function clear_warning()
  warned_text = nil
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
end

local function warn(message)
  clear_warning()
  local line = vim.api.nvim_win_get_cursor(win)[1] - 1
  warned_text = text()
  vim.api.nvim_buf_set_extmark(buf, ns, line, 0, { virt_lines = { { { message, "WarningMsg" } } } })
  refit()
end

-- A question or permission prompt is open: Enter would answer it
local function is_blocked()
  local status = hc_get().status
  return type(status) == "table" and status.state == "blocked"
end

local function images_in(content)
  local found = {}
  for image in content:gmatch(IMAGE) do
    found[image] = true
  end
  return found
end

-- The image placeholders in Claude's own prompt, nil while it shows none: between the last two rules
-- on its screen. Not with Ctrl+G: that makes Claude drop a picture it is still loading
local function claude_images()
  local screen = vim.system({ "hc", "read", term }, { text = true }):wait().stdout or ""
  local prompt, current = "", nil
  for _, line in ipairs(vim.split(screen, "\n")) do
    if vim.startswith(line, "─────") then
      prompt, current = current or prompt, ""
    elseif current then
      current = current .. " " .. vim.trim(line)
    end
  end
  prompt = vim.trim((prompt:gsub("%s+", " ")))
  return vim.startswith(prompt, "❯") and images_in(prompt) or nil
end

-- Placeholders this buffer has held since the last message
local known = {}

local function remember()
  for image in pairs(images_in(text())) do
    known[image] = true
  end
end

-- Pictures wait here, as [Picture N], and Claude gets their files with the message
local PICTURE = "%[Picture (%d+)%]"
local SUFFIXES = { png = true, jpg = true, jpeg = true, gif = true, webp = true }
local pictures = dir .. "/pictures"
vim.fn.mkdir(pictures, "p")

local function picture_file(number)
  return vim.fn.glob(pictures .. "/" .. number .. ".*", false, true)[1]
end

local function next_number()
  local number = 1
  for _, file in ipairs(vim.fn.glob(pictures .. "/*", false, true)) do
    number = math.max(number, (tonumber(vim.fn.fnamemodify(file, ":t:r")) or 0) + 1)
  end
  return number
end

local function insert(content)
  vim.api.nvim_put({ content .. " " }, "c", vim.fn.mode() ~= "i", true)
end

-- What Claude made of the pictures it has been given, by number
local attached = {}

-- Gives Claude the message's pictures; answers the message with Claude's placeholders, or nil
local function attach_pictures(message)
  local numbers = {}
  for number in message:gmatch(PICTURE) do
    if picture_file(number) and not vim.tbl_contains(numbers, number) then
      table.insert(numbers, number)
    end
  end
  if #numbers == 0 then
    return message
  end
  for _, number in ipairs(numbers) do
    local before = claude_images()
    if not before then
      return nil
    end
    if not (attached[number] and before[attached[number]]) then
      attached[number] = nil
      keys("\27[200~" .. picture_file(number) .. "\27[201~")
      vim.wait(5000, function()
        for image in pairs(claude_images() or {}) do
          if not before[image] then
            attached[number], known[image] = image, true
          end
        end
        return attached[number] ~= nil
      end, 50)
      if not attached[number] then
        return nil
      end
    end
  end
  return (message:gsub(PICTURE, function(number)
    return attached[number]
  end))
end

local function send()
  local message = vim.trim(text())
  if message == "" then
    return
  end
  if is_blocked() then
    return warn("Not sent: Claude is asking something")
  end
  remember()
  message = attach_pictures(message)
  if not message then
    return warn("Not sent: Claude did not take the picture")
  end
  write("known", vim.list_extend(vim.tbl_keys(known), { "" }))
  write("outbox", vim.split(message, "\n"))
  keys(CTRL_G)
  if not vim.wait(3000, function() return not exists("outbox") end, 10) then
    vim.uv.fs_unlink(dir .. "/outbox")
    return warn("Not sent: Claude did not take it")
  end
  -- Claude takes its keyboard back first
  vim.wait(150)
  if is_blocked() then
    return warn("Claude asked something: the text is in its prompt, not sent")
  end
  keys(ENTER)
  known, attached = {}, {}
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(vim.trim(read("leftover")), "\n"))
  clear_warning()
  save()
  refit()
end

local function clipboard_image()
  local types = vim.system({ "wl-paste", "--list-types" }, { text = true }):wait().stdout or ""
  return types:find("image/png", 1, true) and "image/png" or types:match("image/%a+")
end

local function paste_image(mime)
  local number = next_number()
  local file = ("%s/%d.%s"):format(pictures, number, mime:match("/(%a+)"))
  local picture = vim.system({ "wl-paste", "--type", mime }):wait().stdout
  if not picture or picture == "" then
    return warn("No picture on the clipboard")
  end
  local out = assert(io.open(file, "wb"))
  out:write(picture)
  out:close()
  insert("[Picture " .. number .. "]")
end

-- A dropped picture comes as its path
local paste = vim.paste
vim.paste = function(lines, phase)
  local path = #lines == 1 and vim.trim(lines[1]):gsub("^['\"]", ""):gsub("['\"]$", ""):gsub("\\ ", " ") or ""
  local suffix = path:match("^/.*%.(%a+)$")
  if phase == -1 and suffix and SUFFIXES[suffix:lower()] and vim.uv.fs_stat(path) and vim.api.nvim_get_current_buf() == buf then
    local number = next_number()
    vim.uv.fs_copyfile(path, ("%s/%d.%s"):format(pictures, number, suffix:lower()))
    insert("[Picture " .. number .. "]")
    return true
  end
  return paste(lines, phase)
end

-- Pictures put into Claude's own prompt show up here too, on the way back
local function adopt()
  remember()
  for image in pairs(claude_images() or {}) do
    if not known[image] then
      known[image] = true
      insert(image)
    end
  end
end

local function to_end()
  vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(buf), 0 })
  vim.cmd("startinsert!")
end

-- Claude's draft, after what is here already
local function take()
  local incoming = read("incoming")
  vim.uv.fs_unlink(dir .. "/incoming")
  local here = text()
  -- Placeholders left in Claude's prompt come back with every Ctrl+G
  incoming = vim.trim((incoming:gsub(IMAGE, function(image)
    return here:find(image, 1, true) and "" or nil
  end)))
  if incoming ~= "" then
    local lines = vim.split(incoming, "\n")
    local at = vim.trim(here) == "" and 0 or -1
    vim.api.nvim_buf_set_lines(buf, at, -1, false, lines)
    remember()
    save()
    to_end()
    refit()
  end
  return "ok"
end
ClaudeNotepad = { take = take }

local function map(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc })
end
map("n", "<CR>", send, "Send to Claude")
map({ "n", "i" }, "<C-v>", function()
  local mime = clipboard_image()
  if mime then
    paste_image(mime)
  else
    vim.api.nvim_feedkeys(vim.keycode("<C-v>"), "n", false)
  end
end, "Paste a picture for Claude")

local function on(events, callback)
  vim.api.nvim_create_autocmd(events, { buffer = buf, callback = callback })
end
on({ "TextChanged", "InsertLeave", "VimLeavePre" }, save)
on({ "TextChanged", "TextChangedI" }, function()
  -- A save counts as a change too
  if warned_text ~= text() then
    clear_warning()
  end
  refit()
end)
vim.api.nvim_create_autocmd("FocusGained", { callback = adopt })
vim.api.nvim_create_autocmd("VimResized", { callback = vim.schedule_wrap(show_top) })

-- Every row is for the text; lualine brings its bar back as it loads
local function bare()
  vim.o.laststatus, vim.o.showtabline, vim.o.cmdheight = 0, 0, 0
end
bare()
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  callback = function()
    vim.schedule(function()
      pcall(function()
        require("lualine").hide()
      end)
      bare()
      refit()
    end)
  end,
})

take()
to_end()
refit()
