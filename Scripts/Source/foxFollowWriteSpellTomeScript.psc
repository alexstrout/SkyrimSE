Scriptname foxFollowWriteSpellTomeScript extends ActiveMagicEffect
{Cool script that writes Spell Tomes from Spells yo}

Spell Property ThisSpell Auto
FormList Property SpellTomeList Auto
Message Property SpendSoulMessage Auto

event OnEffectStart(Actor akTarget, Actor akCaster)
	if (!akTarget || !akCaster)
		;Debug.MessageBox("No target or caster!\n" + akTarget + "\n" + akCaster)
		return
	endif
	;This should never happen, as we check caster's DragonSouls in the CK MagicEffect
	if (akCaster.GetActorValue("DragonSouls") < 1)
		;Debug.MessageBox("Not enough DragonSouls!\n" + akCaster.GetBaseActorValue("DragonSouls"))
		return
	endif

	Spell SomeSpell = akTarget.GetEquippedSpell(0)
	if (!SomeSpell || SomeSpell == ThisSpell)
		SomeSpell = akTarget.GetEquippedSpell(1)
	endif
	if (!SomeSpell || SomeSpell == ThisSpell)
		SomeSpell = akTarget.GetEquippedSpell(2)
	endif

	Book SomeBook
	int i = SpellTomeList.GetSize()
	while (i)
		i -= 1
		SomeBook = SpellTomeList.GetAt(i) as Book
		if (SomeBook && SomeBook.GetSpell() == SomeSpell)
			akCaster.AddItem(SomeBook)
			akCaster.ModActorValue("DragonSouls", -1)
			SpendSoulMessage.Show(akCaster.GetActorValue("DragonSouls"))
			return
		endif
	endwhile
endEvent
