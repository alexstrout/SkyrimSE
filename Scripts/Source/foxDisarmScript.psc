Scriptname foxDisarmScript extends ActiveMagicEffect
{Cool script that replaces disarms with just unequipping stuff yo}

event OnEffectStart(Actor akTarget, Actor akCaster)
	if (!akTarget)
		;Debug.MessageBox("No target!\n" + akTarget)
		return
	endif

	;Unequip weapon in right hand...
	Form SomeForm = akTarget.GetEquippedWeapon()
	if (SomeForm)
		akTarget.UnequipItem(SomeForm)
	endif

	;... and left hand as well
	SomeForm = akTarget.GetEquippedWeapon(true)
	if (SomeForm)
		akTarget.UnequipItem(SomeForm)
	else
		;... and shield too! Why not
		SomeForm = akTarget.GetEquippedShield()
		if (SomeForm)
			akTarget.UnequipItem(SomeForm)
		endif
	endif
endEvent
