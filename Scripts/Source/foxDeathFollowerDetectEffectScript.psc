Scriptname foxDeathFollowerDetectEffectScript extends ActiveMagicEffect
{Script applied to detected followers, currently just for item management}

foxDeathQuestScript Property DeathQuest Auto

;Simply enumerate our items to strip, then dispel
event OnEffectStart(Actor akTarget, Actor akCaster)
	;Debug.Trace("foxDeathEffect OnEffectStart\t" + akTarget + "\t" + akTarget.GetBaseObject().GetName() + "\t" + akCaster + "\t" + akCaster.GetBaseObject().GetName())
	DeathQuest.ItemManagerAlias.EnumerateItemsToStrip(akTarget)
endEvent

;event OnEffectFinish(Actor akTarget, Actor akCaster)
;	;Debug.Trace("foxDeathEffect OnEffectFinish\t" + akTarget + "\t" + akTarget.GetBaseObject().GetName() + "\t" + akCaster + "\t" + akCaster.GetBaseObject().GetName())
;endEvent
