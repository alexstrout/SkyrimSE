Scriptname foxDeathPlayerAliasScript extends ReferenceAlias
{Derpy script that handles bleedout}

Quest Property FollowerFinderQuest Auto

float Property FollowerFinderGameTime = 72.0 AutoReadOnly
float Property CombatWaitUpdateTime = 12.0 AutoReadOnly

event OnEnterBleedout()
	;If we don't exist or already have NoBleedoutRecovery set (e.g. some other death-handling event is happening?), bail immediately
	Actor ThisActor = Self.GetReference() as Actor
	if (!ThisActor || ThisActor.GetNoBleedoutRecovery())
		return
	endif

	;Player bleedout is weird, so SetNoBleedoutRecovery and start manually ticking up our health
	ThisActor.SetNoBleedoutRecovery(true)
	RegisterForSingleUpdate(1.0)

	;We'll hog the remainder of this thread checking for nearby friendlies via FollowerFinderQuest
	while (ThisActor && ThisActor.IsBleedingOut())
	    FollowerFinderQuest.Start()
		Utility.Wait(5.0)

		;If we don't have any around, then bail and handle our actual death
		if (!(FollowerFinderQuest.GetAlias(0) as ReferenceAlias).GetReference())
	    	FollowerFinderQuest.Stop()
			HandleDeath(ThisActor)
			return
		endif

	    FollowerFinderQuest.Stop()
		Utility.Wait(1.0)
	endwhile
endEvent

event OnUpdate()
	Actor ThisActor = Self.GetReference() as Actor
	if (!ThisActor)
		return
	endif

	;If we're done bleeding out, clean up and bail
	if (!ThisActor.IsBleedingOut())
		ThisActor.SetNoBleedoutRecovery(false)

		;For some reason, bleedout recovery sometimes, but not always, restores all our health
		;To work around this, damage our health back down to 1hp
		;This has the nice side effect of proccing injuries from Wildcat etc.
		;ThisActor.RestoreActorValue("Health", 10000.0)
		float adjHealth = ThisActor.GetActorValue("Health") - 1.0
		if (adjHealth > 0.0)
			ThisActor.DamageActorValue("Health", adjHealth)
		endif

		return
	endif

	;Otherwise, slowly heal up
	ThisActor.RestoreActorValue("Health", 1.0)
	RegisterForSingleUpdate(1.0)
endEvent

function HandleDeath(Actor ThisActor)
	;Debug.MessageBox("You died")
	ThisActor.ForceActorValue("Health", 1.0)
	while !(Self.TryToClear())
		Utility.Wait(0.1)
	endwhile
	Utility.Wait(0.5)
	ThisActor.Kill()
endFunction
