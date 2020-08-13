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

---	This function rounds nNum to nDecimalPlaces (or to a whole number)
function round(nNum, nDecimalPlaces)
  local nMult = 10^(nDecimalPlaces or 0)
  return math.floor(nNum * nMult + 0.5) / nMult
end