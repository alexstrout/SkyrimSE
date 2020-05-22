Scriptname foxDeathCalmEffectScript extends ActiveMagicEffect
{Handle events for effect applied to all actors near player to temporarily suspend combat}

;Register for dispel event, or just dispel after some time
event OnEffectStart(Actor akTarget, Actor akCaster)
	;Debug.Trace("foxDeathEffect OnEffectStart\t" + akTarget + "\t" + akTarget.GetBaseObject().GetName() + "\t" + akCaster + "\t" + akCaster.GetBaseObject().GetName())
	GoToState("HandleEvents")
	RegisterForModEvent("foxDeathDispelCalmEffect", "foxDeathOnDispelCalmEffect")
	;RegisterForSingleUpdate(12.0) ;Simply set via Duration
endEvent
event foxDeathOnDispelCalmEffect(string eventName, string strArg, float numArg, Form sender)
endEvent

event OnEffectFinish(Actor akTarget, Actor akCaster)
	;Debug.Trace("foxDeathEffect OnEffectFinish\t" + akTarget + "\t" + akTarget.GetBaseObject().GetName() + "\t" + akCaster + "\t" + akCaster.GetBaseObject().GetName())
	GoToState("")
endEvent

state HandleEvents
	;event OnUpdate()
	;	;Debug.Trace("foxDeathEffect OnUpdate\t" + GetTargetActor() + "\t" + GetTargetActor().GetBaseObject().GetName())
	;	Dispel()
	;endEvent
	event foxDeathOnDispelCalmEffect(string eventName, string strArg, float numArg, Form sender)
		;Debug.Trace("foxDeathEffect foxDeathOnDispelCalmEffect\t" + GetTargetActor() + "\t" + GetTargetActor().GetBaseObject().GetName())
		Dispel()
	endEvent
endState
