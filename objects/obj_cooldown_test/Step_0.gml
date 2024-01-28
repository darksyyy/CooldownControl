if (keyboard_check_pressed(vk_space) and can_ability)
{
	cooldown_manager.start("ability");	
	show_debug_message("ability");
}