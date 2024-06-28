Scriptname foxPetScript extends ObjectReference
{Derivative of WEDogFollowerScript - now shares some common functionality with foxFollowFollowerAliasScript}

DialogueFollowerScript Property DialogueFollower Auto
Message Property foxPetScriptGetNewAnimalMessage Auto
Message Property foxPetScriptHasAnimalMessage Auto
Message Property foxPetScriptUpdatingMessage Auto
Message Property foxPetScriptUpdateCompleteMessage Auto
ReferenceAlias Property AnimalNameAlias Auto
Actor Property PlayerRef Auto

Spell Property RagdollDetectSpell Auto

;================
;Pet Management (Add / Remove)
;================
function foxPetAddPet()
	Actor ThisActor = (Self as ObjectReference) as Actor

	;Lockpicking is tampered with in SetAnimal by vanilla scripts, so store it to be fixed later
	;It could already be 0 if pet was hired in previous versions - however, OnActivate should fix this up
	float tempAV = ThisActor.GetBaseActorValue("Lockpicking")

	if (DialogueFollower.pPlayerAnimalCount.GetValue() as int > 0)
		DialogueFollower.SetFollower(Self)
	else
		DialogueFollower.SetAnimal(Self)
	endif
	ThisActor.SetPlayerTeammate(true, true)
	ThisActor.AddSpell(RagdollDetectSpell)

	;Show name-specific message
	AnimalNameAlias.ForceRefTo(ThisActor)
	foxPetScriptGetNewAnimalMessage.Show()
	AnimalNameAlias.Clear()

	;Revert Lockpicking to whatever it was before SetAnimal tampered with it
	ThisActor.SetActorValue("Lockpicking", tempAV)
endFunction

function foxPetRemovePet(Actor ThatActor = None)
	ObjectReference AnimalRef = DialogueFollower.pAnimalAlias.GetReference()
	ObjectReference FollowerRef = DialogueFollower.pFollowerAlias.GetReference()

	;Figure out dismissal if unspecified
	if (!ThatActor)
		if (FollowerRef == Self as ObjectReference)
			;We're a follower!
			ThatActor = FollowerRef as Actor
		else
			;We're an animal! Or don't care, and will dismiss existing animal
			if (AnimalRef != Self as ObjectReference)
				foxPetScriptHasAnimalMessage.Show()
			endif
			ThatActor = AnimalRef as Actor
		endif
	endif

	;Do follow-up dismissal stuff like foxPetDialDismiss
	if (ThatActor)
		if (ThatActor == FollowerRef)
			DialogueFollower.DismissFollower()
		elseif (ThatActor == AnimalRef)
			DialogueFollower.DismissAnimal()
		endif
		ThatActor.SetPlayerTeammate(false)
		ThatActor.SetActorValue("WaitingForPlayer", 0)
	endif
endFunction

;================
;Manual State Management
;================
event OnActivate(ObjectReference akActivator)
	Actor ThisActor = (Self as ObjectReference) as Actor

	;Fix 0 lockpicking on old saves caused by vanilla SetAnimal (doesn't really matter, but should be done anyway)
	;Also for some reason PlayerRef is None on old saves...?
	;This should also fix very old pets that are still set as a teammate even though they were dismissed
	if (!PlayerRef || ThisActor.GetBaseActorValue("Lockpicking") == 0 \
	|| (ThisActor.IsPlayerTeammate() && !ThisActor.HasSpell(RagdollDetectSpell)))
		foxPetScriptUpdatingMessage.Show()
		if (!PlayerRef)
			PlayerRef = Game.GetPlayer()
		endif
		foxPetRemovePet(ThisActor)
		ThisActor.Disable(false)
		Utility.Wait(2.0)
		ThisActor.Enable(false)
		foxPetScriptUpdateCompleteMessage.Show()
	endif

	;Normally, we don't show a trade dialogue, so make sure we grab any stray arrows etc. that may be in pet's inventory
	;This should be unnecessary as we immediately drop any added item - but we'll still do this just in case it's a really old save etc.
	;Actually, this is still useful for Ammo - we no longer immediately drop that, so we aren't littering the battlefield with objects as we get shot
	ThisActor.RemoveAllItems(PlayerRef, false, true)

	;If we're in dialoue somehow, do nothing - may allow better compatibility with follower frameworks, etc.
	;Also don't activate if we're doing favor - this breaks foxFollow, though we gracefully handle it there too
	if (ThisActor.IsInDialogueWithPlayer() || ThisActor.IsDoingFavor())
		return
	endif

	;Add ourself as a pet - unless there is an old pet, in which case we will just kick it and add ourself anyway
	;Checking IsPlayerTeammate is a little more reliable now that we've fixed old foxPets' teammate status
	if (!ThisActor.IsPlayerTeammate())
		if (DialogueFollower.pPlayerAnimalCount.GetValue() as int > 0 \
		&& DialogueFollower.pPlayerFollowerCount.GetValue() as int > 0)
			foxPetRemovePet()
		endif
		foxPetAddPet()
	endif
endEvent

;================
;Automatic State Management
;================
event OnEnterBleedout()
	Actor ThisActor = (Self as ObjectReference) as Actor

	;Flop over if no bleedout animation
	if (ThisActor.GetAnimationVariableBool("IsBleedingOut"))
		return
	endif
	ThisActor.PushActorAway(ThisActor, 0.0)

	;Fix sometimes getting stuck in bleedout
	Utility.Wait(1.0)
	ThisActor.PushActorAway(ThisActor, 0.0)
endEvent

event OnPackageChange(Package akOldPackage)
	Actor ThisActor = (Self as ObjectReference) as Actor

	;Ideally, we would remove RagdollDetectSpell when dismissed
	;However, there's no easy way to tell when that happens, so just do it on package change
	if (!ThisActor.IsPlayerTeammate())
		ThisActor.RemoveSpell(RagdollDetectSpell)
	endif
endEvent

;================
;Item Management
;================
event OnItemAdded(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akSourceContainer)
	Actor ThisActor = (Self as ObjectReference) as Actor

	;If we're incoming follower bow / arrow, delete that junk
	if (akBaseItem == DialogueFollower.FollowerHuntingBow \
	|| akBaseItem == DialogueFollower.FollowerIronArrow)
		ThisActor.RemoveItem(akBaseItem, aiItemCount)
		return
	endif

	;If we're an incoming projectile, do nothing (these will be transferred to player next OnActivate)
	if (akBaseItem as Ammo)
		return
	endif

	;Immediately drop it and release ownership (don't let your pets manage your cupboard!)
	;Note: There is a vanilla bug where items taken by followers are sometimes marked as stolen
	;Debug.Trace("Dropping Base " + akBaseItem + " (" + aiItemCount + ")")
	ObjectReference DroppedItem = ThisActor.DropObject(akBaseItem, aiItemCount)
	if (DroppedItem && DroppedItem.GetActorOwner() == ThisActor.GetActorBase())
		DroppedItem.SetActorOwner(None)
	endif
endEvent
