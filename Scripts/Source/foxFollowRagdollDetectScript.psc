Scriptname foxFollowRagdollDetectScript extends ActiveMagicEffect
{Handle detection for ragdoll state}

;Fix an obscure issue where our anim state becomes bugged when detached while ragdolled
;This became not-so-obscure when using ragdolls for bleedout!
event OnCellDetach()
	Actor ThisActor = Self.GetTargetActor() as Actor
	if (ThisActor)
		ThisActor.PushActorAway(ThisActor, 0.0)
		Utility.Wait(1.0)
		ThisActor.PushActorAway(ThisActor, 0.0)
	endif
endEvent
