Scriptname foxDeathSummonVendorEffectScript extends ActiveMagicEffect
{Script to handle death vendor summoning}

foxDeathQuestScript Property DeathQuest Auto
ImageSpaceModifier Property IntroIMOD Auto
ImageSpaceModifier Property StaticIMOD Auto
ImageSpaceModifier Property OutroIMOD Auto
ShaderParticleGeometry Property StaticSPGD Auto
Spell Property FamiliarVisuals Auto

bool SummonVendor = false

float Property VendorFinalPlacementDist = 512.0 AutoReadOnly

event OnEffectStart(Actor akTarget, Actor akCaster)
	Actor VendorActor = DeathQuest.VendorAlias.GetReference() as Actor
	if (!akCaster || !VendorActor)
		Dispel()
		return
	endif

	;Init some stuff
	GoToState("EventsYesGood") ;Enable events
	SummonVendor = !DeathQuest.ActiveWeaknessEffect \
		&& !DeathQuest.IsProcessingDeath() \
		&& !akCaster.IsInCombat()

	;Apply our intro IMOD
	IntroIMOD.Apply()

	;Place vendor at a nice location in front of us
	if (SummonVendor)
		float aZ = akCaster.GetAngleZ()
		VendorActor.Disable(false)
		VendorActor.MoveTo(akCaster, VendorFinalPlacementDist * Math.Sin(aZ), VendorFinalPlacementDist * Math.Cos(aZ), 0.0, true)
		VendorActor.SetAngle(0.0, 0.0, aZ + 180.0)
		VendorActor.Enable(false)
		VendorActor.AddSpell(FamiliarVisuals)
	endif

	;Apply our static effects
	StaticIMOD.Apply()
	StaticSPGD.Apply(0.1)

	;Signal vendor to approach
	;May be more mysterious to just stand there? Dunno
	if (SummonVendor)
		DeathQuest.VendorAlias.SetMovementState(2)
		VendorActor.SetLookAt(akCaster)
	;Kick us out if nothing to do
	else
		Utility.Wait(2.0)
		Dispel()
	endif
endEvent

;Only process events if necessary
state EventsYesGood
	event OnEffectFinish(Actor akTarget, Actor akCaster)
		GoToState("") ;We're likely disabled by now, kill events

		;Apply our outro IMOD
		OutroIMOD.Apply()

		;I must go, my planet needs me
		Actor VendorActor = DeathQuest.VendorAlias.GetReference() as Actor
		if (SummonVendor && VendorActor)
			VendorActor.ClearLookAt()
			VendorActor.RemoveSpell(FamiliarVisuals)
			if (!DeathQuest.IsProcessingDeath())
				VendorActor.Disable(false)
				VendorActor.MoveToMyEditorLocation()
				VendorActor.Enable(false)
				DeathQuest.VendorAlias.SetMovementState(0)
			endif
		endif

		;Remove our static effects
		StaticIMOD.Remove()
		StaticSPGD.Remove(0.1)
	endEvent

	;Various events to kick us out of this state, since it's a free time dialation
	event OnHit(ObjectReference akAggressor, Form akSource, Projectile akProjectile, bool abPowerAttack, bool abSneakAttack, bool abBashAttack, bool abHitBlocked)
		Actor AggressorActor = akAggressor as Actor
		if (AggressorActor)
			Actor ThisActor = GetCasterActor()
			if (ThisActor && AggressorActor.IsHostileToActor(ThisActor))
				Dispel()
			endif
		endif
	endEvent
	event OnObjectEquipped(Form akBaseObject, ObjectReference akReference)
		Dispel()
	endEvent
	event OnSpellCast(Form akSpell)
		Actor ThisActor = GetCasterActor()
		if (!ThisActor)
			return
		endif

		int i = 4
		while (i > 0)
			i -= 1
			if (ThisActor.GetEquippedSpell(i) == akSpell)
				Dispel()
				return
			endif
		endwhile

		Shout SomeShout = ThisActor.GetEquippedShout()
		if (SomeShout)
			i = 3
			while (i > 0)
				i -= 1
				if (SomeShout.GetNthSpell(i) == akSpell)
					Dispel()
					return
				endif
			endwhile
		endif
	endEvent
endState
