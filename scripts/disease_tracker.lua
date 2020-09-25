--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

aSBOverrides = {
	-- CoreRPG overrides
	["disease"] = {
		bExport = true,
		aDataMap = { "disease", "reference.diseases" }, 
		aDisplayIcon = { "button_diseases", "button_diseases_down" },
		sRecordDisplayClass = "referencedisease", 
		aGMListButtons = { "button_feat_type" };
		aPlayerListButtons = { "button_feat_type" };
		aCustomFilters = {
			["Type"] = { sField = "type" },
		},
	},
};

function onInit()
	if User.isHost() and TimeManager then
		DB.addHandler('calendar.dateinminutes', 'onUpdate', onTimeChanged)
		DB.addHandler('combattracker.round', 'onUpdate', onTimeChanged)
	end
	for kRecordType,vRecordType in pairs(aSBOverrides) do
		LibraryData.setRecordTypeInfo(kRecordType, vRecordType)
	end
end

-- This function iterates through each disease and poison of the character
local function parseDiseases(nodeActor, nDateinMinutes)
	for _,nodeDisease in pairs(DB.getChildren(nodeActor, 'diseases')) do
		local sDiseaseName = DB.getValue(nodeDisease, 'name', '')
		local nDateOfContr = DB.getValue(nodeDisease, 'starttime', nDateinMinutes)
		local nTimeElapsed = nDateinMinutes - nDateOfContr
		
		local nOnsUnit = DB.getValue(nodeDisease, 'onset_unit', 0)
		local nOnsVal = DB.getValue(nodeDisease, 'onset_interval', 0)
		local nOnset = 0
		
		-- if onset components are configured, calculate total time to onset
		if nOnsUnit ~= 0 and nOnsVal ~= 0 then nOnset = (nOnsUnit * nOnsVal) end
		
		-- if the disease has a starting time, the current time is known, and any onset has elapsed
		if nDateOfContr ~= 0 and nDateinMinutes and (nTimeElapsed >= nOnset) then
			local nFreq = DB.getValue(nodeDisease, 'freq_unit', 1)
			local nDurUnit = DB.getValue(nodeDisease, 'duration_unit', 0)
			local nDurVal = DB.getValue(nodeDisease, 'duration_interval', 0)
			local nDuration = 0
			
			-- if duration components are configured, calculate total duration
			if nDurUnit ~= 0 and nDurVal ~= 0 then nDuration = (nDurUnit * nDurVal) end

			local nPrevRollCount = DB.getValue(nodeDisease, 'savecount', 0)
			local nNewRollCount = math.floor((nTimeElapsed - nOnset) / nFreq) + 1
			if not (nNewRollCount >= 0) then nNewRollCount = 0 end
			local nTargetRollCount = nNewRollCount - nPrevRollCount
			
			-- if the disease has a duration, recalculate how many rolls should have been rolled
			if nDuration ~= 0 and nTargetRollCount > (nDuration / nFreq) then nTargetRollCount = (nDuration / nFreq) end

			local sDiseaseType = DB.getValue(nodeDisease, 'type', '')
			local bIsAutoRoll = (DB.getValue(nodeActor, 'diseaserollactive', 1) == 1)
			if not bIsAutoRoll then ChatManager.SystemMessage(DB.getValue(nodeActor, 'name') ..' is due to roll ' .. nTargetRollCount .. ' saving throws against their ' .. sDiseaseName .. ' ' .. sDiseaseType .. '.') end
			
			-- if savetype is known and more saves are due to be rolled
			if DB.getValue(nodeDisease, 'savetype') and nNewRollCount > nPrevRollCount then
				local rActor = ActorManager.getActor('pc', nodeActor)
				local nRollCount = 0
				-- rolls saving throws until the desired total is achieved
				repeat
					if bIsAutoRoll then rollSave(rActor, nodeDisease) end
					
					nRollCount = nRollCount + 1
				until nRollCount == nTargetRollCount
				
				-- if the disease has a duration and the duration has now expired,
				-- announce in chat, delete the save-counting + time records,
				-- and add [EXPIRED] to the disease name
				if nDuration ~= 0 and nTimeElapsed >= nDuration then
					DB.setValue(nodeDisease, 'starttime', 'number', nil)
					DB.setValue(nodeDisease, 'savecount', 'number', nil)
					DB.setValue(nodeDisease, 'name', 'string', '[EXPIRED] ' .. sDiseaseName)
					ChatManager.SystemMessage(DB.getValue(nodeActor, 'name') .."'s " .. sDiseaseName .. ' has run its course.')
					break
				end
				
				DB.setValue(nodeDisease, 'savecount', 'number', nPrevRollCount + nRollCount)	-- saves the new total for use next time
			end
		end
	end
end

---	This function is called by the handler which watches for changes in current time.
--	The handler is only configured if the ClockAdjuster extension is installed.
--	@param node the databasenode corresponding to the calendar (two levels below database root)
function onTimeChanged(node)
	timeConcierge(node)
	-- DB.setValue(node.getChild('...'), 'combattracker.round', 'number', 1)
end

---	This function is called by the handler which watches for changes in current time.
--	The handler is only configured if the ClockAdjuster extension is installed.
--	@param node the databasenode corresponding to the calendar (two levels below database root)
function timeConcierge(node)
	local nRound = DB.getValue(node.getChild('...'), 'combattracker.round', 1)
	local nDateinMinutes = TimeManager.getCurrentDateinMinutes() + ( 0.1 * nRound )
	-- iterates through each player character
	for _,nodeChar in pairs(DB.getChildren(node.getChild('...'), 'charsheet')) do
		parseDiseases(nodeChar, nDateinMinutes)
	end
	-- iterates through each non-player character
	for _,nodeNPC in pairs(DB.getChildren(node.getChild('...'), 'combattracker.list')) do
		parseDiseases(nodeNPC, nDateinMinutes)
	end
end

---	This function rolls the save specified in the disease information
function rollSave(rActor, nodeDisease)
	ActionDiseaseSave.performRoll(nil, rActor, nodeDisease)
end