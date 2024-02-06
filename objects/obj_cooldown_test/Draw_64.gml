if (alive)
{
	var _remaining = cooldown_manager.get_cooldown_remaining("ability");
	var _elapsed = cooldown_manager.get_cooldown_elapsed("ability");
	var _percent = cooldown_manager.get_cooldown_percent("ability");

	draw_text(5, 5, $"can_ability: {cooldown_manager.is_cooldown_ready("ability")}, Remaining: {_remaining}, Elapsed: {_elapsed}, Percent: {_percent}");
}