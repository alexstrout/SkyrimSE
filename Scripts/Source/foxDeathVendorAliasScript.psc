Scriptname foxDeathVendorAliasScript extends ReferenceAlias
{Manages state for our cool death vendor guy}

Spell Property InvisibilityAbility Auto

;Apply SpeedMult - CarryWeight must be adjusted for SpeedMult to apply
function ApplySpeedMult(float SpeedMult)
	Actor ThisActor = Self.GetReference() as Actor
	ThisActor.SetActorValue("SpeedMult", SpeedMult)
	ThisActor.ModActorValue("CarryWeight", 1.0)
	ThisActor.ModActorValue("CarryWeight", -1.0)
endFunction
