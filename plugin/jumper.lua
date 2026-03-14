vim.api.nvim_create_user_command("JumperInteractiveSearch", function()
	require("jumper").interactive_search()
end, {})
