Scriptname foxDeathWeaknessEffectScript extends ActiveMagicEffect
{Script to handle player post-defeat weakness / strength effects}
;This should really be "foxDeathDefeatEffectScript", but keeping for save / dependency compatibility

foxDeathQuestScript Property DeathQuest Auto
Message Property WeaknessEffectMessage Auto ;Should really be "EffectStartMessage"
int Property DefeatEffectType Auto

;Disable ability to summon vendor
event OnEffectStart(Actor akTarget, Actor akCaster)
	DeathQuest.SetActiveDefeatEffect(DefeatEffectType, Self)
	if (WeaknessEffectMessage)
		WeaknessEffectMessage.Show()
	endif
endEvent

;Restore ability to summon vendor
event OnEffectFinish(Actor akTarget, Actor akCaster)
	DeathQuest.SetActiveDefeatEffect(DefeatEffectType, None, Self)
endEvent
