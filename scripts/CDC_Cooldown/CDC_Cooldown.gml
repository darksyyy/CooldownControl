/**
	Cooldown Control
	Author: Darcy Shaw
*/

function CDC_Cooldown() constructor
{
	__on_start = undefined; // Function to execute on start
	__on_end = undefined;	// Function to execute on end
	__name = undefined;		// Name of the Cooldown
	__period = undefined;	// Cooldown Time in (__units)
	__units = undefined;	// Unit of Time (seconds or frames)
	__state = CDC_STATE.WAITING;	// Current State of the Cooldown
	_ts = undefined;		// Time source
	
	toString = function()
	{
		return $"CDC_COOLDOWN: \'{__name}\', \'{__period}\', \'{__units}\'";	
	}
}

/// @function			CDC_CooldownManager
/// @description		Manages Cooldowns
function CDC_CooldownManager() constructor 
{
	__context = other;					// Execution context for ALL cooldown functions
	__cooldowns = ds_map_create();		// Map containing Names -> Cooldown Structs
	
	/// @function			_add(_name, _on_start, _on_end, _period, _units)
	/// @description		(Internal) Add cooldown to Cooldown Manager
	/// @param {String}		_name		Name of the Cooldown
	/// @param {Function}	_on_start	Function to execute on start	
	/// @param {Function}	_on_end		Function to execute on end
	/// @param {Real}		_period		Cooldown Time in (_units)
	/// @param {Real}		_units		Unit of Time (seconds or frames)
	__add = function(_name, _on_start, _on_end, _period, _units) 
	{
		var _start, _end, _cooldown;
		_cooldown = new CDC_Cooldown();
		
		_start = (is_undefined(_on_start) || !is_method(_on_start)) ? function () {} : _on_start;
		_end   = (is_undefined(_on_end) || !is_method(_on_end)) ? function () {} : _on_end;
		
		
		_cooldown.__on_start = method(self.__context, _start);
		_cooldown.__on_end = method(self.__context, _end);
		_cooldown.__name = _name;
		_cooldown.__units = _units;
		_cooldown.__period = _period;
		
		ds_map_add(self.__cooldowns, _name, _cooldown);
		
		//if (CDC_DEBUG)
		//{
		//	_cooldown.__on_start();
		//	_cooldown.__on_end();
		//	show_debug_message(_cooldown);
		//}
	}
	
	add = function(_name, _cooldown_struct)
	{
		var _on_start = undefined;
		var _on_end = undefined;
		
		var _period, _units;
		var _properties = struct_get_names(_cooldown_struct);
		
		// Iterate and add custom function events
		for (var _i = 0; _i < array_length(_properties); _i++)
		{
			var _property_name = _properties[_i];
			var _property = struct_get(_cooldown_struct, _property_name);
			
			if (!is_method(_property)) continue;
			
			if (_property_name == "on_start") _on_start = _property;
			if (_property_name == "on_end") _on_end = _property;
		}
		
		_period = (struct_exists(_cooldown_struct, "period")) ? struct_get(_cooldown_struct, "period") : 1;
		_units = (struct_exists(_cooldown_struct, "units")) ? struct_get(_cooldown_struct, "units") : CDC_DEFAULT_UNIT;
		
		__add(_name, _on_start, _on_end, _period, _units);
	}
	
	destroy = function()
	{
		ds_map_destroy(__cooldowns);	
	}
}

enum CDC_STATE
{
	WAITING,
	START,
	RUNNING,
	END,
	RESET
}


