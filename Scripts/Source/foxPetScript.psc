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

int Property foxPetVer Auto
int Property foxPetScriptVer = 1 AutoReadOnly

;================
;Pet Management (Add / Remove)
;================
function foxPetAddPet()
	Actor ThisActor = (Self as ObjectReference) as Actor

	;Figure out slot to use
	if (DialogueFollower.pPlayerAnimalCount.GetValue() as int > 0)
		if (DialogueFollower.pPlayerFollowerCount.GetValue() as int > 0)
			return ;No room. Oh no!
		endif
		DialogueFollower.SetFollower(Self)
	else
		;Allow lockpicking on vanilla SetAnimal calls
		float tempAV = ThisActor.GetBaseActorValue("Lockpicking")
		DialogueFollower.SetAnimal(Self)
		ThisActor.SetActorValue("Lockpicking", tempAV)
	endif
	ThisActor.SetPlayerTeammate(true, true)

	;Show name-specific message
	AnimalNameAlias.ForceRefTo(ThisActor)
	foxPetScriptGetNewAnimalMessage.Show()
	AnimalNameAlias.Clear()
endFunction

function foxPetRemovePet(Actor ThatActor = None)
	ObjectReference AnimalRef = DialogueFollower.pAnimalAlias.GetReference()
	ObjectReference FollowerRef = DialogueFollower.pFollowerAlias.GetReference()

	;Figure out dismissal if unspecified
	if (!ThatActor)
		if (FollowerRef == Self as ObjectReference)
			;We're a follower!
			ThatActor = FollowerRef as Actor
			DialogueFollower.DismissFollower()
		else
			;We're an animal! Or don't care, and will dismiss existing animal
			if (AnimalRef != Self as ObjectReference)
				foxPetScriptHasAnimalMessage.Show()
			endif
			ThatActor = AnimalRef as Actor
			DialogueFollower.DismissAnimal()
		endif
	endif

	;Do follow-up dismissal stuff like foxPetDialDismiss
	if (ThatActor)
		ThatActor.SetPlayerTeammate(false)
		ThatActor.SetActorValue("WaitingForPlayer", 0)
	endif
endFunction

;================
;Manual State Management
;================
event OnActivate(ObjectReference akActivator)
	Actor ThisActor = (Self as ObjectReference) as Actor

	;Fix potentially bad stuff on old saves - but only check once
	if (foxPetVer < foxPetScriptVer)
		foxPetVer = foxPetScriptVer

		;For now, just a generic catch-all of old stuff
		if (!PlayerRef || ThisActor.GetBaseActorValue("Lockpicking") == 0)
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
	endif

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

	;Ideally, we would add/remove RagdollDetectSpell when added/dismissed
	;However, there's no easy way to tell when that happens, so just do it on package change
	Utility.Wait(1.0)
	if (ThisActor.IsPlayerTeammate())
		ThisActor.AddSpell(RagdollDetectSpell)
	else
		ThisActor.RemoveSpell(RagdollDetectSpell)
	endif
endEvent

;================
;Item Management
;================
event OnItemAdded(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akSourceContainer)
	Actor ThisActor = (Self as ObjectReference) as Actor

	;If from player, do nothing
	if (akSourceContainer == PlayerRef)
		return
	endif

	;If we're an incoming follower bow / arrow, delete that junk
	if (akBaseItem == DialogueFollower.FollowerHuntingBow \
	|| akBaseItem == DialogueFollower.FollowerIronArrow)
		ThisActor.RemoveItem(akBaseItem, aiItemCount)
		return
	endif

	;If doing favor, immediately drop and release ownership (don't let your pets manage your cupboard!)
	;Note: There is a vanilla bug where items taken by followers are sometimes marked as stolen
	;Debug.Trace("Dropping Base " + akBaseItem + " (" + aiItemCount + ")")
	if (akSourceContainer && ThisActor.IsDoingFavor())
		ObjectReference DroppedItem = ThisActor.DropObject(akBaseItem, aiItemCount)
		if (DroppedItem && DroppedItem.GetActorOwner() == ThisActor.GetActorBase())
			DroppedItem.SetActorOwner(None)
		endif
	endif
endEvent
