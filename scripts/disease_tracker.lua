--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

function onInit()
	if TimeManager then DB.addHandler("calendar.current", "onChildUpdate", onTimeChanged) end
end

function onTimeChanged(node)
	local nDateinMinutes = TimeManager.getCurrentDateinMinutes()
	for _,vNode in pairs(DB.getChildren(node.getChild('...'), "charsheet")) do 	-- iterates through each player character
		for _,vvNode in pairs(DB.getChildren(vNode, "diseases")) do 			-- iterates through each disease of the player character
			local sDiseaseName = DB.getValue(vvNode, 'name', '')
			local nDateOfContr = DB.getValue(vvNode, 'starttime', 0)
			local nTimeElapsed = nDateinMinutes - nDateOfContr
			
			local nOnsUnit = DB.getValue(vvNode, 'onset_unit', 0)
			local nOnsVal = DB.getValue(vvNode, 'onset_interval', 0)
			local nOnset = 0
			
			if nOnsUnit ~= 0 and nOnsVal ~= 0 then nOnset = (nOnsUnit * nOnsVal) end
			
			-- if the disease has a date of contraction listed, the current date is known, and enough time has elapsed for the disease to kick in
			if nDateOfContr ~= 0 and nDateinMinutes and (nTimeElapsed >= nOnset) then
				Debug.chat(nTimeElapsed, nOnset)
				local rActor = ActorManager.getActor('pc', vNode)
				
				local sType = DB.getValue(vvNode, 'type')
				local sSave = DB.getValue(vvNode, 'savetype')
				local nDC = DB.getValue(vvNode, 'savedc')
				
				local nFreq = DB.getValue(vvNode, 'freq_unit', 1)
				local nDurUnit = DB.getValue(vvNode, 'duration_unit', 0)
				local nDurVal = DB.getValue(vvNode, 'duration_interval', 0)
				local nDuration = 0

				if nDurUnit ~= 0 and nDurVal ~= 0 then nDuration = (nDurUnit * nDurVal) end

				local nPrevRollCount = DB.getValue(vvNode, 'savecount', 0)
				local nNewRollCount = math.floor((nTimeElapsed - nOnset) / nFreq) + 1
				if not (nNewRollCount >= 0) then nNewRollCount = 0 end
				local nTargetRollCount = nNewRollCount - nPrevRollCount
				
				if nDuration ~= 0 and nTargetRollCount > (nDuration / nFreq) then nTargetRollCount = (nDuration / nFreq) end
				
				if sSave and nNewRollCount > nPrevRollCount then	-- if savetype is known and more saves are due
					local nRollCount = 0
					repeat											-- rolls saving throws until the correct total number have been rolled
						rollSave(rActor, sSave, nDC, sType, sDiseaseName)

						nRollCount = nRollCount + 1
					until nRollCount == nTargetRollCount
					
					if nDurUnit ~= 0 and nDurVal ~= 0 and nTimeElapsed >= nDuration then
						DB.setValue(vvNode, 'starttime', 'number', nil)
						DB.setValue(vvNode, 'savecount', 'number', nil)
						DB.setValue(vvNode, 'name', 'string', '[EXPIRED] ' .. sDiseaseName)
						ChatManager.SystemMessage(DB.getValue(vNode, 'name') .."'s " .. sDiseaseName .. ' has run its course.')
						break
					end

					DB.setValue(vvNode, 'savecount', 'number', nPrevRollCount + nRollCount)	-- saves the new total for use next time
				end
			end
		end
	end
end

--- Allow dragging and dropping madnesses between players
--	@return nodeChar This is the databasenode of the player character within charsheet.
--	@return sClass 
--	@return sRecord 
--	@return nodeTargetList 
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
function rollSave(rActor, sSave, nDC, sType, sDiseaseName)
	if sSave == 'fort' then
		sSave = 'fortitude'
	elseif sSave == 'ref' then
		sSave = 'reflex'
	elseif sSave == 'will' then
		sSave = 'will'
	elseif sSave == 'none' then
		sSave = nil
	end

	local rRoll = ActionSave.getRoll(rActor, sSave)

	if nDC == 0 then
		nDC = nil
	end
	rRoll.nTarget = nDC
	if sType ~= '' then
		rRoll.tags = sType .. 'tracker'
	end
	if sDiseaseName ~= '' and sSave then
		rRoll.sDesc = '[' .. string.upper(sType) .. '] ' .. sDiseaseName .. ' [' .. string.upper(sSave) .. ' SAVE]'
	end
	
	ActionsManager.performAction(nil, rActor, rRoll)
end