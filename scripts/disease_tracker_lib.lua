-- 
-- Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

---	This function facilitates conversion to title case.
--	@param first The first character of the string it's processing.
--	@param rest The complete string, except for the first character.
--	@return first:upper()..rest:lower() The re-combined string, converted to title case.
function formatTitleCase(first, rest)
   return first:upper() .. rest:lower()
end

---	This function rounds to the specified number of decimals
function round(number, decimals)
    local n = 10^(decimals or 0)
    number = number * n
    if number >= 0 then number = math.floor(number + 0.5) else number = math.ceil(number - 0.5) end
    return number / n
end