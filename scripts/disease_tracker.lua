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
			local nDateOfContr = DB.getValue(vvNode, 'starttime')
			if nDateOfContr and nDateinMinutes then								-- if the disease has a date of contraction listed and the current date is known
				local nTimeElapsed = nDateinMinutes - nDateOfContr
				local nFreq = DB.getValue(vvNode, 'remindercycle', 1)
				local nPrevRollCount = DB.getValue(vvNode, 'savecount', 0)
				local nNewRollCount = math.floor(nTimeElapsed / nFreq)
				
				if DB.getValue(vvNode, 'savetype') and nNewRollCount > nPrevRollCount then	-- if savetype is known and more saves are due
					local nRollCount = 0
					repeat														-- rolls saving throws until the correct total number have been rolled
						local rActor = ActorManager.getActor('pc', vNode)
						local sSave = DB.getValue(vvNode, 'savetype')
						local nDC = DB.getValue(vvNode, 'savedc')
						local sType = DB.getValue(vvNode, 'type')
						rollSave(rActor, sSave, nDC, sType)

						nRollCount = nRollCount + 1
					until nRollCount == (nNewRollCount - nPrevRollCount)

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
function rollSave(rActor, sSave, nDC, sType)
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
	if sType == 'disease' then rRoll.tags = 'diseasetracker' end
	if sType == 'poison' then rRoll.tags = 'poisontracker' end

	ActionsManager.performAction(nil, rActor, rRoll)
end