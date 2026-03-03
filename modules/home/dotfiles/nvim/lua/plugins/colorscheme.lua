return {
  { "folke/tokyonight.nvim", enabled = false }, -- very persistent default
  -- { "ellisonleao/gruvbox.nvim" },
  --
  -- Add/set catppuccin
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    lazy = false,
    opts = {
      flavour = "macchiato", -- or mocha, frappe, etc.
    },
  },

  -- Configure LazyVim to load theme
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin-macchiato",
    },
  },
}
