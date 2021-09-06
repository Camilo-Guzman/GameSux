return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`GameSux` mod must be lower than Vermintide Mod Framework in your launcher's load order.")

		new_mod("GameSux", {
			mod_script       = "scripts/mods/GameSux/GameSux",
			mod_data         = "scripts/mods/GameSux/GameSux_data",
			mod_localization = "scripts/mods/GameSux/GameSux_localization",
		})
	end,
	packages = {
		"resource_packages/GameSux/GameSux",
	},
}
