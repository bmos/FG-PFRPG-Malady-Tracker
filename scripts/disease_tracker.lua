--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

function onInit()
	if TimeManager_Disabled and LongTermEffects then
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

function calculateFrequency(nodeDisease, sDiseaseName)
	local nFreqUnit = tonumber(DB.getValue(nodeDisease, 'freq_unit'))
	local nFreqVal = DB.getValue(nodeDisease, 'freq_interval')
	local nFreq
	-- Debug.console(sDiseaseName, 'nFreqUnit: ' .. nFreqUnit, 'nFreqVal: ' .. nFreqVal)
	if nFreqUnit and nFreqVal then
		nFreq = nFreqUnit * nFreqVal
	end
	-- Debug.console(sDiseaseName, 'Frequency: ' .. nFreq or 'nil')

	return nFreq
end

function calculateDuration(nodeDisease, sDiseaseName, nOnset)
	local nDurUnit = tonumber(DB.getValue(nodeDisease, 'duration_unit'))
	local nDurVal = DB.getValue(nodeDisease, 'duration_interval')
	local nDuration
	-- Debug.console(sDiseaseName, 'nDurUnit: ' .. nDurUnit, 'nDurVal: ' .. nDurVal)
	if nDurUnit and nDurVal then
		nDuration = nDurUnit * nDurVal
		nDurationWithOnset = nDurUnit * nDurVal + nOnset
	end
	-- Debug.console(sDiseaseName, 'nDurationWithOnset: ' .. nDurationWithOnset, 'nDuration: ' .. nDuration)

	return nDurationWithOnset, nDuration, nDurUnit
end

function calculateOnset(nodeDisease, sDiseaseName)
	local nOnsUnit = tonumber(DB.getValue(nodeDisease, 'onset_unit'))
	local nOnsVal = DB.getValue(nodeDisease, 'onset_interval')
	local nOnset
	-- Debug.console(sDiseaseName, 'nOnsUnit: ' .. nOnsUnit, 'nOnsVal: ' .. nOnsVal)
	if nOnsUnit and nOnsVal then
		nOnset = nOnsUnit * nOnsVal
	end
	-- Debug.console(sDiseaseName, 'nOnset: ' .. nOnset)

	return nOnset
end

-- This function iterates through each disease and poison of the character
function parseDiseases()
	local nDateWithRounds = TimeManager.getCurrentDateinMinutes()
	for _,nodeCT in pairs(DB.getChildren('combattracker.list')) do
		local rActor = ActorManager.resolveActor(nodeCT)
		local nodeActor = ActorManager.getCreatureNode(rActor)
		for _,nodeDisease in pairs(DB.getChildren(nodeActor, 'diseases')) do
			local nDateOfContr = DB.getValue(nodeDisease, 'starttimestring') or DB.getValue(nodeDisease, 'starttime')
			if nDateOfContr and DB.getValue(nodeDisease, 'savetype') and not string.find(DB.getValue(nodeDisease, 'name', ''), '%[') then
				local nTimeSinceContraction = nDateWithRounds - nDateOfContr

				local nOnset = calculateOnset(nodeDisease, sDiseaseName) or 0
				nDiseaseElapsed = round(nTimeSinceContraction - nOnset, 1)

				local sDiseaseName = DB.getValue(nodeDisease, 'name', 'their disease')
				Debug.console(sDiseaseName, 'nDiseaseElapsed: ' .. nDiseaseElapsed)
				-- if the disease has a starting time, the current time is known, and any onset has elapsed
				if nDiseaseElapsed > 0 then
					local nFreq = calculateFrequency(nodeDisease, sDiseaseName)
					if nFreq then
						local nPrevRollCount = DB.getValue(nodeDisease, 'savecount', 0) -- how many saves have been successful
						local nTotalRolls = round(nDiseaseElapsed / nFreq, 0)
						-- Debug.console(sDiseaseName, 'nTotalRolls: ' .. nTotalRolls, 'nPrevRollCount: ' .. nPrevRollCount)
						local nTargetRollCount = nTotalRolls - nPrevRollCount
						if nTargetRollCount > 0 then
							local nDurationWithOnset, nDuration, nDurUnit = calculateDuration(nodeDisease, sDiseaseName, nOnset)
							if nDurationWithOnset then nTargetRollCount = math.min(nTargetRollCount, nDuration / nFreq); end
							-- Debug.console(sDiseaseName, 'nDurationWithOnset: ' .. nDurationWithOnset, 'nDiseaseElapsed: ' .. nDiseaseElapsed)
							-- Debug.console(sDiseaseName, 'nTargetRollCount: ' .. nTargetRollCount)

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
									true, rActor)
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
							if (nDuration and nDuration > 0) and (nDiseaseElapsed >= nDuration) then
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
									true, rActor)
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