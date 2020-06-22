Scriptname foxFollowWriteSpellTomeScript extends ActiveMagicEffect
{Cool script that writes Spell Tomes from Spells yo}

Spell Property ThisSpell Auto
FormList Property SpellTomeList Auto
Message Property SpendSoulMessage Auto
Message Property FailedToFindTomeMessage Auto
Message Property NoSoulsMessage Auto

Spell TargetSpell
Book TargetBook
Actor Caster

;================
;List Iterators
;================
;LVLIs must contain the same school (perk) of spell tome (unless they contain only other LVLIs or FLSTs) - will halt on first mismatch
;FLSTs may contain anything in any order - will always iterate the full list
;Intended to be only called from TestForm
;Return values:
;	0 = move to next item - nothing found
;	1 = (for LVLIs) stop processing current sublist - perk mismatch (wrong list)
;	1 = (for FLSTs) treat as 0, move to next item (this is also what parent lists of LVLIs see)
;	2 = stop processing all sublists - target found (yay!)
;	3 = stop processing all sublists - target changed or out of time (boo!)
int function TraverseLVLI(LeveledItem akList, Spell akSpell)
	int i = akList.GetNumForms()
	int ret
	while (i)
		i -= 1
		ret = TestForm(akList.GetNthForm(i), akSpell)
		if (ret)
			;Still return 0 to parent list so they don't halt processing
			if (ret == 1)
				return 0
			endif
			return ret
		endif
	endwhile
	return 0
endFunction
int function TraverseFLST(FormList akList, Spell akSpell)
	int i = akList.GetSize()
	int ret
	while (i)
		i -= 1
		ret = TestForm(akList.GetAt(i), akSpell)
		;Only care about "stop processing" codes for FLSTs
		if (ret > 1)
			return ret
		endif
	endwhile
	return 0
endFunction
int function TestForm(Form akForm, Spell akSpell)
	if (TargetSpell != akSpell)
		return 3
	endif
	if (akForm as LeveledItem)
		return TraverseLVLI(akForm as LeveledItem, akSpell)
	endif
	if (akForm as FormList)
		return TraverseFLST(akForm as FormList, akSpell)
	endif

	Book SomeBook = akForm as Book
	if (SomeBook)
		Spell SomeSpell = SomeBook.GetSpell()
		if (SomeSpell == akSpell)
			TargetSpell = None
			TargetBook = SomeBook
			return 2
		endif
		if (SomeSpell && SomeSpell.GetPerk() != akSpell.GetPerk())
			return 1
		endif
	endif
	return 0
endFunction

;Try to find a spell tome for this spell
;Our "master" function called from OnEffectStart and OnObjectEquipped
;Returns true if we processed a search (w/ TargetBook set appropriately if we found our target), false otherwise
bool function FindSpellTomeFor(Spell akSpell)
	if (!akSpell || akSpell == ThisSpell)
		return false
	endif

	;New thread - set our TargetSpell accordingly, which will signal our other threads to stop
	TargetSpell = akSpell
	if (!TestForm(SpellTomeList, akSpell) && TargetSpell == akSpell)
		;If we returned 0 here, we must have iterated through our entire SpellTomeList as our latest thread and not found anything - signal we're done processing
		TargetSpell = None
	endif
	return true
endFunction

;================
;Automatic State Management
;================
;Handle initial casting
event OnEffectStart(Actor akTarget, Actor akCaster)
	if (!akTarget || !akCaster)
		;Debug.MessageBox("No target or caster!\n" + akTarget + "\n" + akCaster)
		Dispel()
		return
	endif
	;Debug.StartStackProfiling()
	Caster = akCaster

	;We will wait at least this long before writing a tome and spending a soul
	;This allows us to switch spells after casting - e.g. to equip a BothHands spell
	RegisterForSingleUpdate(GetMagnitude())

	;Get our "target" spell (can be either hand, or even a shout! If it had a Spell Tome that taught it)
	;Goes Right > Left > Voice
	;This may change if we equip another spell via OnObjectEquipped after this
	int i = 0
	while (i < 3 && !FindSpellTomeFor(akCaster.GetEquippedSpell(i)))
		i += 1
	endwhile
	;Debug.StopStackProfiling()
endEvent

;Handle any spell changes after casting - e.g. to equip a BothHands spell
event OnObjectEquipped(Form akBaseObject, ObjectReference akReference)
	FindSpellTomeFor(akBaseObject as Spell)
endEvent

;Actually write our Spell Tome after GetMagnitude seconds, retrying every second if we're still processing our lists
event OnUpdate()
	;If we're approaching our maximum time, signal our search thread(s) to quit fussing
	if (GetTimeElapsed() > GetDuration() - 5.0)
		TargetSpell = None
	endif

	;Do the same if sheathed after casting
	if (!Caster.IsWeaponDrawn())
		TargetSpell = None
		TargetBook = None
	endif

	;Otherwise, if we're still processing, try again in a second
	if (TargetSpell)
		RegisterForSingleUpdate(1.0)
		return
	endif

	;Double-check TargetBook and DragonSouls just to be sure, as some time has passed
	if (!TargetBook)
		FailedToFindTomeMessage.Show()
	elseif (Caster.GetActorValue("DragonSouls") < 1)
		NoSoulsMessage.Show()
	else
		Caster.ModActorValue("DragonSouls", -1)
		Caster.AddItem(TargetBook)
		SpendSoulMessage.Show(Caster.GetActorValue("DragonSouls"))
	endif
	Dispel()
endEvent
