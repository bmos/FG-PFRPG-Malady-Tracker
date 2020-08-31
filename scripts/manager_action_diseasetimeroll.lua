---
--- Initialization
---

function onInit()
	GameSystem.actions["diseasetimeroll"] = { bUseModStack = false };
	ActionsManager.registerResultHandler("diseasetimeroll", onRoll);
end

local function getRoll(rActor, sDieCount, sDie, sDesc)
	local rRoll = {};
	
	rRoll.sType = "diseasetimeroll";
	rRoll.aDice = { sDie };
	rRoll.nMod = 0;
	rRoll.sDesc = sDesc;
	
	return rRoll;
end

-- Start the action process
function performRoll(draginfo, rActor, sDieCount, sDie, sDesc)
	local rRoll = getRoll(rActor, sDieCount, sDie, sDesc);
	
	ActionsManager.performAction(draginfo, rActor, rRoll);
end

function onRoll(rSource, rTarget, rRoll)
	local rMessage = ActionsManager.createActionMessage(rSource, rRoll);
	Comm.deliverChatMessage(rMessage);
end