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
		
		if nodeSource.getChild('....') and nodeSource.getChild('....').getName() ~= 'charsheet' then
			if DB.getValue(nodeSource, 'onset_dice') then
				ActionDiseaseTimeRoll.performRoll(draginfo, nodeEntry, rActor, DB.getValue(nodeSource, 'onset_dice'), DB.getValue(nodeSource, 'onset_interval'), 'Onset')
			end
			if DB.getValue(nodeSource, 'freq_dice') then
				ActionDiseaseTimeRoll.performRoll(draginfo, nodeEntry, rActor, DB.getValue(nodeSource, 'freq_dice'), DB.getValue(nodeSource, 'freq_interval'), 'Frequency')
			end
			if DB.getValue(nodeSource, 'duration_dice') then
				ActionDiseaseTimeRoll.performRoll(draginfo, nodeEntry, rActor, DB.getValue(nodeSource, 'duration_dice'), DB.getValue(nodeSource, 'duration_interval'), 'Duration')
			end
		end
		if TimeManager and DB.getValue(nodeEntry, 'freq_interval') and tonumber(DB.getValue(nodeEntry, 'freq_unit', 0.1)) then
			local nRound = DB.getValue(nodeEntry.getChild('.....'), 'combattracker.round', 1)
			DB.setValue(nodeEntry, 'starttime', 'number', TimeManager.getCurrentDateinMinutes() + ( 0.1 * nRound ))
			DB.setValue(nodeEntry, 'starttimestring', 'string', tostring(TimeManager.getCurrentDateinMinutes() + ( 0.1 * nRound )))
			DB.setValue(nodeEntry, 'savecount', 'number', 0)
		end
		if DB.getValue(nodeEntry, 'dc_notifier') == 1 then
			ChatManager.SystemMessage(Interface.getString("disease_msg_dcnotifier"))
		end
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