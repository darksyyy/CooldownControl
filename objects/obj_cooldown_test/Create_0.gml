cooldown_manager = new CDC_Manager();

can_ability = true;

cooldown_manager.add("ability",
{
	period: 2,
	on_start: function()
	{
		can_ability = false;		
		sprite_index = spr_cd_not_ready;
	},
	on_end: function ()
	{
		can_ability = true;
		sprite_index = spr_cd_ready;
	}
});


