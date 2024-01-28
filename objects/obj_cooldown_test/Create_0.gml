cooldown_manager = new CDC_CooldownManager();

temp = "hello";
show_debug_message(temp);

cooldown_manager.add("test",
{
	period: 2,
	on_end: function ()
	{
		temp = "goodbye";
	}
});


show_debug_message(temp);
cooldown_manager.destroy();