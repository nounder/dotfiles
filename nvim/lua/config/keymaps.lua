vim.keymap.del("n", ";")
vim.keymap.del("n", "f")

vim.keymap.set("n", "<return>", "<cmd>w<cr><esc>", { desc = "Save file" })
vim.keymap.set("n", "<return>q", "<cmd>wq<cr><esc>", { desc = "Save file and quit" })

vim.keymap.set("n", "gl", "<c-w>w", { desc = "Other window" })

vim.keymap.set("n", "x", '"_x')
vim.keymap.set("v", "x", '"_x')

vim.keymap.set("n", "c", '"_c')
vim.keymap.set("v", "c", '"_c')

vim.keymap.set("n", ";q", "<Space>bd", { silent = true })

vim.keymap.set("i", "<M-BS>", "<C-w>", { noremap = true, silent = true })

vim.keymap.set("n", "<c-'>", function() Snacks.terminal(vim.o.shell, { cwd = LazyVim.root() }) end,
  { desc = "Terminal (floating, cwd)" })

vim.keymap.set("t", "<c-'>", function() Snacks.terminal(vim.o.shell, { cwd = LazyVim.root() }) end,
  { desc = "Terminal (floating, cwd)" })



vim.keymap.set("n", ";a", "i", { noremap = true, silent = true })
vim.keymap.set("i", ";a", "<Esc>", { noremap = true, silent = true })

vim.keymap.set("n", "<Space>uz", "<cmd>Zen<cr>", { desc = "Enter Zen" })
vim.keymap.set(
  "n",
  "<leader>bfP",
  ':let @+=expand("%:p")<CR>',
  { noremap = true, silent = true, desc = "Copy buffer file path (full)" }
)

vim.keymap.set(
  "n",
  "<leader>bfp",
  ':let @+=substitute(system("git rev-parse --show-toplevel"), "\\n", "", "") . "/" . expand("%:~:.")<CR>',
  { noremap = true, silent = true, desc = "Copy buffer file path (relative)" }
)
