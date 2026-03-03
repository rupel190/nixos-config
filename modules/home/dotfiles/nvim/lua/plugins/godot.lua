return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      gdscript = {
        -- Connect to Godot's internal LSP
        cmd = { "nc", "localhost", "6005" },
      },
    },
  },
}
