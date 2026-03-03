-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("n", "[b", "<cmd>BufferLineMovePrev<cr>", { desc = "Move buffer tab left" })
vim.keymap.set("n", "]b", "<cmd>BufferLineMoveNext<cr>", { desc = "Move buffer tab right" })

-- Next bookmark
vim.keymap.set("n", "]B", function()
  require("spelunk").move_cursor(1)
end, { desc = "Next Bookmark" })

-- Previous bookmark
vim.keymap.set("n", "[B", function()
  require("spelunk").move_cursor(-1)
end, { desc = "Previous Bookmark" })
