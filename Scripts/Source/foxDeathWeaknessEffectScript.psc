Scriptname foxDeathWeaknessEffectScript extends ActiveMagicEffect
{Script to handle player post-defeat weakness}

foxDeathQuestScript Property DeathQuest Auto
Message Property WeaknessEffectMessage Auto

;Disable ability to summon vendor
event OnEffectStart(Actor akTarget, Actor akCaster)
	DeathQuest.ActiveWeaknessEffect = Self
	WeaknessEffectMessage.Show()
endEvent

;Restore ability to summon vendor
event OnEffectFinish(Actor akTarget, Actor akCaster)
	DeathQuest.ActiveWeaknessEffect = None
endEvent
