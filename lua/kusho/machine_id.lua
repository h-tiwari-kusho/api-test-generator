local M = {}

-- Utility function to get command output
local function get_command_output(cmd)
	local handle = io.popen(cmd)
	if not handle then
		return nil
	end

	local result = handle:read("*a")
	handle:close()
	return result and result:gsub("%s+$", "") or nil
end

-- Get various system identifiers
local function get_system_info()
	local info = {}

	-- Try to get CPU ID (works on Unix-like systems)
	info.cpu_id = get_command_output("cat /proc/cpuinfo | grep -i 'processor' | head -1 | awk '{print $3}'")

	-- Get hostname
	info.hostname = get_command_output("hostname")

	-- Get username
	info.username = vim.fn.expand("$USER")

	-- Get OS info
	if vim.fn.has("win32") == 1 then
		info.os = "windows"
		-- Try to get Windows-specific hardware ID
		info.hardware_id = get_command_output("wmic csproduct get uuid")
	elseif vim.fn.has("unix") == 1 then
		info.os = "unix"
		-- Try to get machine-id on Unix-like systems
		info.machine_id = get_command_output("cat /etc/machine-id")
	elseif vim.fn.has("mac") == 1 then
		info.os = "mac"
		-- Try to get Mac-specific hardware UUID
		info.hardware_id = get_command_output("ioreg -rd1 -c IOPlatformExpertDevice | grep UUID")
	end

	return info
end

-- Simple string hashing function that doesn't require bit operations
local function hash_string(str)
	local hash = 0
	for i = 1, #str do
		hash = (hash * 223 + str:byte(i)) % 4294967291 -- Use a prime number close to 2^32
	end
	return string.format("%08x", hash)
end

-- Combine multiple strings for hashing
local function combine_hashes(...)
	local combined = ""
	for _, value in ipairs({ ... }) do
		if value then
			combined = combined .. tostring(value)
		end
	end
	return hash_string(combined)
end

-- Get or create machine ID
function M.get_machine_id()
	-- Try to read existing machine ID
	local cache_dir = vim.fn.stdpath("cache")
	local id_file = cache_dir .. "/kusho_machine_id"

	-- Check if we already have a stored machine ID
	local f = io.open(id_file, "r")
	if f then
		local stored_id = f:read("*all")
		f:close()
		if stored_id and #stored_id > 0 then
			return stored_id
		end
	end

	-- Generate new machine ID
	local system_info = get_system_info()

	-- Combine all available system information
	local components = {
		system_info.cpu_id,
		system_info.hostname,
		system_info.username,
		system_info.os,
		system_info.hardware_id,
		system_info.machine_id,
		tostring(os.time()), -- Add timestamp to ensure uniqueness
	}

	-- Create combined hash using unpack instead of table.unpack
	local machine_id = combine_hashes(unpack(components))

	-- Store the machine ID
	f = io.open(id_file, "w")
	if f then
		f:write(machine_id)
		f:close()
	end

	return machine_id
end

return M
