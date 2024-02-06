/**
	Cooldown Control
	Author: Darcy Shaw
*/

/// @function			CDC_Cooldown
/// @description		Struct holding cooldown properties
function CDC_Cooldown() constructor
{
	__on_start = undefined;		// Function to execute on start
	__on_end = undefined;		// Function to execute on end
	__name = undefined;			// Name of the Cooldown
	__duration = undefined;		// Cooldown Time in (__units)
	__base_duration = undefined // Cooldown Time in (__units) unchanged by cooldown reduction
	__units = undefined;		// Unit of Time (seconds or frames)
	__state = CDC_STATE.READY;	// Current State of the Cooldown
	__ts = undefined;			// Time source
	__ts_callback = undefined;
	__cdr_type = undefined;		// Cooldown Reduction Type: Flat, Flat Percent, Exponential, Multiplicative
	__cdr_factor = undefined;	// The amount of reduction per stack of CDR (ex. 0.10, 0.45)
	__cdr_stacks = 0;			// The amount of stacks of the CDR factor
	__cdr_sources = undefined;
	
	toString = function()
	{
		return $"CDC_COOLDOWN: \'{__name}\', \'{__duration}\', \'{__units}\'";	
	}
}

/// @function			CDC_Manager
/// @description		Manages Cooldowns
function CDC_Manager() constructor 
{
	__context = other;					// Execution context for ALL cooldown inner functions
	__cooldowns = ds_map_create();		// Map containing Names -> Cooldown Structs
	
	#region Cooldown Creation & Deletion
	/// @function			_add(_name, _on_start, _on_end, _duration, _units)
	/// @description		(Internal - DO NOT CALL THIS) Add cooldown to Cooldown Manager
	/// @param {String}		_name		Name of the Cooldown
	/// @param {Function}	_on_start	Function to execute on start	
	/// @param {Function}	_on_end		Function to execute on end
	/// @param {Real}		_duration	Cooldown Time in (_units)
	/// @param {Real}		_units		Unit of Time (seconds or frames)
	/// @param {Real}		_cdr_type	Type of Cooldown Reduction calculation for this CD
	/// @param {Real}		_cdr_factor	The amount of cooldown to reduce. (Per stack, if using EXPO or MULT CDR scaling)
	__add = function(_name, _on_start, _on_end, _duration, _units, _cdr_type, _cdr_factor) 
	{
		var _start, _end, _cooldown;
		_cooldown = new CDC_Cooldown();
		
		_start = (is_undefined(_on_start) || !is_method(_on_start)) ? function () {} : _on_start;
		_end   = (is_undefined(_on_end) || !is_method(_on_end)) ? cdc_default_on_end : _on_end;
		
		var _is_on_end_user_defined = cdc_default_on_end != _on_end;
		
		_cooldown.__on_start = method(self.__context, _start);
		_cooldown.__on_end = method(self.__context, _end);
		_cooldown.__name = _name;
		_cooldown.__units = _units;
		_cooldown.__duration = _duration;
		_cooldown.__cdr_type = _cdr_type;
		_cooldown.__cdr_factor = _cdr_factor;
		
		if (_is_on_end_user_defined)
		{
			_cooldown.__ts_callback = method(_cooldown, function() { __on_end(); __state = CDC_STATE.READY; });
		} 
		else {
			_cooldown.__ts_callback = cdc_default_on_end;
		}
		
		ds_map_add(self.__cooldowns, _name, _cooldown);
	}
	
	add = function(_name, _cooldown_struct)
	{
		var _on_start = undefined;
		var _on_end = undefined;
		
		var _duration, _units, _cdr_type, _cdr_factor;
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
		
		_duration = (struct_exists(_cooldown_struct, "duration")) ? struct_get(_cooldown_struct, "duration") : __CDC_DEFAULT_DURATION;
		_units = (struct_exists(_cooldown_struct, "units")) ? struct_get(_cooldown_struct, "units") : __CDC_DEFAULT_TIME_SOURCE_UNIT;
		_cdr_type = (struct_exists(_cooldown_struct, "cdr_type")) ? struct_get(_cooldown_struct, "cdr_type") : __CDC_DEFAULT_CDR_TYPE;
		_cdr_factor = (struct_exists(_cooldown_struct, "cdr_factor")) ? struct_get(_cooldown_struct, "cdr_factor") : __CDC_DEFAULT_CDR_FACTOR;
		
		__add(_name, _on_start, _on_end, _duration, _units, _cdr_type, _cdr_factor);
	}

	
	delete_cooldown = function(_name)
	{
		delete self.__cooldowns[@ _name];
		ds_map_set(self.__cooldowns, _name, undefined);
	}
	
	set_cooldown_duration = function(_name, _duration)
	{
		var _cooldown = get(_name);
		if (is_undefined(_cooldown)) show_debug_message($"CDC: Failed to set duration {_name} doesn't exist");
		
		_cooldown.__base_duration = _duration;
		_cooldown.__duration = _duration;
		
		time_source_reconfigure(_cooldown.__ts, _cooldown.__duration, _cooldown.__units, _cooldown.__on_end);
	}
	#endregion	
	
	#region Cooldown Controls
	
	/**
		@function			start(_name, _run_on_start)    Starts the cooldown specified by 'name'
		@param {String}		_name			Name of cooldown to start.	
		@param {Bool}		_run_on_start	Whether or not to execute the on_start function. Defaults to True.
	*/
	start = function (_name, _run_on_start = true) 
	{
		var _cooldown = get(_name);
		
		if (is_undefined(_cooldown))
		{
			show_debug_message($"CDC: Failed to Start {_name} doesn't exist");
			return false;
		}
		
		if (_cooldown.__state != CDC_STATE.READY)
		{
			show_debug_message($"CDC: Failed to Start {_name} is already running");
			return false;
		}
		
		if (_run_on_start) _cooldown.__on_start();
		
		if (is_undefined(_cooldown.__ts))
		{
			_cooldown.__ts = time_source_create(__CDC_DEFAULT_TIME_SOURCE, _cooldown.__duration, _cooldown.__units, _cooldown.__ts_callback);	
		}
		
		_cooldown.__state = CDC_STATE.NOT_READY;
		time_source_start(_cooldown.__ts);
		return true;
	}
	
	/**
		@function			start_blocking(_name)    Sets the specified cooldown to the BLOCKING state
		@param {String}		_name			Name of cooldown to start blocking.	
	*/
	start_blocking = function (_name) 
	{
		var _cooldown = get(_name);
		
		if (is_undefined(_cooldown))
		{
			show_debug_message($"CDC: Failed to Start Blocking {_name} doesn't exist");
			return false;
		}
		
		if (_cooldown.__state != CDC_STATE.READY)
		{
			show_debug_message($"CDC: Failed to Start Blocking {_name} has already been started");
			return false;
		}
		
		_cooldown.__state = CDC_STATE.BLOCKING;
		return true;
	}
	
	/**
		@function			stop(_name)		 Stops the cooldown specified by 'name'
		@param {String}		_name			 Name of cooldown to stop.	
		@param {Bool}		_run_on_end	Whether or not to execute the on_end function. Defaults to True.
	*/
	stop = function (_name, _run_on_end = true) 
	{
		var _cooldown = get(_name);
		
		if (is_undefined(_cooldown))
		{
			show_debug_message($"CDC: Failed to Stop {_name} doesn't exist");
			return false;
		}
		
		if (_cooldown.__state != CDC_STATE.NOT_READY and _cooldown.__state != CDC_STATE.PAUSED)
		{
			show_debug_message($"CDC: Failed to Stop {_name} is not running");
			return false;
		}
		
		if (_cooldown.__state == CDC_STATE.PAUSED) resume(_name);
		
		if (_run_on_end) _cooldown.__on_end();
		
		_cooldown.__state = CDC_STATE.READY;
		time_source_stop(_cooldown.__ts);
		return true;
	}
	
	/**
		@function			pause(_name)	 Pauses the cooldown specified by 'name'
		@param {String}		_name			 Name of cooldown to pause.	
	*/
	pause = function (_name) 
	{
		var _cooldown = get(_name);
		
		if (is_undefined(_cooldown))
		{
			show_debug_message($"CDC: Failed to Pause {_name} doesn't exist");
			return false;
		}
		
		if (_cooldown.__state != CDC_STATE.NOT_READY)
		{
			show_debug_message($"CDC: Failed to Pause {_name} is not running");
			return false;
		}
		
		_cooldown.__state = CDC_STATE.PAUSED;
		time_source_pause(_cooldown.__ts);
		return true;
	}
	
	/**
		@function			resume(_name)	 Resumes the cooldown specified by 'name'
		@param {String}		_name			 Name of cooldown to resume.	
	*/
	resume = function (_name) 
	{
		var _cooldown = get(_name);
		
		if (is_undefined(_cooldown))
		{
			show_debug_message($"CDC: Failed to Resume {_name} doesn't exist");
			return false;
		}
		
		if (_cooldown.__state != CDC_STATE.PAUSED)
		{
			show_debug_message($"CDC: Failed to Resume {_name} is not paused");
			return false;
		}
		
		_cooldown.__state = CDC_STATE.NOT_READY;
		time_source_resume(_cooldown.__ts);
		return true;
	}
	
	#endregion
	
	#region Cooldown Reduction
	
	
	
	#endregion
	
	#region Getters
	/**
		@function			get(_name)      Returns the cooldown specified by 'name'
		@param {String}		_name			Name of cooldown to return.	
	*/
	get = function(_name)
	{
		var _cooldown = ds_map_find_value(__cooldowns, _name);
		if (!is_undefined(_cooldown)) return _cooldown;
		
		return undefined; 
	}

	/**
		@function			get_cooldown_remaining(_name)      Returns the remaining time for the specified cooldown
		@param {String}		_name							   Name of cooldown.	
	*/
	get_cooldown_remaining = function(_name)
	{
		var _cooldown = get(_name);
		
		if (!is_undefined(_cooldown.__ts)) return time_source_get_time_remaining(_cooldown.__ts);
		
		return undefined;
	}

	/**
		@function			get_cooldown_elapsed(_name)      Returns the elapsed time for the specified cooldown
		@param {String}		_name							 Name of cooldown.	
	*/
	get_cooldown_elapsed = function(_name)
	{
		var _cooldown = get(_name);
		if (!is_undefined(_cooldown.__ts)) return time_source_get_period(_cooldown.__ts) - time_source_get_time_remaining(_cooldown.__ts);
		
		return undefined;
	}
	
	/**
		@function			get_cooldown_percent(_name)      Returns the percentage of completion for the specified cooldown
		@param {String}		_name							 Name of cooldown.	
		@param {Real}		_scale							 OPTIONAL: The scale for the percentage to multipled with. Default 100.
	*/
	get_cooldown_percent = function(_name, _scale = 100)
	{
		var _cooldown = get(_name);
		if (is_undefined(_cooldown.__ts)) return undefined;	
		
		var _curr = time_source_get_time_remaining(_cooldown.__ts);
		var _total = time_source_get_period(_cooldown.__ts);
		
		return (1 - (_curr/_total)) * _scale;			
	}

	/**
		@function			get_cooldown_remaining(_name)      Returns the total duration for the specified cooldown
		@param {String}		_name							   Name of cooldown.	
	*/
	get_cooldown_duration = function(_name)
	{
		var _cooldown = get(_name);
		if (!is_undefined(_cooldown.__ts)) return time_source_get_period(_cooldown.__ts);
		
		return undefined;
	}
	#endregion
	
	#region Boolean Getters
	/**
		@function			is_cooldown_ready(_name)		   Returns whether or not the cooldown is actively waiting to start (TRUE) or ticking down (FALSE)
		@param {String}		_name							   Name of cooldown.	
	*/
	is_cooldown_ready = function(_name)
	{
		var _cooldown = get(_name);
		if (!is_undefined(_cooldown)) return _cooldown.__state == CDC_STATE.READY;
		
		return undefined;
	}
	
	/**
		@function			is_cooldown_blocking(_name)		   Returns whether or not the cooldown is actively blocking
		@param {String}		_name							   Name of cooldown.	
	*/
	is_cooldown_blocking = function(_name)
	{
		var _cooldown = get(_name);
		if (!is_undefined(_cooldown)) return _cooldown.__state == CDC_STATE.BLOCKING;
		
		return undefined;
	}
	#endregion
	
	/**
		@function		destroy    Destroys the Cooldown Manager and all cooldowns
	*/
	destroy = function()
	{
		var _keys = [];
		_keys = ds_map_keys_to_array(self.__cooldowns);
		
		for(var _i = 0; _i < array_length(_keys); _i++)
		{
			var _key = _keys[_i];
			
			var _cooldown = ds_map_find_value(self.__cooldowns, _key);
			
			
			if (!is_undefined(_cooldown.__ts))
			{
				time_source_pause(_cooldown.__ts);
				time_source_destroy(_cooldown.__ts, true);
			}
			
			delete _cooldown;
			_cooldown = undefined;
			//show_debug_message(_cooldown);
		}
		
		ds_map_destroy(__cooldowns);	
		__cooldowns = undefined;
	}
	
	toString = function()
	{
		if (!is_undefined(self.__cooldowns))
		{
			var _keys = [];
			_keys = ds_map_keys_to_array(self.__cooldowns);
		
			var _str = $"CDC Cooldown Manager: {instance_id_get(self.__context)}";
			for(var _i = 0; _i < array_length(_keys); _i++)
			{
				var _key = _keys[_i];
			
				var _cooldown = ds_map_find_value(self.__cooldowns, _key);
				_str += string($"{_cooldown}\n");
			}
		
			return _str;
		} else	{
			var _str = $"CDC Cooldown Manager: {instance_id_get(self.__context)}";
			return _str;
		}
	}
}

#region Default Functions

function cdc_default_on_end()
{
	__state = CDC_STATE.READY;	
}

#endregion

#region Cooldown Reduction Equations

function __get_cdr_flat(_duration, _val) 
{
	return max(MIN_CD_DURATION, _duration - _val);
}

function __get_cdr_percent(_duration, _percent) 
{
	var _new_duration = _duration - (_duration * _percent);
	return max(MIN_CD_DURATION, _new_duration);
}

function __get_cdr_exponential(_duration, _factor, _stacks) 
{
	var _new_duration = _duration * exp((-1 * _factor) * _stacks);
	return max(MIN_CD_DURATION, _new_duration);
}

function __get_cdr_multiplicative(_duration, _factor, _stacks) 
{
	var _new_duration = _duration * power((1 - _factor), _stacks);
	return max(MIN_CD_DURATION, _new_duration);	
}

#endregion

#region Enums

enum CDC_STATE
{
	NOT_READY,	// Cooldown is active and ticking down
	READY,		// Cooldown is not active
	PAUSED,		// Cooldown is active, but paused
	BLOCKING	// Cooldown is active, but timer is not started. Useful for disallowing an ability after cast but not starting the cooldown timer till the ability has finished (animating etc.).
}

enum CDC_CDR_TYPE
{
	FLAT,
	PERCENT,
	EXPO,		// Exponential Reduction
	MULT		// Multiplicative Reduction
}

#macro MIN_CD_DURATION 0.001

#endregion


#region Testing
var _duration = 20;
var _stacks = 3;
var _factor = 0.5;
//show_debug_message("flat: {0}", __get_cdr_flat(_duration, _factor));
//show_debug_message("percent: {0}", __get_cdr_percent(_duration, _factor));
var _r1 = __get_cdr_exponential(_duration, _factor, _stacks)
show_debug_message("exp: {0}", _r1);

_factor = 0.4
var _r2 = __get_cdr_exponential(_duration, _factor, _stacks);
show_debug_message("exp: {0}", _r2);

_factor = 0.1
_stacks = 6
var _r3 = __get_cdr_exponential(_duration, _factor, _stacks);
show_debug_message("exp: {0}", _r3);

show_debug_message("avg: {0}", mean(_r1, _r2, _r3));
//show_debug_message("mult: {0}", __get_cdr_multiplicative(_duration, _factor, _stacks));
#endregion