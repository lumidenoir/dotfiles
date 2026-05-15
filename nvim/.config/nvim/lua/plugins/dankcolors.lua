return {
	{
		"RRethy/base16-nvim",
		priority = 1000,
		config = function()
			require('base16-colorscheme').setup({
				base00 = '#111418',
				base01 = '#111418',
				base02 = '#989da4',
				base03 = '#989da4',
				base04 = '#eff6ff',
				base05 = '#f8fbff',
				base06 = '#f8fbff',
				base07 = '#f8fbff',
				base08 = '#ff9fbb',
				base09 = '#ff9fbb',
				base0A = '#b0d2ff',
				base0B = '#a5ffb2',
				base0C = '#d5e7ff',
				base0D = '#b0d2ff',
				base0E = '#bedaff',
				base0F = '#bedaff',
			})

			vim.api.nvim_set_hl(0, 'Visual', {
				bg = '#989da4',
				fg = '#f8fbff',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Statusline', {
				bg = '#b0d2ff',
				fg = '#111418',
			})
			vim.api.nvim_set_hl(0, 'LineNr', { fg = '#989da4' })
			vim.api.nvim_set_hl(0, 'CursorLineNr', { fg = '#d5e7ff', bold = true })

			vim.api.nvim_set_hl(0, 'Statement', {
				fg = '#bedaff',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Keyword', { link = 'Statement' })
			vim.api.nvim_set_hl(0, 'Repeat', { link = 'Statement' })
			vim.api.nvim_set_hl(0, 'Conditional', { link = 'Statement' })

			vim.api.nvim_set_hl(0, 'Function', {
				fg = '#b0d2ff',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Macro', {
				fg = '#b0d2ff',
				italic = true
			})
			vim.api.nvim_set_hl(0, '@function.macro', { link = 'Macro' })

			vim.api.nvim_set_hl(0, 'Type', {
				fg = '#d5e7ff',
				bold = true,
				italic = true
			})
			vim.api.nvim_set_hl(0, 'Structure', { link = 'Type' })

			vim.api.nvim_set_hl(0, 'String', {
				fg = '#a5ffb2',
				italic = true
			})

			vim.api.nvim_set_hl(0, 'Operator', { fg = '#eff6ff' })
			vim.api.nvim_set_hl(0, 'Delimiter', { fg = '#eff6ff' })
			vim.api.nvim_set_hl(0, '@punctuation.bracket', { link = 'Delimiter' })
			vim.api.nvim_set_hl(0, '@punctuation.delimiter', { link = 'Delimiter' })

			vim.api.nvim_set_hl(0, 'Comment', {
				fg = '#989da4',
				italic = true
			})

			local current_file_path = vim.fn.stdpath("config") .. "/lua/plugins/dankcolors.lua"
			if not _G._matugen_theme_watcher then
				local uv = vim.uv or vim.loop
				_G._matugen_theme_watcher = uv.new_fs_event()
				_G._matugen_theme_watcher:start(current_file_path, {}, vim.schedule_wrap(function()
					local new_spec = dofile(current_file_path)
					if new_spec and new_spec[1] and new_spec[1].config then
						new_spec[1].config()
						print("Theme reload")
					end
				end))
			end
		end
	}
}
