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
