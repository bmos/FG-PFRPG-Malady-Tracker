--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

function onInit()
	if LongTermEffects then
		CombatManager.setCustomTurnEnd(parseDiseases)
		CalendarManager.registerChangeCallback(parseDiseases)
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
function roundDown(number, decimals)
    local n = 10^(decimals or 0)
    number = number * n
    number = math.floor(number + 0.5)
    return number / n
end

-- This function iterates through each disease and poison of the character
function parseDiseases(nodeActor)
	if not nodeActor then return; end
	local rActor = ActorManager.resolveActor(nodeActor)
	local nRound = DB.getValue("combattracker.round", 0)
	local nInit = DB.getValue(ActorManager.getCTNode(rActor), "initresult", 0)
	if nInit ~= 0 then nInit = 0.1 - (0.001 * (nInit)) end
	local nDateinMinutes = TimeManager.getCurrentDateinMinutes() + nInit
	--Debug.chat('current', nDateinMinutes, nodeActor)
	for _,nodeCT in pairs(DB.getChildren('combattracker.list')) do
		local rActor = ActorManager.resolveActor(nodeCT)
		local nodeActor = ActorManager.getCreatureNode(rActor)
		for _,nodeDisease in pairs(DB.getChildren(nodeActor, 'diseases')) do
			local sDiseaseName = DB.getValue(nodeDisease, 'name', 'their disease')
			local nDateOfContr = DB.getValue(nodeDisease, 'starttime')
			if DB.getValue(nodeDisease, 'starttimestring') then nDateOfContr = tonumber(DB.getValue(nodeDisease, 'starttimestring')) end
			if not nDateOfContr then return; end -- only continue if disease starting time has been set
			local nTimeElapsed = roundDown(nDateinMinutes - nDateOfContr, 3)
			--Debug.chat(nodeActor, sDiseaseName, nTimeElapsed)
			local nOnsUnit = tonumber(DB.getValue(nodeDisease, 'onset_unit', 0))
			local nOnsVal = DB.getValue(nodeDisease, 'onset_interval', 0)
			local nOnset = 0
			
			-- if onset components are configured, calculate total time to onset
			if nOnsUnit ~= 0 and nOnsVal ~= 0 then nOnset = nOnsUnit * nOnsVal end
			
			-- if the disease has a starting time, the current time is known, and any onset has elapsed
			if nDateOfContr ~= 0 and nTimeElapsed - nOnset >= 0.1 then
				local nFreqUnit = tonumber(DB.getValue(nodeDisease, 'freq_unit', 1))
				local nFreqVal = DB.getValue(nodeDisease, 'freq_interval', 1)
				local nFreq = nFreqUnit * nFreqVal
				-- if freqency components are configured, calculate freqency
				if nFreq == 0 then return; end

				local nPrevRollCount = DB.getValue(nodeDisease, 'savecount', 0) -- how many saves have been successful
				local nNewRollCount = (nTimeElapsed - nOnset) / nFreq
				if string.find(tostring(nNewRollCount), '%.') then nNewRollCount = math.floor(nNewRollCount) end
				local nTargetRollCount = nNewRollCount - nPrevRollCount
				--Debug.chat(sDiseaseName, 'Previous Rolls:' .. nPrevRollCount, 'Target/New Rolls:' .. nTargetRollCount)
				if nTargetRollCount < 0 then nTargetRollCount = 0 end
				
				local nDurUnit = tonumber(DB.getValue(nodeDisease, 'duration_unit')) or 0
				local nDurVal = DB.getValue(nodeDisease, 'duration_interval', 0)
				-- if duration components are configured, calculate total duration
				local nDuration = nDurUnit * nDurVal
				if nDuration ~= 0 then
					-- if the disease has a duration, recalculate how many rolls should have been rolled
					if nTargetRollCount > (nDuration / nFreq) then nTargetRollCount = nDuration / nFreq end
					if nOnset ~= 0 then nDuration = nDuration + nOnset end
				end

				local sDiseaseType = DB.getValue(nodeDisease, 'type', '')
				local bIsAutoRoll = (DB.getValue(nodeActor, 'diseaserollactive', 1) == 1)
				if not bIsAutoRoll and (nTargetRollCount and (nTargetRollCount > 0)) then
					ChatManager.Message(string.format(Interface.getString('disease_agencynotifer'), DB.getValue(nodeActor, 'name', 'A character'), nTargetRollCount, 'a ' .. sDiseaseType), false, rActor)
				end
				
				-- if savetype is known and more saves are due to be rolled
				if DB.getValue(nodeDisease, 'savetype') and (nNewRollCount >= 1) and (nTargetRollCount > 0) then
					local nRollCount = 0
					if nDurUnit == 0.1 then nRollCount = 1 end
					
					-- rolls saving throws until the desired total is achieved
					repeat
						if bIsAutoRoll and not string.find(DB.getValue(nodeDisease, 'name', ''), '%[') then ActionDiseaseSave.performRoll(nil, rActor, nodeDisease) end
						nRollCount = nRollCount + 1
					until nRollCount >= nTargetRollCount
					
					-- if the disease has a duration and the duration has now expired,
					-- announce in chat, delete the save-counting + time records,
					-- and add [EXPIRED] to the disease name
					if nDuration ~= 0 and nTimeElapsed >= nDuration then
						DB.setValue(nodeDisease, 'starttime', 'number', nil)
						DB.setValue(nodeDisease, 'starttimestring', 'string', nil)
						DB.setValue(nodeDisease, 'savecount', 'number', nil)
						if not string.find(DB.getValue(nodeDisease, 'name', ''), '%[EXPIRED%]') then
							DB.setValue(nodeDisease, 'name', 'string', '[EXPIRED] ' .. sDiseaseName)
						end
						ChatManager.Message(string.format(Interface.getString('disease_expiration'), DB.getValue(nodeActor, 'name', 'A character'), sDiseaseName), false, rActor)
						break
					end
					
					if nDurUnit == 0.1 then nRollCount = nRollCount - 1 end
					DB.setValue(nodeDisease, 'savecount', 'number', nPrevRollCount + nRollCount) -- saves the new total for use next time
				end
			end
		end
	end
end