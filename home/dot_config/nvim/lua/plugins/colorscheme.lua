-- Match the rest of the environment (kitty / tmux / oh-my-posh): Catppuccin Macchiato.
return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    opts = { flavour = "macchiato" },
  },
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "catppuccin" },
  },
}
