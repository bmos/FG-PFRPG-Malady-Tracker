--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

function onInit()
	if Session.IsHost then
		if LongTermEffects then
			if DB.getValue('calendar.dateinminutesstring') then
				DB.addHandler('calendar.dateinminutesstring', 'onUpdate', onTimeChanged)
			else
				DB.addHandler('calendar.dateinminutes', 'onUpdate', onTimeChanged)
			end
			DB.addHandler('combattracker.round', 'onUpdate', onTimeChanged)
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
end

-- This function iterates through each disease and poison of the character
local function parseDiseases(nodeActor, nDateinMinutes)
	for _,nodeDisease in pairs(DB.getChildren(nodeActor, 'diseases')) do
		local sDiseaseName = DB.getValue(nodeDisease, 'name', 'their disease')
		local nDateOfContr = DB.getValue(nodeDisease, 'starttime')
		if DB.getValue(nodeDisease, 'starttimestring') then nDateOfContr = tonumber(DB.getValue(nodeDisease, 'starttimestring')) end
		if not nDateOfContr then nDateOfContr = nDateinMinutes end
		if (nDateOfContr <= 0) then return; end -- only continue if disease starting time has been set
		local nTimeElapsed = DiseaseTrackerLib.round((nDateinMinutes - nDateOfContr), 1)
		local nOnsUnit = tonumber(DB.getValue(nodeDisease, 'onset_unit', '0'))
		local nOnsVal = DB.getValue(nodeDisease, 'onset_interval', 0)
		local nOnset = 0
		
		-- if onset components are configured, calculate total time to onset
		if (nOnsUnit ~= 0) and (nOnsVal ~= 0) then nOnset = (nOnsUnit * nOnsVal) end
		
		-- if the disease has a starting time, the current time is known, and any onset has elapsed
		if nDateOfContr ~= 0 and (nTimeElapsed >= nOnset) then
			local nFreqUnit = tonumber(DB.getValue(nodeDisease, 'freq_unit', '1'))
			local nFreqVal = DB.getValue(nodeDisease, 'freq_interval', 1)
			local nFreq = (nFreqUnit * nFreqVal)
			-- if freqency components are configured, calculate freqency
			if (nFreq == 0) then return; end

			local nPrevRollCount = DB.getValue(nodeDisease, 'savecount', 0)
			local nNewRollCount = ((nTimeElapsed - nOnset) / nFreq) + 1
			if string.find(tostring(nNewRollCount), '%.') then nNewRollCount = math.floor(nNewRollCount) end
			if (nNewRollCount < 0) then nNewRollCount = 0 end
			local nTargetRollCount = nNewRollCount - nPrevRollCount
			
			local nDurUnit = tonumber(DB.getValue(nodeDisease, 'duration_unit', '0'))
			if (nDurUnit == nil) then nDurUnit = 0 end -- I'm not sure why this needs to be here, but it does to support no-duration.
			local nDurVal = DB.getValue(nodeDisease, 'duration_interval', 0)
			-- if duration components are configured, calculate total duration
			local nDuration = (nDurUnit * nDurVal)
			if (nDuration ~= 0) then
				-- if the disease has a duration, recalculate how many rolls should have been rolled
				if (nTargetRollCount > (nDuration / nFreq)) then nTargetRollCount = nDuration / nFreq end
				if (nOnset ~= 0) then nDuration = nDuration + nOnset end
			end

			local sDiseaseType = DB.getValue(nodeDisease, 'type', '')
			local bIsAutoRoll = (DB.getValue(nodeActor, 'diseaserollactive', 1) == 1)
			if not bIsAutoRoll and (nTargetRollCount and (nTargetRollCount > 0)) then
				ChatManager.SystemMessage(string.format(Interface.getString('disease_agencynotifer'), DB.getValue(nodeActor, 'name', 'A character'), nTargetRollCount, 'a ' .. sDiseaseType))
				-- alternate messaging that exposes the name of the malady
				--ChatManager.SystemMessage(string.format(Interface.getString('disease_agencynotifer'), DB.getValue(nodeActor, 'name', 'A character'), nTargetRollCount, sDiseaseName))
			end
			
			-- if savetype is known and more saves are due to be rolled
			if DB.getValue(nodeDisease, 'savetype') and (nNewRollCount >= 1) and (nTargetRollCount > 0) then
				local rActor = ActorManager.getCreatureNode(nodeActor)
				local nRollCount = 0
				if (nDurUnit == 0.1) then nRollCount = 1 end
				
				-- rolls saving throws until the desired total is achieved
				repeat
					if bIsAutoRoll and not string.find(DB.getValue(nodeDisease, 'name', ''), '%[') then ActionDiseaseSave.performRoll(nil, rActor, nodeDisease) end
					nRollCount = nRollCount + 1
				until nRollCount >= nTargetRollCount
				
				-- if the disease has a duration and the duration has now expired,
				-- announce in chat, delete the save-counting + time records,
				-- and add [EXPIRED] to the disease name
				if (nDuration ~= 0) and (nTimeElapsed >= nDuration) then
					DB.setValue(nodeDisease, 'starttime', 'number', nil)
					DB.setValue(nodeDisease, 'starttimestring', 'string', nil)
					DB.setValue(nodeDisease, 'savecount', 'number', nil)
					if not string.find(DB.getValue(nodeDisease, 'name', ''), '%[EXPIRED%]') then
						DB.setValue(nodeDisease, 'name', 'string', '[EXPIRED] ' .. sDiseaseName)
					end
					ChatManager.SystemMessage(string.format(Interface.getString('disease_expiration'), DB.getValue(nodeActor, 'name', 'A character'), sDiseaseName))
					break
				end
				
				if (nDurUnit == 0.1) then nRollCount = nRollCount - 1 end
				DB.setValue(nodeDisease, 'savecount', 'number', nPrevRollCount + nRollCount) -- saves the new total for use next time
			end
		end
	end
end

---	This function is called by the handler which watches for changes in current time.
--	The handler is only configured if the ClockAdjuster extension is installed.
function onTimeChanged()
	local nRound = DB.getValue(CombatManager.CT_ROUND, 1)
	local nDateinMinutes = TimeManager.getCurrentDateinMinutes() + ( 0.1 * nRound )
	-- iterates through each player character
	for _,nodeChar in pairs(DB.getChildren('charsheet')) do
		parseDiseases(nodeChar, nDateinMinutes)
	end
	-- iterates through each non-player character
	for _,nodeNPC in pairs(DB.getChildren(CombatManager.CT_LIST)) do
		parseDiseases(nodeNPC, nDateinMinutes)
	end
end