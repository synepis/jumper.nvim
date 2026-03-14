# jumper.nvim

Simple jumping plugin for Neovim. 

Basic configuration
```lua
{
    "synepis/jumper.nvim",
    config = function()
        local jumper = require("jumper")

        -- Config
        config = {
            jumping_letters = "ASDFGHJKL",
            highlight = {
                jump_label = { fg = "#FFFFFF", bg = "#DB461D", bold = true },
                search_str = { fg = "#D0CADB", bg = "#47784C", bold = false },
            },
        }
        jumper.setup(config)

        -- Key bidnings
        vim.keymap.set({ "n", "v" }, "<leader>j", function()
            jumper.interactive_search()
        end)
    end,
},
```
