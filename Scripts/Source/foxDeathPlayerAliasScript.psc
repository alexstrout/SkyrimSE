Scriptname foxDeathPlayerAliasScript extends ReferenceAlias
{Derpy script that handles bleedout and other cool stuff}

foxDeathQuestScript Property DeathQuest Auto
FormList Property PlayerTransformQuestList Auto

bool DeferredBump = false
float CurrentBleedoutModHealthAmt = 0.0
Spell[] SpellsToEquip
Shout ShoutToEquip = None
bool NoOnObjectEquipped = false
Quest CurrentTransformationQuest = None

float Property BleedoutUpdateTime = 20.0 AutoReadOnly
float Property BleedoutModHealthAmt = 100000.0 AutoReadOnly

;Initialization stuff
event OnInit()
	SpellsToEquip = new Spell[4]
endEvent

;Record our currently equipped spells to re-equip later (fixes spell weirdness on getting up from bleedout)
event OnObjectEquipped(Form akBaseObject, ObjectReference akReference)
	if (NoOnObjectEquipped)
		return
	endif
	Actor ThisActor = Self.GetReference() as Actor
	SpellsToEquip[0] = ThisActor.GetEquippedSpell(0) ;Keep as unrolled loop just in case, since this fires often
	SpellsToEquip[1] = ThisActor.GetEquippedSpell(1)
	SpellsToEquip[2] = ThisActor.GetEquippedSpell(2)
	SpellsToEquip[3] = ThisActor.GetEquippedSpell(3)
	ShoutToEquip = ThisActor.GetEquippedShout()
endEvent

;Player transformation handling (werewolf, vampire, etc.)
Quest function GetTransformationQuest()
	int i = PlayerTransformQuestList.GetSize()
	Quest SomeQuest
	while (i)
		i -= 1
		SomeQuest = PlayerTransformQuestList.GetAt(i) as Quest
		if (SomeQuest && SomeQuest.IsRunning())
			return SomeQuest
		endif
	endwhile
	return None
endFunction
function CancelTransformation(Actor ThisActor)
	CurrentTransformationQuest.SetCurrentStageID(1) ;This should finish up the transform if unfinished
	Utility.Wait(2.0) ;Wolf around for a few seconds
	CurrentTransformationQuest.SetCurrentStageID(100) ;This should transform us back
	CurrentTransformationQuest = None
endFunction

;Bleedout handling
event OnEnterBleedout()
	;If we don't exist or already have NoBleedoutRecovery set (e.g. some other death-handling event is happening?), bail immediately
	Actor ThisActor = Self.GetReference() as Actor
	if (!ThisActor || ThisActor.GetNoBleedoutRecovery() || CurrentBleedoutModHealthAmt)
		return
	endif

	;Player bleedout is weird, so SetNoBleedoutRecovery and just manually heal with an update later
	;This should be safe from interruption - no heals etc. can affect us in this state
	ThisActor.SetNoBleedoutRecovery(true)

	;Hide equipment UI etc. - should be safe to use here
	Game.SetBeastForm(true)

	;Actually, make sure potions etc. won't bring us out early
	AdjustBleedoutModHealthAmt(-BleedoutModHealthAmt)

	;Handle transformations here in a special branch - totally jank, but we'll hide it with fades at least
	CurrentTransformationQuest = GetTransformationQuest()
	if (CurrentTransformationQuest)
		DeathQuest.FadeManagerAlias.FadeOut()
		RegisterForSingleUpdate(BleedoutUpdateTime / 2.0) ;Ideally longer than ChangeFX times, to prevent weirdness
		;DeathQuest.RegisterForSingleUpdate(DeathQuest.FollowerFinderUpdateTime) ;No death handling for transformations
		return
	endif

	;Immediately queue our items for removal, in case we try to cheat by unequipping during bleedout
	;Also prevent us from dropping any items during this time
	DeathQuest.ItemManagerAlias.EnumerateItemsToStrip(ThisActor)
	DeathQuest.ItemManagerAlias.SetNoPlayerEquipmentDrop(true)

	;Bump if we're in a weird state
	if (!ThisActor.GetAnimationVariableBool("IsBleedingOut"))
		ThisActor.PushActorAway(ThisActor, 0.0)
		DeferredBump = true
	endif

	;Re-equip our previously equipped spells (fixes spell weirdness on getting up from bleedout)
	NoOnObjectEquipped = true
	int i = SpellsToEquip.Length
	while (i)
		i -= 1
		if (SpellsToEquip[i])
			ThisActor.EquipSpell(SpellsToEquip[i], i)
			Utility.Wait(0.01) ;Prevent barrage of equip audio
		endif
	endwhile
	if (ShoutToEquip)
		ThisActor.EquipShout(ShoutToEquip)
	endif
	NoOnObjectEquipped = false

	;And we're off! Register our update to ExitBleedout later
	;Also start checking for nearby friendlies via FollowerFinderQuest
	RegisterForSingleUpdate(BleedoutUpdateTime)
	DeathQuest.RegisterForSingleUpdate(DeathQuest.FollowerFinderUpdateTime)
endEvent
event OnUpdate()
	ExitBleedout()
endEvent
function ExitBleedout()
	;Abort our friendlies check if still running
	;There's a miniscule chance of a race condition here if these fire on the same frame
	;Worst case, we get up from bleedout while starting defeat scenario - no big deal
	DeathQuest.UnRegisterForUpdate()
	if (DeathQuest.FollowerFinderQuest.IsRunning())
		DeathQuest.FollowerFinderQuest.Stop()
	endif

	;If we're somehow invalid, try again later
	Actor ThisActor = Self.GetReference() as Actor
	if (!ThisActor)
		RegisterForSingleUpdate(2.0)
		return
	endif

	;If we're still bleeding out...
	if (ThisActor.IsBleedingOut())
		;Determine if we should bump later to fix ragdoll-bleedout issues
		if (!ThisActor.GetAnimationVariableBool("IsBleedingOut"))
			DeferredBump = true
		endif

		;Allow us to live / heal again :P
		;We will actually force this to a massive positive amount to ensure we get up
		if (CurrentBleedoutModHealthAmt < 0)
			AdjustBleedoutModHealthAmt(BleedoutModHealthAmt * 2)
		endif

		;Allow us to drop items again
		;Also clear all queued items for removal (cleans things up if nothing was taken)
		DeathQuest.ItemManagerAlias.SetNoPlayerEquipmentDrop(false)
		DeathQuest.ItemManagerAlias.ClearItemsToStrip()

		;Heal to (nearly) full and clear NoBleedoutRecovery
		ThisActor.RestoreActorValue("Health", ThisActor.GetBaseActorValue("Health") + BleedoutModHealthAmt)
		ThisActor.SetNoBleedoutRecovery(false)

		;Attempt to transition out of transformation
		if (CurrentTransformationQuest)
			CancelTransformation(ThisActor)
		endif

		;Restore equipment UI etc. - should be safe to use here
		Game.SetBeastForm(false)

		;We'll either be done bleeding out next run or need a retry...
		RegisterForSingleUpdate(0.1)
		return
	endif

	;If we're done bleeding out, clean up and bail
	;First, reset our mega-health back down to normal
	AdjustBleedoutModHealthAmt()

	;For some reason, bleedout recovery sometimes restores all our health
	;Though this doesn't matter as we now just heal to mostly full anyway
	;Either way, to work around this, damage our health back down to a low value
	;This has the nice side effect of proccing additional injuries from Wildcat etc.
	float adjHealth = ThisActor.GetActorValue("Health") - 10.0
	if (adjHealth > 0.0)
		ThisActor.DamageActorValue("Health", adjHealth)
	endif

	;Fix eyes stuck shut - we should never be mounted right now, but check just in case
	if (!ThisActor.IsOnMount())
		ThisActor.QueueNiNodeUpdate()
	endif

	;Fix broken ragdoll state!
	if (DeferredBump)
		DeferredBump = false
		Utility.Wait(1.0)
		ThisActor.PushActorAway(ThisActor, 0.0)
	endif

	;Fade back in from transformation handling if needed
	if (GetState() != "ProcessingDeath")
		DeathQuest.FadeManagerAlias.FadeIn()
	endif
endFunction
function AdjustBleedoutModHealthAmt(float AdjAmount = 0.0)
	Actor ThisActor = Self.GetReference() as Actor
	if (AdjAmount)
		ThisActor.ModActorValue("Health", AdjAmount)
		CurrentBleedoutModHealthAmt += AdjAmount
	else
		ThisActor.ModActorValue("Health", -CurrentBleedoutModHealthAmt)
		CurrentBleedoutModHealthAmt = 0
	endif
endFunction

;Try a teleport, attempting to account for cell changes - returns true if cell appears loaded (more or less)
;Latent - waits a second to test if cell is relatively loaded
bool function TryFullTeleport(Actor VendorActor, bool abMatchRotation = true)
	Actor ThisActor = Self.GetReference() as Actor
	if (ThisActor && VendorActor)
		VendorActor.Disable(false)
		ThisActor.MoveTo(VendorActor, 0.0, 0.0, 0.0, abMatchRotation)
		VendorActor.Enable(false)
	endif
	Utility.Wait(1.0)
	return ThisActor && VendorActor \
		&& ThisActor.GetParentCell() \
		&& ThisActor.GetParentCell().IsAttached() \
		&& ThisActor.Is3DLoaded() \
		&& VendorActor.Is3DLoaded()
endFunction

;Registered from DeathQuest, just forward the callback
event OnLostLOS(Actor akViewer, ObjectReference akTarget)
	DeathQuest.PlayerAliasOnLostLOS(akViewer, akTarget)
endEvent

;Special state for processing our death, so that these events are ignored during normal gameplay
;A sane prerequisite for this state is not having any control of our character (e.g. via FadeManager's fade)
;This used to handle equipment removal and mattered more, but still saves on unnecessary OnCellLoad calls I guess!
state ProcessingDeath
	;Needed for DeathQuest, just forward the callback
	event OnCellLoad()
		DeathQuest.PlayerAliasOnCellLoad()
	endEvent
endState
