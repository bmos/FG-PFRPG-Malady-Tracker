---
--- Initialization
---

function onInit()
	GameSystem.actions["diseasetimeroll"] = { bUseModStack = false };
	ActionsManager.registerResultHandler("diseasetimeroll", onRoll);
end

function getRoll(rActor, tDice, nFixedInt, sField)
	local rRoll = {};
	
	rRoll.sType = "diseasetimeroll";
	rRoll.aDice = tDice;
	rRoll.nMod = nFixedInt;
	rRoll.sDesc = sField;
	
	return rRoll;
end

-- Start the action process
function performRoll(draginfo, nodeDisease, rActor, tDice, nFixedInt, sField)
	local rRoll = getRoll(rActor, tDice, nFixedInt, sField);
	rRoll.nodeDisease = nodeDisease.getPath()
	
	ActionsManager.performAction(draginfo, rActor, rRoll);
end

function onRoll(rSource, rTarget, rRoll)
	local rMessage = ActionsManager.createActionMessage(rSource, rRoll);
	Comm.deliverChatMessage(rMessage);
	
	local nodeDisease = {}
	if rRoll.nodeDisease then nodeDisease = DB.findNode(rRoll.nodeDisease) end
	if nodeDisease then
		rRoll.nTotal = ActionsManager.total(rRoll)
		
		if rRoll.sDesc == 'Onset' then DB.setValue(nodeDisease, 'onset_interval', 'number', rRoll.nTotal)
		elseif rRoll.sDesc == 'Frequency' then DB.setValue(nodeDisease, 'freq_interval', 'number', rRoll.nTotal)
		elseif rRoll.sDesc == 'Duration' then DB.setValue(nodeDisease, 'duration_interval', 'number', rRoll.nTotal) end
	end
end