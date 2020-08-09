Scriptname foxDeathVendorChestAliasScript extends ReferenceAlias
{Manages stuff for our cool death vendor chest}

foxDeathQuestScript Property DeathQuest Auto
FormList Property TrackedQuestItems Auto

;Query possible quest items, tracking such items for safekeeping later
event OnItemAdded(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akSourceContainer)
	;Debug.Trace("foxDeath OnItemAdded " + akBaseItem + " (" + aiItemCount + ")\tReference Count: " + akItemReference.GetNumReferenceAliases())
	if (akItemReference && akItemReference.GetNumReferenceAliases() > 0)
		TrackedQuestItems.AddForm(akItemReference)
	endif

	if (akBaseItem == DeathQuest.DifficultyGoldItem \
	&& !DeathQuest.AllowSellback.GetValue() as bool)
		Self.GetReference().RemoveItem(akBaseItem, aiItemCount)
		Actor VendorActor = DeathQuest.VendorAlias.GetReference() as Actor
		if (VendorActor)
			VendorActor.RemoveItem(akBaseItem) ;This simply triggers a shop UI update
		endif
	endif
endEvent
event OnItemRemoved(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akDestContainer)
	if (TrackedQuestItems.HasForm(akItemReference))
		TrackedQuestItems.RemoveAddedForm(akItemReference)
	endif
endEvent

;Remove all non-quest items
function RemoveAllNonQuestItems(ObjectReference HoldingContainer)
	int i = TrackedQuestItems.GetSize()
	ObjectReference ThisRef = Self.GetReference()
	ObjectReference ItemRef
	GoToState("NoEvents")
	while (i > 0)
		i -= 1
		ItemRef = TrackedQuestItems.GetAt(i) as ObjectReference
		if (ItemRef && ItemRef.GetNumReferenceAliases() > 0)
			ThisRef.RemoveItem(ItemRef, akOtherContainer = HoldingContainer)
		endif
	endwhile
	TrackedQuestItems.Revert()
	ThisRef.RemoveAllItems()
	GoToState("")

	;Delicately place items back in container in a way that doesn't queue too many item events
	i = HoldingContainer.GetNumItems()
	while (i > 0)
		i -= 1
		HoldingContainer.RemoveItem(HoldingContainer.GetNthForm(i), 999999, akOtherContainer = ThisRef)
		Utility.Wait(0.01) ;Prevent barrage of item events
		if (i % 10 == 0)
			Utility.Wait(0.1) ;Spread out events a bit
		endif
	endwhile
	HoldingContainer.RemoveAllItems(ThisRef, true, true) ;Just in case
endFunction

state NoEvents
	event OnItemAdded(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akSourceContainer)
	endEvent
	event OnItemRemoved(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akDestContainer)
	endEvent
endState
