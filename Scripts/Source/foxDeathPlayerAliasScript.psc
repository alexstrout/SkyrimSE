Scriptname foxDeathPlayerAliasScript extends ReferenceAlias
{Derpy script that handles bleedout and other cool stuff}

foxDeathQuestScript Property DeathQuest Auto

bool DeferredBump = false

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
	RegisterForSingleUpdate(20.0)

	;Also start checking for nearby friendlies via FollowerFinderQuest
	DeathQuest.RegisterForSingleUpdate(DeathQuest.FollowerFinderUpdateTime)
endEvent
event OnUpdate()
	ExitBleedout()
endEvent
function ExitBleedout(float HealthToHealTo = 10.0)
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

	;Fix broken ragdoll state!
	if (DeferredBump)
		DeferredBump = false
		Utility.Wait(1.0)
		ThisActor.PushActorAway(ThisActor, 0.0)
	endif
endFunction

;Try a teleport, attempting to account for cell changes - returns true if cell appears loaded (more or less)
;Latent - waits a second to test if cell is relatively loaded
bool function TryFullTeleport(Actor VendorActor)
	Actor ThisActor = Self.GetReference() as Actor
	if (ThisActor && VendorActor)
		VendorActor.Disable(false)
		ThisActor.MoveTo(VendorActor, 0.0, 0.0, 0.0, true)
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
state ProcessingDeath
	;Handle stripping equipment from player - here so we don't yank equipment while player still has control of it
	event OnObjectUnequipped(Form akBaseObject, ObjectReference akReference)
		;Equipable stuff only!
		if (!(akBaseObject as Ammo || akBaseObject as Armor || akBaseObject as Weapon))
			return
		endif

		Actor ThisActor = Self.GetReference() as Actor
		int count = 1
		if (akBaseObject as Ammo)
			count = ThisActor.GetItemCount(akBaseObject)
			count = Utility.RandomInt(count / 2, count)
		endif
		ThisActor.RemoveItem(akBaseObject, count, true, DeathQuest.VendorChestAlias.GetReference())
	endEvent

	;Needed for DeathQuest, just forward the callback
	event OnCellLoad()
		DeathQuest.PlayerAliasOnCellLoad()
	endEvent
endState
