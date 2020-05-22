Scriptname foxDeathVendorAliasScript extends ReferenceAlias
{Manages stuff for our cool death vendor guy}

foxDeathQuestScript Property DeathQuest Auto
Spell Property InvisibilityAbility Auto

;Trade when activated (no more voice, aww)
event OnActivate(ObjectReference akActionRef)
	if (akActionRef == DeathQuest.PlayerAlias.GetReference())
		(Self.GetReference() as Actor).ShowBarterMenu()
	endif
endEvent

;Convenience function to set the requested movement state
;Latent if RequestedAIState is 1 - checks to make sure we're actually moving
function SetMovementState(int RequestedAIState)
	Actor ThisActor = Self.GetReference() as Actor
	DeathQuest.RequestedVendorAIState = RequestedAIState
	ThisActor.EvaluatePackage()

	if (RequestedAIState == 1)
		Actor PlayerActor = DeathQuest.PlayerAlias.GetReference() as Actor
		float StartingDist = ThisActor.GetDistance(PlayerActor)
		Utility.Wait(1.0)

		;Switch to alternate package if we're not moving
		if (Math.abs(ThisActor.GetDistance(PlayerActor) - StartingDist) < 2.0)
			DeathQuest.RequestedVendorAIState = 3
			ThisActor.EvaluatePackage()
		endif
	endif
endFunction

;Apply InvisibilityAbility depending on whether or not it's already applied
function SetInvisible(bool ShouldBeInvisible)
	Actor ThisActor = Self.GetReference() as Actor
	if (ShouldBeInvisible)
		if (!ThisActor.HasSpell(InvisibilityAbility))
			ThisActor.AddSpell(InvisibilityAbility)
		endif
	elseif (ThisActor.HasSpell(InvisibilityAbility))
		ThisActor.RemoveSpell(InvisibilityAbility)
	endif
endFunction

;Apply SpeedMult - CarryWeight must be adjusted for SpeedMult to apply
function ApplySpeedMult(float SpeedMult)
	Actor ThisActor = Self.GetReference() as Actor
	ThisActor.SetActorValue("SpeedMult", SpeedMult)
	ThisActor.ModActorValue("CarryWeight", 1.0)
	ThisActor.ModActorValue("CarryWeight", -1.0)
endFunction
