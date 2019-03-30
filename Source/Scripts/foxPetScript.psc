Scriptname foxPetScript extends ObjectReference
{Derivative of WEDogFollowerScript - now shares some common functionality with foxFollowFollowerAliasScript}

DialogueFollowerScript Property DialogueFollower Auto
GlobalVariable Property PlayerAnimalCount Auto
Message Property foxPetScriptGetNewAnimalMessage Auto
Message Property foxPetScriptHasAnimalMessage Auto
Message Property foxPetScriptUpdatingMessage Auto
Message Property foxPetScriptUpdateCompleteMessage Auto
ReferenceAlias Property AnimalNameAlias Auto
Actor Property PlayerRef Auto

float Property CombatWaitUpdateTime = 12.0 AutoReadOnly

function foxPetAddPet()
	Actor ThisActor = (Self as ObjectReference) as Actor

	;Lockpicking is tampered with in SetAnimal by vanilla scripts, so store it to be fixed later
	;It could already be 0 if pet was hired in previous versions - however, OnActivate should fix this up
	float tempAV = ThisActor.GetBaseActorValue("Lockpicking")

	DialogueFollower.SetAnimal(Self)
	ThisActor.SetPlayerTeammate(true, true)
	ThisActor.SetNoBleedoutRecovery(false)
	AnimalNameAlias.ForceRefTo(ThisActor)
	foxPetScriptGetNewAnimalMessage.Show()
	AnimalNameAlias.Clear()

	;Revert Lockpicking to whatever it was before SetAnimal tampered with it
	ThisActor.SetActorValue("Lockpicking", tempAV)
endFunction

function foxPetRemovePet(Actor ThatActor = None)
	if (!ThatActor)
		ThatActor = DialogueFollower.pAnimalAlias.GetReference() as Actor
	endif
	if (ThatActor != Self as ObjectReference)
		foxPetScriptHasAnimalMessage.Show()
	endif
	DialogueFollower.DismissAnimal()
	if (!ThatActor)
		return
	endif
	ThatActor.SetPlayerTeammate(false)
	ThatActor.SetActorValue("WaitingForPlayer", 0)
endFunction

event OnCombatStateChanged(Actor akTarget, int aeCombatState)
	;HACK Begin registering combat check to fix getting stuck in combat (bug in bleedouts for animals)
	;This should be bloat-friendly as it will never fire more than once at a time, even if OnActivate is called multiple times in this time frame
	if (aeCombatState == 1)
		RegisterForSingleUpdate(CombatWaitUpdateTime)
	endif
endEvent

event OnItemAdded(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akSourceContainer)
	Actor ThisActor = (Self as ObjectReference) as Actor

	;Immediately drop it and release ownership (don't let your pets manage your cupboard!)
	;Note: There is a vanilla bug where items taken by followers are sometimes marked as stolen
	;Debug.Trace("Dropping Base " + akBaseItem + " (" + aiItemCount + ")")
	ObjectReference DroppedItem = ThisActor.DropObject(akBaseItem, aiItemCount)
	if (DroppedItem && DroppedItem.GetActorOwner() == ThisActor.GetActorBase())
		DroppedItem.SetActorOwner(None)
	endif
endEvent

event OnActivate(ObjectReference akActivator)
	Actor ThisActor = (Self as ObjectReference) as Actor

	;Fix 0 lockpicking on old saves caused by vanilla SetAnimal (doesn't really matter, but should be done anyway)
	;Also for some reason PlayerRef is None on old saves...?
	;This should also fix very old pets that are still set as a teammate even though they were dismissed
	if (!PlayerRef || ThisActor.GetBaseActorValue("Lockpicking") == 0)
		foxPetScriptUpdatingMessage.Show()
		if (!PlayerRef)
			PlayerRef = Game.GetPlayer()
		endif
		if (ThisActor.IsPlayerTeammate())
			foxPetRemovePet(ThisActor)
		endif
		ThisActor.Disable()
		Utility.Wait(5.0)
		ThisActor.Enable()
		foxPetScriptUpdateCompleteMessage.Show()
	endif

	;Normally, we don't show a trade dialogue, so make sure we grab any stray arrows etc. that may be in pet's inventory
	;This should be unnecessary as we immediately drop any added item - but we'll still do this just in case it's a really old save etc.
	ThisActor.RemoveAllItems(PlayerRef, false, true)

	;If we're in dialoue somehow, do nothing - may allow better compatibility with follower frameworks, etc.
	;Also don't activate if we're doing favor - this breaks foxFollow, though we gracefully handle it there too
	if (ThisActor.IsInDialogueWithPlayer() || ThisActor.IsDoingFavor())
		return
	endif

	;Add ourself as a pet - unless there is an old pet, in which case we will just kick it and add ourself anyway
	;Checking IsPlayerTeammate is a little more reliable now that we've fixed old foxPets' teammate status
	if (!ThisActor.IsPlayerTeammate())
		if (PlayerAnimalCount.GetValueInt() > 0)
			foxPetRemovePet()
		endif
		foxPetAddPet()
	endif
endEvent

event OnUpdate()
	Actor ThisActor = (Self as ObjectReference) as Actor
	if (!ThisActor)
		return
	endif

	;Register for longer-interval update as long as we're in combat
	;Otherwise don't register for any update as we no longer need to
	if (ThisActor.IsInCombat())
		;If we've exited combat then actually stop combat - this fixes perma-bleedout issues
		if (!PlayerRef.IsInCombat())
			ThisActor.StopCombat()
			return
		endif

		RegisterForSingleUpdate(CombatWaitUpdateTime)
	endif
endEvent
