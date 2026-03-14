vim.api.nvim_create_user_command("JumpDown", function()
	require("jumper").interactive_search()
end, {})

vim.keymap.set({ "n", "v" }, ";", function()
	require("jumper").interactive_search()
end, { desc = "Interactive Jump" })

vim.keymap.set("n", "<leader>rp", function()
	package.loaded["jumper"] = nil
	require("jumper").setup({})
	print("Jumper reloaded")
end, { desc = "Interactive Jump" })
