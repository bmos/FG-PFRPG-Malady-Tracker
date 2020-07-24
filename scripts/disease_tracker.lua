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