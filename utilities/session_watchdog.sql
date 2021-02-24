
/*
	This script is monitoring the `EXA_ALL_SESSIONS` system table to identify "bad" sessions based on some criteria, and subsequently, kill/abort these sessions.
*/

CREATE SCHEMA IF NOT EXISTS EXA_TOOLBOX;

--/
CREATE OR REPLACE SCRIPT EXA_TOOLBOX.session_watchdog() RETURNS TABLE AS
	-- requirement: KILL ANY SESSION
	-- output: List of sessions that have been aborted/killed, including the respective reason

	--[[
		Configuration section
	--]]
	-- Table with user-specific limits
	local USER_LIMITS = {
		USER1 = { query_timeout = 300, temp_ram = 3000, idle_timeout = 1800 },
		USER2 = { query_timeout = 150, idle_timeout = 300 },
		SYS = { temp_ram = 10000 }
	}
	-- Logging table, will be returned by script
	local log_data = {}

	--[[
		Given maximal and current measure value, the given session is killed or the current statement is aborted.
	--]]
	local function kill_session( session, measure_name, measure_value, max_value )
		if measure_value / max_value <= 1.1 then
			-- exceeded by 0-10% ... try to kill statement only
			local success = pquery( [[kill statement ]] .. session.STMT_ID .. [[ in session ]] .. session.SESSION_ID )
			if success then
				log_data[1+#log_data] = { session.SESSION_ID, session.USER_NAME, 'soft ' .. measure_name, measure_value, max_value }
			end

		else
			local success = pquery( [[kill session ]] .. session.SESSION_ID )
			if success then
				log_data[1+#log_data] = { session.SESSION_ID, session.USER_NAME, 'hard ' .. measure_name, measure_value, max_value }
			end

		end
	end


	--[[
		Preparation section
	--]]
	-- get list of current sessions, excluding disconnected idle sessions
	local session_list = query([[
		select
			to_char(SESSION_ID) as SESSION_ID, STMT_ID, USER_NAME, STATUS, COMMAND_NAME, 
			right(duration,2) + 60*regexp_substr(duration, '(?<=:)[0-9]{2}(?=:)') + 3600 * regexp_substr(duration, '^[0-9]+(?=:)') as duration,
			temp_db_ram
		from
			sys.exa_all_sessions
		where
			temp_db_ram > 0
	]])


	--[[
		Action section
	--]]
	-- go through the list and check each session for its limits
	for snum = 1, #session_list do
		-- session information
		local usession = session_list[snum]
		-- looking up the session's user
		local ulimit = USER_LIMITS[usession.USER_NAME]

		-- ignore service process and unlimited users
		if usession.SESSION_ID ~= '4' and ulimit ~= nil then

			-- dummy loop allows us to use 'break' instead of cascading if/else/if
			repeat
				-- check TEMP
				if ulimit.temp_ram ~= nil and usession.TEMP_DB_RAM > ulimit.temp_ram then
					kill_session( usession, 'TEMP', usession.TEMP_DB_RAM, ulimit.temp_ram )
					break
				end

				-- check query runtime
				if usession.STATUS ~= 'IDLE' and ulimit.query_timeout ~= nil and usession.DURATION > ulimit.query_timeout then
					kill_session( usession, 'QUERY TIMEOUT', usession.DURATION, ulimit.query_timeout )
					break
				end

				-- check idle timeout
				if usession.STATUS == 'IDLE' and ulimit.idle_timeout ~= nil and usession.DURATION > ulimit.idle_timeout then
					kill_session( usession, 'IDLE TIMEOUT', usession.DURATION, ulimit.idle_timeout )
					break
				end
			-- dummy loop exits after first iteration
			until true
		end
	end

	return log_data, "SESSION_ID decimal(20), USER_NAME varchar(128), MEASURE_TYPE varchar(20), MEASURE_VALUE decimal(9,3), MEASURE_LIMIT decimal(9,3)"
/

--EXECUTE SCRIPT  EXA_TOOLBOX.SESSION_WATCHDOG()