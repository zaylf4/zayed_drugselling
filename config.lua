return {

    rep_command = 'gangrep', -- Command used to check your drugselling rep
    buyer_cooldown = 10000, -- Time in milliseconds until you can sell to the same ped. 1000 = 1 second.
    npc_spawn_interval = 10000, -- Time in milliseconds until the next ped spawns. 1000 = 1 second.
    npc_delete_timer = 5000,
    money_item = 'black_money',

    interaction = { 
        type = 'target', -- 'target' or '3dtext'

        targetlabel = 'Sell Drugs',
        targetradius = 3.0, 
        targeticon = 'fas fa-cannabis', -- https://fontawesome.com/icons
        targetdistance = 2.0,

        text = '[~g~E~w~] Sell Drugs'
    },

    police = {
        callpoliceondeny = false, -- If police should be called if the ped runs away (You need to add your dispatch) in resource/client.lua - police_dispatch()
        required = 3, -- Amount of cops required to sell drugs, set to false for no requirement.
        multi = 0, -- Multiplier applied to sale price per officer on.
        job = 'police', -- Police Job name
    },
    
    drugs = { -- base_price = Base price for 1 drug // maxsale = max amount of items that can be sold at once // rep_sale = reputation received from sale of drug.
        ['weed'] = {base_price = 200, max_sale = 2, rep_sale = 0.1},
    },  

    sellChance = {
        max = 100,
        min = 0,
        chance = 80, 
    },

    pedModels = {
        "a_m_y_juggalo_01", 
        "a_m_m_hillbilly_01", 
        "g_m_y_ballasout_01", 
        "g_m_y_mexgoon_01",   
        "g_m_y_famca_01"      
    },


    --- Don't touch this at all

    reps = {
        {
            level = 'gangrep', 
            label = 'Gang Reputation: ', 
            description = '',
            min_reputation = 0.0
        },
        --- Don't remove this level from here!
        {
            level = 'level2', 
            label = 'Level 2', 
            description = 'You are getting the hang of it!', 
            min_reputation = 9999999999999999999999999999999999999999999999.0
        },
    },

    Zones = {
        -- 8TREY ZONE
        [1] = { --
            ['zone'] = {
                ['type'] = 'sphere',
                ['thickness'] = 2,
                ['debug'] = false,
                ['radius'] = 30.0,
                ['size'] = vec3(1, 1, 1),
                ['rotation'] = 45.0,
                ['coords'] = {
                    vec3(315.34, -1267.23, 31.5),
                },
                ['action'] = {
                    onEnter = function(self)
                        TriggerServerEvent("zayed_drugsell:server:setZoneStatus", true)
                        lib.notify({
                            title = "Gang Territory - Entering",
                            description = "You have entered 8 Trey's Territory",
                            icon = "user-ninja",  -- Ad icon on the left side
                            iconColor = '#ff6000', -- Golden yellow color for icon
                            duration = 4000, -- Display for 8 seconds
                            position = "center", -- Show notification in the center
                            type = "inform"
                        })
                    end,
                    onExit = function(self)
                        TriggerServerEvent("zayed_drugsell:server:setZoneStatus", false)
                        lib.notify({
                            title = "Gang Territory - Leaving",
                            description = "You have left 8 Trey's Territory.",
                            icon = "user-ninja",  -- Ad icon on the left side
                            iconColor = '#ff0000', -- Golden yellow color for icon
                            duration = 4000, -- Display for 8 seconds
                            position = "center", -- Show notification in the center
                            type = "inform"
                        })
                    end,
                    inside = function(self)
                    end,
                },
            },
            ['blip'] = {
                ['blip_radius'] = {
                    ['enabled'] = true,
                    ['coords'] = {
                        ['X'] = 315.34,
                        ['Y'] = -1267.23,
                        ['Z'] = 31.5,
                    },
                    ['color'] = 85,
                    ['radius'] = 30.0,
                    ['alpha'] = 100,
                },
                ['blip_marker'] = {
                    ['enabled'] = false,
                    ['coords'] = {
                        ['X'] = 255.250198,
                        ['Y'] = 226.070358,
                        ['Z'] = 101.882225,
                    },
                    ['color'] = 0,
                    ['scale'] = 1.0,
                    ['display'] = 1,
                    ['sprite'] = 108,
                    ['text'] = 'Safezone',
                },
            },
        },
    }
}