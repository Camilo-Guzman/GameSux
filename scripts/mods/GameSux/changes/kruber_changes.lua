local mod = get_mod("GameSux")

-- Buff and Talent Functions
local function merge(dst, src)
    for k, v in pairs(src) do
        dst[k] = v
    end
    return dst
end
function mod.add_talent_buff_template(self, hero_name, buff_name, buff_data, extra_data)   
    local new_talent_buff = {
        buffs = {
            merge({ name = buff_name }, buff_data),
        },
    }
    if extra_data then
        new_talent_buff = merge(new_talent_buff, extra_data)
    elseif type(buff_data[1]) == "table" then
        new_talent_buff = {
            buffs = buff_data,
        }
        if new_talent_buff.buffs[1].name == nil then
            new_talent_buff.buffs[1].name = buff_name
        end
    end
    TalentBuffTemplates[hero_name][buff_name] = new_talent_buff
    BuffTemplates[buff_name] = new_talent_buff
    local index = #NetworkLookup.buff_templates + 1
    NetworkLookup.buff_templates[index] = buff_name
    NetworkLookup.buff_templates[buff_name] = index
end
function mod.modify_talent_buff_template(self, hero_name, buff_name, buff_data, extra_data)   
    local new_talent_buff = {
        buffs = {
            merge({ name = buff_name }, buff_data),
        },
    }
    if extra_data then
        new_talent_buff = merge(new_talent_buff, extra_data)
    elseif type(buff_data[1]) == "table" then
        new_talent_buff = {
            buffs = buff_data,
        }
        if new_talent_buff.buffs[1].name == nil then
            new_talent_buff.buffs[1].name = buff_name
        end
    end

    local original_buff = TalentBuffTemplates[hero_name][buff_name]
    local merged_buff = original_buff
    for i=1, #original_buff.buffs do
        if new_talent_buff.buffs[i] then
            merged_buff.buffs[i] = merge(original_buff.buffs[i], new_talent_buff.buffs[i])
        elseif original_buff[i] then
            merged_buff.buffs[i] = merge(original_buff.buffs[i], new_talent_buff.buffs)
        else
            merged_buff.buffs = merge(original_buff.buffs, new_talent_buff.buffs)
        end
    end

    TalentBuffTemplates[hero_name][buff_name] = merged_buff
    BuffTemplates[buff_name] = merged_buff
end
function mod.add_buff_template(self, buff_name, buff_data)   
    local new_talent_buff = {
        buffs = {
            merge({ name = buff_name }, buff_data),
        },
    }
    BuffTemplates[buff_name] = new_talent_buff
    local index = #NetworkLookup.buff_templates + 1
    NetworkLookup.buff_templates[index] = buff_name
    NetworkLookup.buff_templates[buff_name] = index
end
function mod.add_proc_function(self, name, func)
    ProcFunctions[name] = func
end
function mod.add_buff_function(self, name, func)
    BuffFunctionTemplates.functions[name] = func
end
function mod.modify_talent(self, career_name, tier, index, new_talent_data)
	local career_settings = CareerSettings[career_name]
    local hero_name = career_settings.profile_name
	local talent_tree_index = career_settings.talent_tree_index

	local old_talent_name = TalentTrees[hero_name][talent_tree_index][tier][index]
	local old_talent_id_lookup = TalentIDLookup[old_talent_name]
	local old_talent_id = old_talent_id_lookup.talent_id
	local old_talent_data = Talents[hero_name][old_talent_id]

    Talents[hero_name][old_talent_id] = merge(old_talent_data, new_talent_data)
end
function mod.add_buff(self, owner_unit, buff_name)
    if Managers.state.network ~= nil then
        local network_manager = Managers.state.network
        local network_transmit = network_manager.network_transmit

        local unit_object_id = network_manager:unit_game_object_id(owner_unit)
        local buff_template_name_id = NetworkLookup.buff_templates[buff_name]
        local is_server = Managers.player.is_server

        if is_server then
            local buff_extension = ScriptUnit.extension(owner_unit, "buff_system")

            buff_extension:add_buff(buff_name)
            network_transmit:send_rpc_clients("rpc_add_buff", unit_object_id, buff_template_name_id, unit_object_id, 0, false)
        else
            network_transmit:send_rpc_server("rpc_add_buff", unit_object_id, buff_template_name_id, unit_object_id, 0, true)
        end
    end
end

--Mercenary
--Passive Changes
mod:modify_talent_buff_template("empire_soldier", "markus_mercenary_ability_cooldown_on_damage_taken", {
    bonus = 0.25
})

--lvl 10
mod:modify_talent_buff_template("empire_soldier", "markus_mercenary_damage_on_enemy_proximity", {
    max_stacks = 5,
    multiplier = 0.04

})
mod:modify_talent("es_mercenary", 2, 1, {
    description_values = {
        {
            value_type = "percent",
            value = 0.04
        },
        {
            value = 5
        }
    },
})
mod:modify_talent_buff_template("empire_soldier", "markus_mercenary_power_level_cleave", {
    multiplier = 1
})
mod:modify_talent("es_mercenary", 2, 1, {
    description_values = {
        {
            value_type = "percent",
            value = 1
        }
	},
})
--crit talent

--lvl 20
--gain_markus_mercenary_passive_proc = function (player, buff, params) BuffFunctionTemplates.
mod:hook_origin(BuffFunctionTemplates, "functions.gain_markus_mercenary_passive_proc", function(self, player, buff, params)
	if not Managers.state.network.is_server then
		return
	end

	local player_unit = player.player_unit
	local owner_unit = player_unit
	local buff_template = buff.template
	local target_number = params[4]
	local attack_type = params[2]
	local buff_to_add = buff_template.buff_to_add
	local buff_system = Managers.state.entity:system("buff_system")
	local buff_applied = true

	if Unit.alive(player_unit) and target_number and buff_template.targets <= target_number and (attack_type == "light_attack" or attack_type == "heavy_attack") then
		local talent_extension = ScriptUnit.extension(player_unit, "talent_system")

		if talent_extension:has_talent("markus_mercenary_passive_improved", "empire_soldier", true) then
			if target_number >= 1 then
				buff_system:add_buff(player_unit, "markus_mercenary_passive_improved", owner_unit, false)
			else
				buff_applied = false
			end
		elseif talent_extension:has_talent("markus_mercenary_passive_group_proc", "empire_soldier", true) then
			local side = Managers.state.side.side_by_unit[player_unit]
			local player_and_bot_units = side.PLAYER_AND_BOT_UNITS
			local num_units = #player_and_bot_units

			for i = 1, num_units, 1 do
				local unit = player_and_bot_units[i]

				if Unit.alive(unit) then
					buff_system:add_buff(unit, buff_to_add, owner_unit, false)
				end
			end
		elseif talent_extension:has_talent("markus_mercenary_passive_power_level_on_proc", "empire_soldier", true) then
			buff_system:add_buff(player_unit, "markus_mercenary_passive_power_level", owner_unit, false)
			buff_system:add_buff(player_unit, buff_to_add, owner_unit, false)
		else
			buff_system:add_buff(player_unit, buff_to_add, owner_unit, false)
		end

		if talent_extension:has_talent("markus_mercenary_passive_defence_on_proc", "empire_soldier", true) and buff_applied then
			buff_system:add_buff(player_unit, "markus_mercenary_passive_defence", owner_unit, false)
		end
	end
end)

mod:modify_talent_buff_template("empire_soldier", "markus_mercenary_passive_power_level", {
    multiplier = 0.2
})
mod:modify_talent("es_mercenary", 4, 1, {
    description_values = {
        {
            value_type = "percent",
            value = 0.2
        }
	},
})

--lvl 25
-- Ammo Talent

--lvl 30
mod:modify_talent_buff_template("empire_soldier", "markus_mercenary_activated_ability_cooldown_no_heal", {
    multiplier = -0.25
})
mod:modify_talent("es_mercenary", 6, 1, {
    description_values = {
        {
            value_type = "percent",
            value = 0.25
        },
    },
})
mod:add_talent_buff_template("empire_soldier", "markus_mercenary_activated_ability_damage_reduction_revive", {
    max_stacks = 1,
    icon = "markus_mercenary_activated_ability_damage_reduction",
    stat_buff = "damage_taken",
    multiplier = -0.70,
	duration = 10
})

mod:hook_origin(CareerAbilityESMercenary, "_run_ability", function(self, new_initial_speed)
	self:_stop_priming()

	local world = self._world
	local owner_unit = self._owner_unit
	local is_server = self._is_server
	local local_player = self._local_player
	local bot_player = self._bot_player
	local network_manager = self._network_manager
	local network_transmit = network_manager.network_transmit
	local career_extension = self._career_extension
	local talent_extension = ScriptUnit.extension(owner_unit, "talent_system")

	CharacterStateHelper.play_animation_event(owner_unit, "mercenary_active_ability")

	local radius = 15
	local nearby_player_units = FrameTable.alloc_table()
	local proximity_extension = Managers.state.entity:system("proximity_system")
	local broadphase = proximity_extension.player_units_broadphase

	Broadphase.query(broadphase, POSITION_LOOKUP[owner_unit], radius, nearby_player_units)

	local side_manager = Managers.state.side
	local revivable_units = FrameTable.alloc_table()

	for _, friendly_unit in pairs(nearby_player_units) do
		if not side_manager:is_enemy(self._owner_unit, friendly_unit) then
			local friendly_unit_status_extension = ScriptUnit.extension(friendly_unit, "status_system")

			if friendly_unit_status_extension:is_available_for_career_revive() then
				revivable_units[#revivable_units + 1] = friendly_unit
			end
		end
	end

	local owner_unit_go_id = network_manager:unit_game_object_id(owner_unit)

	if talent_extension:has_talent("markus_mercenary_activated_ability_revive") then
		for _, player_unit in pairs(revivable_units) do
			local target_unit_go_id = network_manager:unit_game_object_id(player_unit)

			network_transmit:send_rpc_server("rpc_request_revive", target_unit_go_id, owner_unit_go_id)
			CharacterStateHelper.play_animation_event(player_unit, "revive_complete")
			local buff_system = Managers.state.entity:system("buff_system")

			buff_system:add_buff(player_unit, "markus_mercenary_activated_ability_damage_reduction_revive", self._owner_unit, false)
		end
	end

	local heal_amount = 25

	if talent_extension:has_talent("markus_mercenary_activated_ability_improved_healing") then
		heal_amount = 45
	end

	local heal_type_id = NetworkLookup.heal_types.career_skill

	for _, player_unit in pairs(nearby_player_units) do
		if not side_manager:is_enemy(self._owner_unit, player_unit) then
			local unit_go_id = network_manager:unit_game_object_id(player_unit)

			if unit_go_id then
				if talent_extension:has_talent("markus_mercenary_activated_ability_damage_reduction") then
					local buff_system = Managers.state.entity:system("buff_system")

					buff_system:add_buff(player_unit, "markus_mercenary_activated_ability_damage_reduction", self._owner_unit, false)
				end

				network_transmit:send_rpc_server("rpc_request_heal", unit_go_id, heal_amount, heal_type_id)
			end
		end
	end

	if (is_server and bot_player) or local_player then
		local first_person_extension = self._first_person_extension

		first_person_extension:animation_event("ability_shout")
		first_person_extension:play_hud_sound_event("Play_career_ability_mercenary_shout_out")
		first_person_extension:play_remote_unit_sound_event("Play_career_ability_mercenary_shout_out", owner_unit, 0)
	end

	local explosion_template_name = "kruber_mercenary_activated_ability_stagger"
	local explosion_template = ExplosionTemplates[explosion_template_name]
	local scale = 1
	local damage_source = "career_ability"
	local is_husk = false
	local rotation = Quaternion.identity()
	local career_power_level = career_extension:get_career_power_level()
	local side = Managers.state.side.side_by_unit[owner_unit]
	local player_and_bot_units = side.PLAYER_AND_BOT_UNITS
	local num_player_units = #player_and_bot_units

	for i = 1, num_player_units, 1 do
		local player_unit = player_and_bot_units[i]
		local friendly_attack_intensity_extension = ScriptUnit.has_extension(player_unit, "attack_intensity_system")

		if friendly_attack_intensity_extension then
			friendly_attack_intensity_extension:add_attack_intensity("normal", 20, 20)
		end
	end

	self:_play_vo()
	self:_play_vfx()
	career_extension:start_activated_ability_cooldown()

	local position = POSITION_LOOKUP[owner_unit]
	local explosion_template_id = NetworkLookup.explosion_templates[explosion_template_name]
	local damage_source_id = NetworkLookup.damage_sources[damage_source]

	if is_server then
		network_transmit:send_rpc_clients("rpc_create_explosion", owner_unit_go_id, false, position, rotation, explosion_template_id, scale, damage_source_id, career_power_level, false, owner_unit_go_id)
	else
		network_transmit:send_rpc_server("rpc_create_explosion", owner_unit_go_id, false, position, rotation, explosion_template_id, scale, damage_source_id, career_power_level, false, owner_unit_go_id)
	end

	DamageUtils.create_explosion(world, owner_unit, position, rotation, explosion_template, scale, damage_source, is_server, is_husk, owner_unit, career_power_level, false, owner_unit)
end)

--Footknight
--Passive Changes
mod:hook_origin(CareerAbilityESKnight, "_run_ability", function(self)
	self:_stop_priming()

	local owner_unit = self._owner_unit
	local is_server = self._is_server
	local status_extension = self._status_extension
	local career_extension = self._career_extension
	local buff_extension = self._buff_extension
	local talent_extension = ScriptUnit.extension(owner_unit, "talent_system")
	local network_manager = self._network_manager
	local network_transmit = network_manager.network_transmit
	local owner_unit_id = network_manager:unit_game_object_id(owner_unit)
	local buff_name = "markus_knight_activated_ability"

	buff_extension:add_buff(buff_name, {
		attacker_unit = owner_unit
	})

	if talent_extension:has_talent("markus_knight_ability_invulnerability", "empire_soldier", true) then
		buff_name = "markus_knight_ability_invulnerability_buff"

		buff_extension:add_buff(buff_name, {
			attacker_unit = owner_unit
		})

		local buff_template_name_id = NetworkLookup.buff_templates[buff_name]

		if is_server then
			network_transmit:send_rpc_clients("rpc_add_buff", owner_unit_id, buff_template_name_id, owner_unit_id, 0, false)
		else
			network_transmit:send_rpc_server("rpc_add_buff", owner_unit_id, buff_template_name_id, owner_unit_id, 0, false)
		end
	end
	
	if talent_extension:has_talent("markus_knight_wide_charge", "empire_soldier", true) then
		buff_name = "markus_knight_heavy_buff"

		buff_extension:add_buff(buff_name, {
			attacker_unit = owner_unit
		})

		local buff_template_name_id = NetworkLookup.buff_templates[buff_name]

		if is_server then
			network_transmit:send_rpc_clients("rpc_add_buff", owner_unit_id, buff_template_name_id, owner_unit_id, 0, false)
		else
			network_transmit:send_rpc_server("rpc_add_buff", owner_unit_id, buff_template_name_id, owner_unit_id, 0, false)
		end
	end

	status_extension:set_noclip(true)

	local hold_duration = 0.03
	local windup_duration = 0.15
	status_extension.do_lunge = {
		animation_end_event = "foot_knight_ability_charge_hit",
		allow_rotation = false,
		falloff_to_speed = 5,
		first_person_animation_end_event = "foot_knight_ability_charge_hit",
		dodge = true,
		first_person_animation_event = "foot_knight_ability_charge_start",
		first_person_hit_animation_event = "charge_react",
		damage_start_time = 0.3,
		duration = 1.5,
		initial_speed = 20,
		animation_event = "foot_knight_ability_charge_start",
		lunge_events = self._lunge_events,
		speed_function = function (lunge_time, duration)
			local end_duration = 0.25
			local rush_time = lunge_time - hold_duration - windup_duration
			local rush_duration = duration - hold_duration - windup_duration - end_duration
			local start_speed = 0
			local windup_speed = -3
			local end_speed = 20
			local rush_speed = 15
			local normal_move_speed = 2

			if rush_time <= 0 and hold_duration > 0 then
				local t = -rush_time / (hold_duration + windup_duration)

				return math.lerp(0, -1, t)
			elseif rush_time < windup_duration then
				local t_value = rush_time / windup_duration
				local interpolation_value = math.cos((t_value + 1) * math.pi * 0.5)

				return math.min(math.lerp(windup_speed, start_speed, interpolation_value), rush_speed)
			elseif rush_time < rush_duration then
				local t_value = rush_time / rush_duration
				local acceleration = math.min(rush_time / (rush_duration / 3), 1)
				local interpolation_value = math.cos(t_value * math.pi * 0.5)
				local offset = nil
				local step_time = 0.25

				if rush_time > 8 * step_time then
					offset = 0
				elseif rush_time > 7 * step_time then
					offset = (rush_time - 1.4) / step_time
				elseif rush_time > 6 * step_time then
					offset = (rush_time - 6 * step_time) / step_time
				elseif rush_time > 5 * step_time then
					offset = (rush_time - 5 * step_time) / step_time
				elseif rush_time > 4 * step_time then
					offset = (rush_time - 4 * step_time) / step_time
				elseif rush_time > 3 * step_time then
					offset = (rush_time - 3 * step_time) / step_time
				elseif rush_time > 2 * step_time then
					offset = (rush_time - 2 * step_time) / step_time
				elseif step_time < rush_time then
					offset = (rush_time - step_time) / step_time
				else
					offset = rush_time / step_time
				end

				local offset_multiplier = 1 - offset * 0.4
				local speed = offset_multiplier * acceleration * acceleration * math.lerp(end_speed, rush_speed, interpolation_value)

				return speed
			else
				local t_value = (rush_time - rush_duration) / end_duration
				local interpolation_value = 1 + math.cos((t_value + 1) * math.pi * 0.5)

				return math.lerp(normal_move_speed, end_speed, interpolation_value)
			end
		end,
		damage = {
			offset_forward = 2.4,
			height = 1.8,
			depth_padding = 0.6,
			hit_zone_hit_name = "full",
			ignore_shield = false,
			collision_filter = "filter_explosion_overlap_no_player",
			interrupt_on_max_hit_mass = true,
			power_level_multiplier = 1,
			interrupt_on_first_hit = false,
			damage_profile = "markus_knight_charge",
			width = 2,
			allow_backstab = false,
			stagger_angles = {
				max = 80,
				min = 25
			},
			on_interrupt_blast = {
				allow_backstab = false,
				radius = 3,
				power_level_multiplier = 1,
				hit_zone_hit_name = "full",
				damage_profile = "markus_knight_charge_blast",
				ignore_shield = false,
				collision_filter = "filter_explosion_overlap_no_player"
			}
		}
	}

	status_extension.do_lunge.damage.width = 5
	status_extension.do_lunge.damage.interrupt_on_max_hit_mass = false


	career_extension:start_activated_ability_cooldown()
	self:_play_vo()
end)

--lvl 10
mod:modify_talent_buff_template("empire_soldier", "markus_knight_power_level_on_stagger_elite_buff", {
    duration = 15
})
mod:modify_talent("es_knight", 2, 2, {
    description_values = {
        {
            value_type = "percent",
            value = 0.15 --BuffTemplates.markus_knight_power_level_on_stagger_elite_buff.multiplier
        },
        {
            value = 15 --BuffTemplates.markus_knight_power_level_on_stagger_elite_buff.duration
        }
    },
})
mod:modify_talent_buff_template("empire_soldier", "markus_knight_attack_speed_on_push_buff", {
    duration = 5
})
mod:modify_talent("es_knight", 2, 3, {
    description_values = {
        {
            value_type = "percent",
            value = 0.15 --BuffTemplates.markus_knight_attack_speed_on_push_buff.multiplier
        },
        {
            value = 5 --BuffTemplates.markus_knight_attack_speed_on_push_buff.duration
        }
    },
})

--lvl 20
--Unchanged

--lvl 25
mod:modify_talent_buff_template("empire_soldier", "markus_knight_cooldown_buff", {
    duration = 0.75,
    multiplier = 3,
})
mod:modify_talent("es_knight", 5, 3, {
    description_values = {
        {
            value_type = "baked_percent",
            value = 3 --BuffTemplates.markus_knight_cooldown_buff.multiplier
        },
        {
            value = 0.75 --BuffTemplates.markus_knight_cooldown_buff.duration
        }
    },
})

--lvl 30
mod:add_talent_buff_template("empire_soldier", "markus_knight_heavy_buff", {
    max_stacks = 1,
    icon = "markus_knight_ability_hit_target_damage_taken",
    stat_buff = "increased_weapon_damage_heavy_attack",
    multiplier = 0.5,
    duration = 6,
})
mod:modify_talent("es_knight", 6, 2, {
    buffs = {
        "markus_knight_heavy_buff",
    },
    description = "rebaltourn_markus_knight_heavy_buff_desc",
    description_values = {},
})
mod:add_text("rebaltourn_markus_knight_heavy_buff_desc", "Valiant Charge increases the Power of heavies by 50.0%% for 6 seconds")

--Huntsman
--Passive Changes
mod:modify_talent_buff_template("empire_soldier", "markus_huntsman_passive_crit_aura", {
    range = 20
})


--Grail Knight
--Passive Changes
ActivatedAbilitySettings.es_4[1].cooldown = 60

--lvl 10
--crit talent

mod:modify_talent("es_questingknight", 2, 3, {
    num_ranks = 1,
    icon = "markus_questing_knight_charged_attacks_increased_power",
    description = "gs_markus_questing_knight_first_target_increase_desc",
    description_values = {
        {
            value_type = "multiplier",
            value = 0.35
        }
    },
    buffs = {
        "gs_markus_questing_knight_first_target_increase"
    },
})
mod:add_text("gs_markus_questing_knight_first_target_increase_desc", "Increases first target damage by %g%%.")

mod:add_talent_buff_template("empire_soldier", "gs_markus_questing_knight_first_target_increase", {
    stat_buff = "first_melee_hit_damage",
    multiplier = 0.35,
})

--lvl 20
--potion quest


