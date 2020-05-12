Scriptname foxDeathSummonVendorEffectScript extends ActiveMagicEffect
{Script to handle death vendor summoning}

foxDeathQuestScript Property DeathQuest Auto
ImageSpaceModifier Property IntroIMOD Auto
ImageSpaceModifier Property StaticIMOD Auto
ImageSpaceModifier Property OutroIMOD Auto
ShaderParticleGeometry Property StaticSPGD Auto

bool NoDispelEvent = true

float Property VendorFinalPlacementDist = 512.0 AutoReadOnly

event OnEffectStart(Actor akTarget, Actor akCaster)
	Actor VendorActor = DeathQuest.VendorAlias.GetReference() as Actor
	if (!akCaster || !VendorActor)
		Dispel()
		return
	endif

	;Apply our intro IMOD
	NoDispelEvent = false
	IntroIMOD.Apply()

	;Place vendor at a nice location in front of us
	float aZ = akCaster.GetAngleZ()
	VendorActor.Disable(false)
	VendorActor.MoveTo(akCaster, VendorFinalPlacementDist * Math.Sin(aZ), VendorFinalPlacementDist * Math.Cos(aZ), 0.0, true)
	VendorActor.SetAngle(0.0, 0.0, aZ + 180.0)
	VendorActor.Enable(false)

	;Apply our static effects
	StaticIMOD.Apply()
	StaticSPGD.Apply(0.1)

	;Signal vendor to approach
	;May be more mysterious to just stand there? Dunno
	DeathQuest.RequestedVendorAIState = 2
	VendorActor.EvaluatePackage()
	VendorActor.SetLookAt(akCaster)

	;Kick us out if we started this spell in combat
	if (akCaster.IsInCombat())
		Utility.Wait(2.0)
		Dispel()
	endif
endEvent

event OnEffectFinish(Actor akTarget, Actor akCaster)
	Actor VendorActor = DeathQuest.VendorAlias.GetReference() as Actor
	if (NoDispelEvent || !VendorActor)
		return
	endif

	;Apply our outro IMOD
	OutroIMOD.Apply()

	;I must go, my planet needs me
	VendorActor.ClearLookAt()
	VendorActor.Disable(false)
	VendorActor.MoveToMyEditorLocation()
	VendorActor.Enable(false)
	DeathQuest.RequestedVendorAIState = 0
	VendorActor.EvaluatePackage()

	;Remove our static effects
	StaticIMOD.Remove()
	StaticSPGD.Remove(0.1)
endEvent

;Various events to kick us out of this state, since it's a free time dialation
event OnHit(ObjectReference akAggressor, Form akSource, Projectile akProjectile, bool abPowerAttack, bool abSneakAttack, bool abBashAttack, bool abHitBlocked)
	Actor AggressorActor = akAggressor as Actor
	if (AggressorActor)
		Actor ThisActor = GetCasterActor()
		if (ThisActor && AggressorActor.IsHostileToActor(GetCasterActor()))
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
