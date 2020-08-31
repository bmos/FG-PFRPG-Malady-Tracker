-- 
-- Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

--- Allow dragging and dropping madnesses between players
local function addDisease(nodeChar, sClass, sRecord, nodeTargetList)
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

function onDrop(x, y, draginfo)
	return handleDrop(draginfo, nil);
end

function handleDrop(draginfo, nodeTargetList)
	if draginfo.isType("shortcut") then
		local sClass, sRecord = draginfo.getShortcutData()
		if StringManager.contains({"referencedisease"}, sClass) then
			addDisease(getDatabaseNode(), sClass, sRecord, nodeTargetList)
			return true
		end
	end
end