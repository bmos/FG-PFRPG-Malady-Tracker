-- 
-- Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--
OOB_MSGTYPE_APPLYDISEASESAVE = "applysave";

function onInit()
--	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_APPLYDISEASESAVE, handleApplySave);

	GameSystem.actions['disease'] = { bUseModStack = true }
	ActionsManager.registerModHandler('disease', modSave)
	ActionsManager.registerResultHandler('disease', onRoll)
end

function handleApplySave(msgOOB)
	local rSource = ActorManager.getActor(msgOOB.sSourceType, msgOOB.sSourceNode);
	local rOrigin = ActorManager.getActor(msgOOB.sTargetType, msgOOB.sTargetNode);
	
	local rAction = {};
	rAction.bSecret = (tonumber(msgOOB.nSecret) == 1);
	rAction.sDesc = msgOOB.sDesc;
	rAction.nTotal = tonumber(msgOOB.nTotal) or 0;
	rAction.sSaveDesc = msgOOB.sSaveDesc;
	rAction.nTarget = tonumber(msgOOB.nTarget) or 0;
	rAction.bRemoveOnMiss = (tonumber(msgOOB.nRemoveOnMiss) == 1);
	rAction.sSaveResult = msgOOB.sSaveResult;
	
	applySave(rSource, rOrigin, rAction);
end

function notifyApplySave(rSource, rRoll)
	local msgOOB = {};
	msgOOB.type = OOB_MSGTYPE_APPLYDISEASESAVE;
	
	if rRoll.bTower then
		msgOOB.nSecret = 1;
	else
		msgOOB.nSecret = 0;
	end
	msgOOB.sDesc = rRoll.sDesc;
	msgOOB.nTotal = ActionsManager.total(rRoll);
	msgOOB.sSaveDesc = rRoll.sSaveDesc;
	msgOOB.nTarget = rRoll.nTarget;
	msgOOB.sSaveResult = rRoll.sSaveResult;
	if rRoll.bRemoveOnMiss then msgOOB.nRemoveOnMiss = 1; end

	local sSourceType, sSourceNode = ActorManager.getTypeAndNodeName(rSource);
	msgOOB.sSourceType = sSourceType;
	msgOOB.sSourceNode = sSourceNode;

	if rRoll.sSource ~= "" then
		msgOOB.sTargetType = "ct";
		msgOOB.sTargetNode = rRoll.sSource;
	else
		msgOOB.sTargetType = "";
		msgOOB.sTargetNode = "";
	end
	
	local nodeDiseaseRoll = DB.findNode(rRoll.nodeDisease)
	if rRoll.sSaveResult:match('failure') and DB.getValue(nodeDiseaseRoll, 'isconsecutive', 1) == 1 then
		DB.setValue(nodeDiseaseRoll, 'savecount_consec', 'number', 0)
	elseif rRoll.sSaveResult:match('success') then
		DB.setValue(nodeDiseaseRoll, 'savecount_consec', 'number', DB.getValue(nodeDiseaseRoll, 'savecount_consec', 0) + 1)
	end
	
	Comm.deliverOOBMessage(msgOOB, "");
end

local function getRoll(rActor, nodeDisease)
	local rRoll = {}
	rRoll.sType = 'disease'
	rRoll.aDice = { 'd20' }
	rRoll.nMod = 0

	-- Look up actor specific information
	local sAbility = nil
	local sActorType, nodeActor = ActorManager.getTypeAndNode(rActor)
	local sSave = DB.getValue(nodeDisease, 'savetype')
	if nodeActor then
		if sActorType == 'pc' then
			rRoll.nMod = DB.getValue(nodeActor, 'saves.' .. sSave .. '.total', 0)
			sAbility = DB.getValue(nodeActor, 'saves.' .. sSave .. '.ability', '')
		else
			rRoll.nMod = DB.getValue(nodeActor, sSave .. 'save', 0)
		end
	end

	local sDiseaseType = string.lower(DB.getValue(nodeDisease, 'type'))
	if sDiseaseType ~= '' then
		rRoll.tags = sDiseaseType .. 'tracker'
	end
	
	rRoll.sDesc = '[DISEASE] ' .. StringManager.capitalize(sSave)
	if sDiseaseType == 'poison' then rRoll.sDesc = '[POISON] ' .. StringManager.capitalize(sSave) end
	if sAbility and sAbility ~= '' then
		if (sSave == 'fortitude' and sAbility ~= 'constitution') or
				(sSave == 'reflex' and sAbility ~= 'dexterity') or
				(sSave == 'will' and sAbility ~= 'wisdom') then
			local sAbilityEffect = DataCommon.ability_ltos[sAbility]
			if sAbilityEffect then
				rRoll.sDesc = rRoll.sDesc .. ' [MOD:' .. sAbilityEffect .. ']'
			end
		end
	end
	
	local nDC = DB.getValue(nodeDisease, 'savedc')
	if nDC == 0 then nDC = nil end
	rRoll.nTarget = nDC
	
	return rRoll
end

local function modSave(rSource, rTarget, rRoll)
	local aAddDesc = {}
	local aAddDice = {}
	local nAddMod = 0
	
	-- Determine save type
	local sSave = nil
	local sSaveMatch = rRoll.sDesc:match('%[DISEASE%] ([^[]+)')
	if not sSaveMatch then sSaveMatch = rRoll.sDesc:match('%[POISON%] ([^[]+)') end
	if sSaveMatch then
		sSave = StringManager.trim(sSaveMatch):lower()
	end
	
	if rSource then
		local bEffects = false

		-- Determine ability used
		local sActionStat = nil
		local sModStat = string.match(rRoll.sDesc, '%[MOD:(%w+)%]')
		if sModStat then
			sActionStat = DataCommon.ability_stol[sModStat]
		end
		if not sActionStat then
			if sSave == 'fortitude' then
				sActionStat = 'constitution'
			elseif sSave == 'reflex' then
				sActionStat = 'dexterity'
			elseif sSave == 'will' then
				sActionStat = 'wisdom'
			end
		end
		
		-- Build save filter
		local aSaveFilter = {}
		if sSave then
			table.insert(aSaveFilter, sSave)
		end
		
		-- Determine flatfooted status
		local bFlatfooted = false
		if not rRoll.bVsSave and ModifierStack.getModifierKey('ATT_FF') then
			bFlatfooted = true
		elseif EffectManager35E.hasEffect(rSource, 'Flat-footed') or EffectManager35E.hasEffect(rSource, 'Flatfooted') then
			bFlatfooted = true
		end

		-- Get effect modifiers
		local rSaveSource = nil
		if rRoll.sSource then
			rSaveSource = ActorManager.getActor('ct', rRoll.sSource)
		end
		local aExistingBonusByType = {}
		local aSaveEffects = EffectManager35E.getEffectsByType(rSource, 'SAVE', aSaveFilter, rSaveSource, false)
		for _,v in pairs(aSaveEffects) do
			-- Determine bonus type if any
			local sBonusType = nil
			for _,v2 in pairs(v.remainder) do
				if StringManager.contains(DataCommon.bonustypes, v2) then
					sBonusType = v2
					break
				end
			end
			-- Dodge bonuses stack (by rules)
			if sBonusType then
				if sBonusType == 'dodge' then
					if not bFlatfooted then
						nAddMod = nAddMod + v.mod
						bEffects = true
					end
				elseif aExistingBonusByType[sBonusType] then
					if v.mod < 0 then
						nAddMod = nAddMod + v.mod
					elseif v.mod > aExistingBonusByType[sBonusType] then
						nAddMod = nAddMod + v.mod - aExistingBonusByType[sBonusType]
						aExistingBonusByType[sBonusType] = v.mod
					end
					bEffects = true
				else
					nAddMod = nAddMod + v.mod
					aExistingBonusByType[sBonusType] = v.mod
					bEffects = true
				end
			else
				nAddMod = nAddMod + v.mod
				bEffects = true
			end
		end

		-- Get condition modifiers
		if EffectManager35E.hasEffectCondition(rSource, 'Frightened') or 
				EffectManager35E.hasEffectCondition(rSource, 'Panicked') or
				EffectManager35E.hasEffectCondition(rSource, 'Shaken') then
			nAddMod = nAddMod - 2
			bEffects = true
		end
		if EffectManager35E.hasEffectCondition(rSource, 'Sickened') then
			nAddMod = nAddMod - 2
			bEffects = true
		end
		if sSave == 'reflex' then
			if EffectManager35E.hasEffectCondition(rSource, 'Slowed') then
				nAddMod = nAddMod - 1
				bEffects = true
			end
		end

		-- Get ability modifiers
		local nBonusStat, nBonusEffects = ActorManager2.getAbilityEffectsBonus(rSource, sActionStat)
		if nBonusEffects > 0 then
			bEffects = true
			nAddMod = nAddMod + nBonusStat
		end
		
		-- Get negative levels
		local nNegLevelMod, nNegLevelCount = EffectManager35E.getEffectsBonus(rSource, {'NLVL'}, true)
		if nNegLevelCount > 0 then
			bEffects = true
			nAddMod = nAddMod - nNegLevelMod
		end

		-- If flatfooted, then add a note
		if bFlatfooted then
			table.insert(aAddDesc, '[FF]')
		end
		
		-- If effects, then add them
		if bEffects then
			local sEffects = ''
			local sMod = StringManager.convertDiceToString(aAddDice, nAddMod, true)
			if sMod ~= '' then
				sEffects = '[' .. Interface.getString('effects_tag') .. ' ' .. sMod .. ']'
			else
				sEffects = '[' .. Interface.getString('effects_tag') .. ']'
			end
			table.insert(aAddDesc, sEffects)
		end
	end
	
	if #aAddDesc > 0 then
		rRoll.sDesc = rRoll.sDesc .. ' ' .. table.concat(aAddDesc, ' ')
	end
	for _,vDie in ipairs(aAddDice) do
		if vDie:sub(1,1) == '-' then
			table.insert(rRoll.aDice, '-p' .. vDie:sub(3))
		else
			table.insert(rRoll.aDice, 'p' .. vDie:sub(2))
		end
	end
	rRoll.nMod = rRoll.nMod + nAddMod
end

function performRoll(draginfo, rActor, nodeDisease)
	local rRoll = getRoll(rActor, nodeDisease)

	local sDiseaseName = DB.getValue(nodeDisease, 'name')
	if sDiseaseName and sDiseaseName ~= '' then
		rRoll.sDesc = rRoll.sDesc .. ' (against ' .. sDiseaseName .. ')'
	end
	
	rRoll.nodeDisease = nodeDisease.getPath()
	
	ActionsManager.performAction(draginfo, rActor, rRoll)
end

function onRoll(rSource, rTarget, rRoll)
	local rMessage = ActionsManager.createActionMessage(rSource, rRoll)
	Comm.deliverChatMessage(rMessage)
		
	if rRoll.nTarget then
		rRoll.nTotal = ActionsManager.total(rRoll)
		if #(rRoll.aDice) > 0 then
			local nFirstDie = rRoll.aDice[1].result or 0
			if nFirstDie == 20 then
				rRoll.sSaveResult = 'autosuccess'
			elseif nFirstDie == 1 then
				rRoll.sSaveResult = 'autofailure'
			end
		end
		if (rRoll.sSaveResult or '') == '' then
			local nTarget = tonumber(rRoll.nTarget) or 0
			if rRoll.nTotal >= nTarget then
				rRoll.sSaveResult = 'success'
			else
				rRoll.sSaveResult = 'failure'
			end
		end
		notifyApplySave(rSource, rRoll)
	end
end