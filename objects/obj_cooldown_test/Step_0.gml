if (keyboard_check_pressed(vk_space) and cooldown_manager.is_cooldown_ready("ability"))
{
	cooldown_manager.start("ability");	
	show_debug_message("ability");
}

if (keyboard_check_pressed(ord("1")))
{
	cooldown_manager.stop("ability");
}

if (keyboard_check_pressed(ord("2")))
{
	cooldown_manager.pause("ability");
}

if (keyboard_check_pressed(ord("3")))
{
	cooldown_manager.resume("ability");
}