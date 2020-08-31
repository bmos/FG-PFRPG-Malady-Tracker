---
--- Initialization
---

function onInit()
	GameSystem.actions["diseasetimeroll"] = { bUseModStack = false };
	ActionsManager.registerResultHandler("diseasetimeroll", onRoll);
end

local function getRoll(rActor, tDice, sDesc)
	local rRoll = {};
	
	rRoll.sType = "diseasetimeroll";
	rRoll.aDice = tDice;
	rRoll.nMod = 0;
	rRoll.sDesc = sDesc;
	
	return rRoll;
end

-- Start the action process
function performRoll(draginfo, rActor, tDice, sDesc)
	local rRoll = getRoll(rActor, tDice, sDesc);
	
	ActionsManager.performAction(draginfo, rActor, rRoll);
end

function onRoll(rSource, rTarget, rRoll)
	local rMessage = ActionsManager.createActionMessage(rSource, rRoll);
	Comm.deliverChatMessage(rMessage);
end