Scriptname foxDeathItemManagerAliasScript extends ReferenceAlias
{Additional alias assigned to player that handles all item management for player and followers}

Spell Property FollowerDetectSpell Auto

;ItemsToStrip containers must be same size
ObjectReference[] ItemsToStripContainer
Form[] ItemsToStripItem
int[] ItemsToStripCount
int ItemsToStripIndex = 0
bool ItemsToStripLock = false
int CurrentThreads = 0

;Initialization stuff
event OnInit()
	;These must be same size
	ItemsToStripContainer = new ObjectReference[128]
	ItemsToStripItem = new Form[128]
	ItemsToStripCount = new int[128]
endEvent

;Call EnumerateItemsToStrip across all followers
;Note this is latent until we think we're doing processing this
function EnumerateItemsToStripOnFollowers()
	CurrentThreads = 0
	Actor ThisActor = Self.GetReference() as Actor
	ThisActor.DoCombatSpellApply(FollowerDetectSpell, ThisActor)
	Utility.Wait(1.0)
	while (CurrentThreads > 0)
		Utility.Wait(1.0)
	endwhile
endFunction

;Enumerate all possible items to strip later via StripAllItems
;Slower, but UnequipAll w/ OnObjectUnequipped event might remove stuff on accident that we don't want removed
function EnumerateItemsToStrip(Actor akTarget)
	CurrentThreads += 1
	int i = akTarget.GetNumItems()
	Form akBaseItem
	while (i > 0 && ItemsToStripIndex < ItemsToStripContainer.Length)
		i -= 1
		akBaseItem = akTarget.GetNthForm(i)
		if ((akBaseItem as Ammo || akBaseItem as Armor || akBaseItem as Weapon) \
		&& akTarget.IsEquipped(akBaseItem) \
		&& akBaseItem.IsPlayable())
			QueueItemsToStrip(akTarget, akBaseItem, GetItemCountFor(akTarget, akBaseItem))
		endif
	endwhile
	CurrentThreads -= 1
endFunction
int function GetItemCountFor(ObjectReference akContainer, Form akBaseItem)
	if (akBaseItem as Ammo)
		if (akContainer)
			int count = akContainer.GetItemCount(akBaseItem)
			return Utility.RandomInt(count / 2, count)
		endif
		return 999999
	endif
	return 1
endFunction

;Queue an item to be stripped by StripAllItems
function QueueItemsToStrip(ObjectReference akContainer, Form akBaseItem, int aiItemCount)
	while (ItemsToStripLock)
		;Debug.Trace("foxDeath - QueueItemsToStrip WaitLock")
		Utility.Wait(0.1)
	endwhile
	ItemsToStripLock = true
	;Debug.Trace("foxDeath - QueueItemsToStrip " + akContainer + "\t" + akBaseItem + "(" + aiItemCount + ")")
	if (ItemsToStripIndex >= ItemsToStripContainer.Length)
		;Debug.Trace("foxDeath - QueueItemsToStrip too many items!?")
		ItemsToStripLock = false
		return
	endif
	ItemsToStripContainer[ItemsToStripIndex] = akContainer
	ItemsToStripItem[ItemsToStripIndex] = akBaseItem
	ItemsToStripCount[ItemsToStripIndex] = aiItemCount
	ItemsToStripIndex += 1
	ItemsToStripLock = false
endFunction

;Clear all items from all containers queued in ItemsToStrip
function ClearItemsToStrip()
	bool FullClear = false
	while (ItemsToStripLock)
		;On the off chance we're somehow jammed in a wait lock, forcefully clear this jam
		;Debug.Trace("foxDeath - ClearItemsToStrip WaitLock")
		ItemsToStripLock = false
		FullClear = true ;Just in case
		Utility.Wait(2.0)
	endwhile
	ItemsToStripLock = true
	if (FullClear)
		ItemsToStripIndex = ItemsToStripContainer.Length
	endif
	while (ItemsToStripIndex > 0)
		ItemsToStripIndex -= 1
		ItemsToStripContainer[ItemsToStripIndex] = None
		ItemsToStripItem[ItemsToStripIndex] = None
		ItemsToStripCount[ItemsToStripIndex] = 0
	endwhile
	ItemsToStripLock = false
endFunction

;Strip all items from all containers queued in ItemsToStrip
;This attempts to delicately do so in a way that doesn't queue too many item events
function StripAllItems(ObjectReference akDestContainer)
	while (ItemsToStripLock)
		;Debug.Trace("foxDeath - StripAllItems WaitLock")
		Utility.Wait(0.1)
	endwhile
	ItemsToStripLock = true
	;ItemsToStripIndex = ItemsToStripContainer.Length ;Not needed, ItemsToStripIndex will be inherently set to the number of items we want to strip
	while (ItemsToStripIndex > 0)
		ItemsToStripIndex -= 1
		if (ItemsToStripContainer[ItemsToStripIndex])
			;Debug.Trace("foxDeath - StripAllItems " + ItemsToStripContainer[ItemsToStripIndex] + "\t" + ItemsToStripItem[ItemsToStripIndex] + "(" + ItemsToStripCount[ItemsToStripIndex] + ")")
			ItemsToStripContainer[ItemsToStripIndex].RemoveItem( \
				ItemsToStripItem[ItemsToStripIndex], \
				ItemsToStripCount[ItemsToStripIndex], \
				true, \
				akDestContainer \
			)
			Utility.Wait(0.01) ;Prevent barrage of equip audio / item events
		endif
		ItemsToStripContainer[ItemsToStripIndex] = None
		ItemsToStripItem[ItemsToStripIndex] = None
		ItemsToStripCount[ItemsToStripIndex] = 0
		if (ItemsToStripIndex % 10 == 0)
			Utility.Wait(0.1) ;Spread out events a bit
		endif
	endwhile
	ItemsToStripLock = false
endFunction

;Transition to PreventDrop state
function SetNoPlayerEquipmentDrop(bool NoDrop)
	if (NoDrop)
		GoToState("PreventDrop")
	endif
endFunction

;Actual PreventDrop state
state PreventDrop
	;Prevent player from dropping equipment via simply picking it back up again
	event OnItemRemoved(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akDestContainer)
		;Debug.Trace("foxDeath - OnItemRemoved " + akBaseItem + "(" + aiItemCount + ")\t" + akItemReference + "\t" + akDestContainer)
		if (akItemReference)
			akItemReference.Activate(Self.GetReference())
		endif
	endEvent

	;Simply return to empty state if we were in this state
	function SetNoPlayerEquipmentDrop(bool NoDrop)
		if (!NoDrop)
			GoToState("")
		endif
	endFunction
endState
