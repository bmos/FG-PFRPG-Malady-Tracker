-- 
-- Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

function onInit()
	update()
end

--	This function takes the Save DC related information and combines them into a single string that can be displayed once the window is locked.
function generateSaveString()
	local sSave = ''
	
	if savedc.getValue() and savedc.getValue() ~= 0 and savetype.getValue() and savetype.getValue() ~= '' then
		sSave = 'DC ' .. savedc.getValue() .. ' '
	end
	if savetype.getValue() and savetype.getValue() ~= '' then
		sSave = sSave .. savetype.getValue()
	else
		sSave = 'none'
	end
	
	save_string.setValue(sSave)
end

---	This function hides extra fields once the malady type is set.
function switchType()
	local sType = string.lower(type.getValue())
	if sType == 'poison' then
		disease_effect.setVisible(false)
		poison_effect_primary_label.setVisible(true)
		poison_effect_primary.setVisible(true)
		poison_effect_secondary_label.setVisible(true)
		poison_effect_secondary.setVisible(true)
	elseif sType == 'disease' then
		disease_effect.setVisible(true)
		poison_effect_primary_label.setVisible(false)
		poison_effect_primary.setVisible(false)
		poison_effect_secondary_label.setVisible(false)
		poison_effect_secondary.setVisible(false)
	else
		disease_effect.setVisible(true)
		poison_effect_primary_label.setVisible(true)
		poison_effect_primary.setVisible(true)
		poison_effect_secondary_label.setVisible(true)
		poison_effect_secondary.setVisible(true)
	end
end

--	This function sets the visibility and editability of various fields on the malady sheet when it is unlocked.
local function ifLocked()
	local sSubtype = ''
	if subtype.getValue() and subtype.getValue() ~= '' then
		sSubtype = ' (' .. subtype.getValue() .. ')'
	end

	generateSaveString()

	save_string.setVisible(true)
	savetype.setVisible(false)
	savedc_label.setVisible(false)
	savedc.setVisible(false)
	saveroll.setVisible(true)

	type_biglabel.setValue('[' .. type.getValue() .. sSubtype .. ']')
	type_biglabel.setVisible(true)
	type.setVisible(false)
	type_label.setVisible(false)
	subtype.setVisible(false)
	subtype_label.setVisible(false)
end

--	This function sets the visibility and editability of various fields on the malady sheet when it is locked.
local function ifUnlocked()
	save_string.setVisible(false)
	savetype.setVisible(true)
	savedc_label.setVisible(true)
	savedc.setVisible(true)
	saveroll.setVisible(false)

	type_biglabel.setVisible(false)
	type.setVisible(true)
	type_label.setVisible(true)
	subtype.setVisible(true)
	subtype_label.setVisible(true)

end

function update()
	local bReadOnly = WindowManager.getReadOnlyState(getDatabaseNode())
	if bReadOnly then
		ifLocked()
	else
		ifUnlocked()
	end

	onset.update(bReadOnly)
	frequency.update(bReadOnly)
	cure.update(bReadOnly)
	disease_effect.update(bReadOnly)
	poison_effect_primary.update(bReadOnly)
	poison_effect_secondary.update(bReadOnly)
	description.update(bReadOnly)

	switchType()
end