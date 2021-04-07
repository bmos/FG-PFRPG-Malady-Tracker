--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

function onInit()
	if LongTermEffects then
		CombatManager.setCustomTurnEnd(parseDiseases)
		
		DB.addHandler('calendar.dateinminutesstring', 'onUpdate', parseDiseases)
		DB.addHandler('calendar.dateinminutes', 'onUpdate', parseDiseases)
	end

	LibraryData.setRecordTypeInfo('disease', {
			bExport = true,
			aDataMap = { 'disease', 'reference.diseases' }, 
			sRecordDisplayClass = 'referencedisease', 
			aGMListButtons = { 'button_feat_type' };
			aPlayerListButtons = { 'button_feat_type' };
			aCustomFilters = {
				['Type'] = { sField = 'type' },
			}
		})
end

---	This function rounds to the specified number of decimals
function round(number, decimals)
    local n = 10^(decimals or 0)
    number = number * n
    if number >= 0 then number = math.floor(number + 0.5) else number = math.ceil(number - 0.5) end
    return number / n
end

local function calculateFrequency(nodeDisease, sDiseaseName)
	local nFreqUnit = tonumber(DB.getValue(nodeDisease, 'freq_unit'))
	local nFreqVal = DB.getValue(nodeDisease, 'freq_interval')
	local nFreq
	if nFreqUnit and nFreqVal then
		nFreq = nFreqUnit * nFreqVal
	end
	--Debug.console(sDiseaseName, 'Frequency: ' .. nFreq or 'nil')

	return nFreq
end

local function calculateDuration(nodeDisease, sDiseaseName, nOnset)
	local nDurUnit = tonumber(DB.getValue(nodeDisease, 'duration_unit'))
	local nDurVal = DB.getValue(nodeDisease, 'duration_interval')
	local nDuration
	if nDurUnit and nDurVal then
		nDuration = nDurUnit * nDurVal + nOnset
		nDurationWithOnset = nDurUnit * nDurVal + nOnset
	end
	--Debug.console(sDiseaseName, 'Duration With Onset: ' .. nDurationWithOnset, 'Duration: ' .. nDuration)

	return nDurationWithOnset, nDuration, nDurUnit
end

local function calculateOnset(nodeDisease, sDiseaseName)
	local nOnsUnit = tonumber(DB.getValue(nodeDisease, 'onset_unit', 0))
	local nOnsVal = DB.getValue(nodeDisease, 'onset_interval', 0)
	local nOnset = 0
	if nDurUnit and nDurVal then
		nOnset = nOnsUnit * nOnsVal
	end
	--Debug.console(sDiseaseName, 'Onset: ' .. nOnset or 'nil')

	return nOnset
end

-- This function iterates through each disease and poison of the character
function parseDiseases(nodeActor)
	local nDateinMinutes, nInit = TimeManager.getCurrentDateinMinutes(), 0
	if nodeActor then
		local rActor = ActorManager.resolveActor(nodeActor)
		nInit = DB.getValue(ActorManager.getCTNode(rActor), "initresult", 0)
		if nInit > 0 then nInit = 0.1 - (0.001 * (nInit)) end
	end
	local nDateWithRounds = nDateinMinutes + nInit
	--Debug.console('current', nDateWithRounds, nDateinMinutes, nodeActor)
	for _,nodeCT in pairs(DB.getChildren('combattracker.list')) do
		local rActor = ActorManager.resolveActor(nodeCT)
		local nodeActor = ActorManager.getCreatureNode(rActor)
		for _,nodeDisease in pairs(DB.getChildren(nodeActor, 'diseases')) do
			local nDateOfContr = DB.getValue(nodeDisease, 'starttimestring') or DB.getValue(nodeDisease, 'starttime')
			if nDateOfContr and DB.getValue(nodeDisease, 'savetype') and not string.find(DB.getValue(nodeDisease, 'name', ''), '%[') then
				local nTimeElapsed = nDateWithRounds - nDateOfContr

				local nOnset = calculateOnset(nodeDisease, sDiseaseName)
				nTimeElapsed = nTimeElapsed - nOnset

				local sDiseaseName = DB.getValue(nodeDisease, 'name', 'their disease')
				--Debug.console(sDiseaseName, nTimeElapsed .. ': ' .. nDateWithRounds .. ' - ' .. nDateOfContr .. ' - ' .. nOnset)
				-- if the disease has a starting time, the current time is known, and any onset has elapsed
				if nTimeElapsed > 0 then
					local nFreq = calculateFrequency(nodeDisease, sDiseaseName)
					if nFreq then
						local nPrevRollCount = DB.getValue(nodeDisease, 'savecount', 0) -- how many saves have been successful
						nTimeElapsed = round(nTimeElapsed / nFreq, 3)
						local nTotalRolls = math.floor(nTimeElapsed)
						--Debug.console(sDiseaseName, nTimeElapsed .. ': ' .. nTimeElapsed .. ' / ' .. nFreq)
						local nTargetRollCount = nTotalRolls - nPrevRollCount
						if nTargetRollCount > 0 then
							local nDurationWithOnset, nDuration, nDurUnit = calculateDuration(nodeDisease, sDiseaseName, nOnset)
							if nDurationWithOnset then nTargetRollCount = math.min(nTargetRollCount, nDurationWithOnset / nFreq) end
							if nDurUnit == 0.1 then nTargetRollCount = nTargetRollCount - 1 end -- fix rounds-based maladies rolling once too many times
							Debug.console(rActor.name, sDiseaseName, 'Previous Rolls:' .. nPrevRollCount, 'Rolls Due:' .. nTargetRollCount)

							-- if character auto-roll is disabled, request roll via a chat message.
							local bIsAutoRoll = DB.getValue(nodeActor, 'diseaserollactive', 1) == 1
							local nRollCount = 0
							if not bIsAutoRoll and nTargetRollCount > 0 then
								ChatManager.Message(
									string.format(
										Interface.getString('disease_agencynotifer'),
										DB.getValue(nodeActor, 'name', 'A character'),
										nTargetRollCount,
										'a ' .. DB.getValue(nodeDisease, 'type', 'malady')),
									false, rActor)
							else
								-- rolls saving throws until the desired total is achieved
								repeat
									ActionDiseaseSave.performRoll(nil, rActor, nodeDisease)
									nRollCount = nRollCount + 1
								until nRollCount >= nTargetRollCount
							end

							-- if the disease has a duration and the duration has now expired,
							-- announce in chat, delete the save-counting + time records,
							-- and add [EXPIRED] to the disease name
							if nDuration and nDuration > 0 and nDurationWithOnset and nTimeElapsed >= nDurationWithOnset then
								DB.setValue(nodeDisease, 'starttime', 'number', nil)
								DB.setValue(nodeDisease, 'starttimestring', 'string', nil)
								DB.setValue(nodeDisease, 'savecount', 'number', nil)
								if not string.find(DB.getValue(nodeDisease, 'name', ''), '%[EXPIRED%]') then
									DB.setValue(nodeDisease, 'name', 'string', '[EXPIRED] ' .. sDiseaseName)
								end
								ChatManager.Message(
									string.format(
										Interface.getString('disease_expiration'),
										DB.getValue(nodeActor, 'name', 'A character'),
										sDiseaseName),
									false, rActor)
							end
							
							-- saves the new total for use next time
							DB.setValue(nodeDisease, 'savecount', 'number', nPrevRollCount + nRollCount)
						end
					end
				end
			end
		end
	end
end