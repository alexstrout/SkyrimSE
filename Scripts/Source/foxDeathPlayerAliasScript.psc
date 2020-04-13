Scriptname foxDeathPlayerAliasScript extends ReferenceAlias
{Derpy script that handles bleedout and other cool stuff}

Quest Property FollowerFinderQuest Auto
ReferenceAlias Property VendorAlias Auto
ReferenceAlias Property VendorChestAlias Auto

float HealthToHealTo = 0.0
bool DeferredBump = false

bool ProcessingDeath = false
bool ShouldBeFaded = false
bool WaitingForCellLoad = false

float Property FollowerFinderUpdateGameTime = 0.05 AutoReadOnly
float Property FadeTime = 2.0 AutoReadOnly
float Property VendorFinalPlacementDist = 512.0 AutoReadOnly

;Bleedout handling
event OnEnterBleedout()
	;If we don't exist or already have NoBleedoutRecovery set (e.g. some other death-handling event is happening?), bail immediately
	Actor ThisActor = Self.GetReference() as Actor
	if (!ThisActor || ThisActor.GetNoBleedoutRecovery())
		return
	endif

	;Player bleedout is weird, so SetNoBleedoutRecovery and just manually heal after some time
	;This should be safe from interruption - no heals etc. can affect us in this state
	ThisActor.SetNoBleedoutRecovery(true)
	HealthToHealTo = 10.0
	RegisterForSingleUpdate(20.0)

	;Also start checking for nearby friendlies via FollowerFinderQuest
	RegisterForSingleUpdateGameTime(FollowerFinderUpdateGameTime)
endEvent
event OnUpdate()
	;Abort our friendlies check if still running
	;There's a miniscule chance of a race condition here if these fire on the same frame
	;Worst case, we get up from bleedout while starting defeat scenario - no big deal
	UnRegisterForUpdateGameTime()
	if (FollowerFinderQuest.IsRunning())
		FollowerFinderQuest.Stop()
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

		;Heal to (nearly) full and clear NoBleedoutRecovery
		ThisActor.RestoreActorValue("Health", ThisActor.GetBaseActorValue("Health"))
		ThisActor.SetNoBleedoutRecovery(false)

		;We'll either be done bleeding out next run or need a retry...
		RegisterForSingleUpdate(0.1)
		return
	endif

	;If we're done bleeding out, clean up and bail
	;First, for some reason, bleedout recovery sometimes restores all our health
	;Though this doesn't matter as we now just heal to mostly full anyway
	;Either way, to work around this, damage our health back down to HealthToHealTo
	;This has the nice side effect of proccing additional injuries from Wildcat etc.
	float adjHealth = ThisActor.GetActorValue("Health") - HealthToHealTo
	if (adjHealth > 0.0)
		ThisActor.DamageActorValue("Health", adjHealth)
	endif
	HealthToHealTo = 0.0

	;Fix broken ragdoll state!
	if (DeferredBump)
		DeferredBump = false
		Utility.Wait(1.0)
		ThisActor.PushActorAway(ThisActor, 0.0)
	endif
endEvent

;Full death handling
event OnUpdateGameTime()
	;Only allow one ProcessingDeath or FollowerFinderQuest thread
	;This could legitimately happen if we repeatedly enter bleedout before we'd finished ProcessingDeath
	;If we're actually getting our ass kicked that much, a normal non-punishing bleedout is fine :)
	if (ProcessingDeath || FollowerFinderQuest.IsRunning())
		return
	endif

	;If we don't have any friends around, start up our defeat logic
	FollowerFinderQuest.Start()
	if (!(FollowerFinderQuest.GetAlias(0) as ReferenceAlias).GetReference())
		FollowerFinderQuest.Stop()
		HandleDeath()
		return
	endif

	FollowerFinderQuest.Stop()
	RegisterForSingleUpdateGameTime(FollowerFinderUpdateGameTime)
endEvent
function HandleDeath()
	;OnUpdateGameTime will guard against this being called more than once while ProcessingDeath
	ProcessingDeath = true
	UnRegisterForUpdate()
	;Debug.MessageBox("You died")

	;This will just kill us - TODO maybe hook up as an option?
	;ThisActor.ForceActorValue("Health", 1.0)
	;Self.Clear()
	;Utility.Wait(0.5)
	;ThisActor.Kill()

	;Ensure our aliases are set up right - we purposefully only check this once
	;After this point, we must assume all actors are valid, and let functions fail when they are not
	;TryFullTeleport is the one exception, since that handles the delicate task of player transport
	Actor ThisActor = Self.GetReference() as Actor
	Actor VendorActor = VendorAlias.GetReference() as Actor
	ObjectReference VendorChest = VendorAlias.GetReference()
	if (!ThisActor || !VendorActor || !VendorChest)
		OnUpdate()
		ProcessingDeath = false
		return
	endif

	;Begin fading - this will also lock out player controls
	;At this point, we're considered committed to our fate, and should not be interrupted
	ShouldBeFaded = true
	Game.FadeOutGame(true, true, 0.0, FadeTime + 0.2)
	Utility.Wait(FadeTime)

	;Hold our fade - this might expire if we get stuck in a wait-loop later
	;But by then, we probably want to see what's going on anyway
	Game.FadeOutGame(false, true, 60.0, FadeTime)

	;Strip equipment and warp vendor to us - he should begin moving immediately on EvaluatePackage
	ThisActor.UnequipAll() ;This will hand over all equipment to vendor - see OnObjectUnequipped
	VendorActor.Disable(false)
	VendorActor.MoveTo(ThisActor, 0.0, 0.0, 0.0, true)
	ApplySpeedMult(VendorActor, 200.0) ;Zoom!
	VendorActor.Enable(false)
	VendorActor.EvaluatePackage()
	Utility.Wait(8.0)

	;Prepare to warp to vendor - exit bleedout, and hold until we're ready to move
	HealthToHealTo = 30.0
	OnUpdate()
	Utility.Wait(2.0)
	while (ThisActor.IsBleedingOut())
		Utility.Wait(1.0)
	endwhile

	;Engage!
	ApplySpeedMult(VendorActor, 100.0)
	TryFullTeleport(ThisActor, VendorActor) ;Internally tests ThisActor, VendorActor
	while (WaitingForCellLoad)
		TryFullTeleport(ThisActor, VendorActor)
	endwhile

	;We've arrived - place us somewhere sane on the navmesh (this isn't guaranteed when cell is unloaded)
	TryFullTeleport(ThisActor, VendorActor)

	;Place vendor at a nice location in front of us
	float aZ = ThisActor.GetAngleZ()
	VendorActor.Disable(false)
	VendorActor.MoveTo(ThisActor, VendorFinalPlacementDist * Math.Sin(aZ), VendorFinalPlacementDist * Math.Cos(aZ), 0.0, true)
	VendorActor.Enable(false)

	;Signal vendor to approach, and fade in
	GetOwningQuest().SetStage(1)
	VendorActor.EvaluatePackage()
	ShouldBeFaded = false
	Game.FadeOutGame(false, true, 0.0, FadeTime)
	Utility.Wait(5.0)

	;Oops! We dragged player somewhere unsafe, guess we can help fight
	;This is mostly here to avoid the upcoming EvaluatePackage in the middle of combat
	while (VendorActor.IsInCombat())
		Utility.Wait(5.0)
	endwhile

	;Signal vendor to wait for us to make a decision
	GetOwningQuest().SetStage(2)
	VendorActor.EvaluatePackage()
	Utility.Wait(10.0)

	;Also, don't run off while the player is still blabbing (or we're fighting again somehow), how rude
	while (VendorActor.IsInCombat() \
	|| VendorActor.IsInDialogueWithPlayer())
		Utility.Wait(5.0)
	endwhile

	;I must go, my planet needs me
	GetOwningQuest().Reset()
	VendorActor.EvaluatePackage()
	Utility.Wait(10.0)
	RegisterForSingleLOSLost(ThisActor, VendorActor)
endFunction
event OnLostLOS(Actor akViewer, ObjectReference akTarget)
	;This appears to be safe and always fires, even if we previously looked away or even zoned
	;Debug.Notification("foxDeath - OnLostLOS")
	akTarget.Disable(false)
	akTarget.MoveToMyEditorLocation()
	akTarget.Enable(false)
	ProcessingDeath = false
endEvent

;Additionally hold our fade OnPlayerLoadGame if needed
event OnPlayerLoadGame()
	;Do this as a short hold (with legit fade at the end) in case of race condition with HandleDeath
	while (ShouldBeFaded)
		Game.FadeOutGame(false, true, 1.2, FadeTime)
		Utility.Wait(1.0)
	endwhile
endEvent

;Handle stripping equipment from player
event OnObjectUnequipped(Form akBaseObject, ObjectReference akReference)
	if (!((akBaseObject as Ammo) || (akBaseObject as Armor) || (akBaseObject as Weapon)))
		return
	endif
	Actor ThisActor = Self.GetReference() as Actor
	if (ThisActor.IsBleedingOut())
		int count = 1
		if (akBaseObject as Ammo)
			count = ThisActor.GetItemCount(akBaseObject)
			count = Utility.RandomInt(count / 2, count)
		endif
		ThisActor.RemoveItem(akBaseObject, count, true, VendorChestAlias.GetReference())
	endif
endEvent

;Try a teleport, attempting to account for cell changes
function TryFullTeleport(Actor ThisActor, Actor VendorActor)
	if (ThisActor && VendorActor)
		VendorActor.Disable(false)
		ThisActor.MoveTo(VendorActor, 0.0, 0.0, 0.0, true)
		VendorActor.Enable(false)
	endif
	Utility.Wait(1.0)
	if (!ThisActor || !VendorActor \
	|| !ThisActor.GetParentCell() \
	|| !ThisActor.Is3DLoaded() \
	|| !VendorActor.Is3DLoaded())
		WaitingForCellLoad = true
	endif
endFunction
event OnCellLoad()
	WaitingForCellLoad = false
endEvent

;Apply SpeedMult - CarryWeight must be adjusted for SpeedMult to apply
function ApplySpeedMult(Actor VendorActor, float SpeedMult)
	VendorActor.SetActorValue("SpeedMult", SpeedMult)
	VendorActor.ModActorValue("CarryWeight", 1.0)
	VendorActor.ModActorValue("CarryWeight", -1.0)
endFunction
