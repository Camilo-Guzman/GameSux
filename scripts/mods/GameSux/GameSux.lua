local mod = get_mod("GameSux")

-- Text Localization
local _language_id = Application.user_setting("language_id")
local _localization_database = {}
mod._quick_localize = function (self, text_id)
    local mod_localization_table = _localization_database
    if mod_localization_table then
        local text_translations = mod_localization_table[text_id]
        if text_translations then
            return text_translations[_language_id] or text_translations["en"]
        end
    end
end
function mod.add_text(self, text_id, text)
    if type(text) == "table" then
        _localization_database[text_id] = text
    else
        _localization_database[text_id] = {
            en = text
        }
    end
end
mod:hook("Localize", function(func, text_id)
    local str = mod:_quick_localize(text_id)
    if str then return str end
    return func(text_id)
end)

-- THP & Stagger Talent Functions & Changes
mod:dofile("scripts/mods/GameSux/changes/thp_stagger_changes")

-- Weapon Changes
mod:dofile("scripts/mods/GameSux/changes/weapon_changes")

-- Kruber Changes
mod:dofile("scripts/mods/GameSux/changes/kruber_changes")

--Bardin Changes
mod:dofile("scripts/mods/GameSux/changes/bardin_changes")

--Kerillian changes
mod:dofile("scripts/mods/GameSux/changes/kerillian_changes")

--Victor changes
mod:dofile("scripts/mods/GameSux/changes/victor_changes")

--Sienna Changes
mod:dofile("scripts/mods/GameSux/changes/sienna_changes")

local function updateValues()
	for _, buffs in pairs(TalentBuffTemplates) do
		table.merge_recursive(BuffTemplates, buffs)
	end

	return

end

mod.on_enabled = function (self)
	mod:echo("enable")
	updateValues()

	return
end