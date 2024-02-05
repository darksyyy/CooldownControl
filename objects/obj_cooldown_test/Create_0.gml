cooldown_manager = new CDC_Manager();

can_ability = true;

cooldown_manager.add("ability",
{
	duration: 2,
	cdr_type: CDC_CDR_TYPE.EXPO,
	cdr_factor: 0.33,
	on_start: function()
	{
		show_debug_message("start");
		can_ability = false;		
		sprite_index = spr_cd_not_ready;
	},
	on_end: function ()
	{
		show_debug_message("end");
		can_ability = true;
		sprite_index = spr_cd_ready;
	}
});

show_debug_message(cooldown_manager);
