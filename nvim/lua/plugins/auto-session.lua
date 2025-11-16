return {
	-- https://github.com/rmagatti/auto-session
	"rmagatti/auto-session",
	enabled = true,
	lazy = false,
	opts = {
		suppressed_dirs = { "~/", "~/Downloads", "/" },
		-- Don't save diffview buffers
		bypass_save_filetypes = {
			"DiffviewFiles",
			"DiffviewFileHistory",
		},
	},
}
