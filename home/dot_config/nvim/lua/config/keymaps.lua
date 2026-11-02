-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

-- Selecting with the mouse copies to the clipboard on release, like in every other
-- tmux pane. nvim takes the mouse (LazyVim sets mouse=a), so tmux passes the drag
-- through and its own copy-on-release never runs: yank the selection to "+ (pbcopy,
-- or OSC 52 on headless Linux — see options.lua) and `gv` to keep it selected.
-- A release carries its press's click count, so a double-click (word), triple-click
-- (line) or quadruple-click (block) ends in <2-/3-/4-LeftRelease>, which a plain
-- <LeftRelease> mapping does not catch.
--
-- A click begun in INSERT mode delivers its release to insert-mode mappings, so the
-- x mapping never sees it, and on current nvim (0.12) a double-click's word selection
-- only exists once that release has been processed. So let the release through and
-- copy right after it, if a selection exists by then; a plain click is untouched.
local function copy_selection()
  if vim.fn.mode():match("^[vV\22]") then
    vim.cmd('normal! "+ygv')
  end
end
for _, lhs in ipairs({ "<LeftRelease>", "<2-LeftRelease>", "<3-LeftRelease>", "<4-LeftRelease>" }) do
  vim.keymap.set("x", lhs, '"+ygv', { desc = "Copy mouse selection to clipboard" })
  vim.keymap.set("i", lhs, function()
    vim.schedule(copy_selection)
    return lhs
  end, { expr = true, desc = "Copy mouse selection to clipboard" })
end
