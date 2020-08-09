--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

function onInit()
	if TimeManager then DB.addHandler('calendar.dateinminutes', 'onUpdate', onTimeChanged) end
end

---	This function is called by the handler which watches for changes in current time.
--	The handler is only configured if the ClockAdjuster extension is installed.
--	@param node the databasenode corresponding to the calendar (two levels below database root)
function onTimeChanged(node)
	local nDateinMinutes = TimeManager.getCurrentDateinMinutes()
	-- iterates through each player character
	for _,nodeChar in pairs(DB.getChildren(node.getChild('...'), 'charsheet')) do
		-- iterates through each diseases and poisons of the player character
		for _,nodeDisease in pairs(DB.getChildren(nodeChar, 'diseases')) do
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
				local rActor = ActorManager.getActor('pc', nodeChar)
								
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
				
				-- if savetype is known and more saves are due to be rolled
				if DB.getValue(nodeDisease, 'savetype') and nNewRollCount > nPrevRollCount then
					local nRollCount = 0
					-- rolls saving throws until the desired total is achieved
					repeat
						rollSave(rActor, nodeDisease)
						
						nRollCount = nRollCount + 1
					until nRollCount == nTargetRollCount
					
					-- if the disease has a duration and the duration has now expired,
					-- announce in chat, delete the save-counting + time records,
					-- and add [EXPIRED] to the disease name
					if nDuration ~= 0 and nTimeElapsed >= nDuration then
						DB.setValue(nodeDisease, 'starttime', 'number', nil)
						DB.setValue(nodeDisease, 'savecount', 'number', nil)
						DB.setValue(nodeDisease, 'name', 'string', '[EXPIRED] ' .. sDiseaseName)
						ChatManager.SystemMessage(DB.getValue(nodeChar, 'name') .."'s " .. sDiseaseName .. ' has run its course.')
						break
					end
					
					DB.setValue(nodeDisease, 'savecount', 'number', nPrevRollCount + nRollCount)	-- saves the new total for use next time
					if DB.getValue(nodeDisease, 'isconsecutive', 1) == 0 then
						-- DB.setValue(nodeDisease, 'savecount_consec', 'number', nPrevRollCount + nRollCount)
					else
						
					end
					
					local nConsecutiveSaves = DB.getValue(nodeDisease, 'savecount_consec', 0)
					local nSavesReq = DB.getValue(nodeDisease, 'savesreq', 0)
					
					if nSavesReq ~= 0 and nConsecutiveSaves >= nSavesReq then
						DB.setValue(nodeDisease, 'starttime', 'number', nil)
						DB.setValue(nodeDisease, 'savecount', 'number', nil)
						DB.setValue(nodeDisease, 'name', 'string', '[CURED] ' .. sDiseaseName)
						ChatManager.SystemMessage(DB.getValue(nodeChar, 'name') ..' has overcome their ' .. sDiseaseName .. '.')
						break
					end
				end
			end
		end
	end
end

--- Allow dragging and dropping madnesses between players
function addDisease(nodeChar, sClass, sRecord, nodeTargetList)
	if not nodeChar then
		return false;
	end
	
	if sClass == 'referencedisease' then
		local nodeSource = CharManager.resolveRefNode(sRecord)
		if not nodeSource then
			return
		end
		
		if not nodeTargetList then
			return
		end
		
		local nodeEntry = nodeTargetList.createChild()
		DB.copyNode(nodeSource, nodeEntry)
	else
		return false
	end
	
	return true
end

---	This function rolls the save specified in the disease information
function rollSave(rActor, nodeDisease)
	ActionDiseaseSave.performRoll(nil, rActor, nodeDisease)
end