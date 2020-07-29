--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

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
function rollSave(rActor, sSave, nDC)
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

	ActionsManager.performAction(nil, rActor, rRoll)
end