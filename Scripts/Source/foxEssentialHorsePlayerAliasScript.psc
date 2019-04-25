Scriptname foxEssentialHorsePlayerAliasScript extends ReferenceAlias
{Derpy script that just periodically sets EssentialHorseAlias to our current horse based on random events}

ReferenceAlias Property EssentialHorseAlias Auto

event OnInit()
	;Debug.Notification("foxHorse OnInit")
	OnUpdate()
endEvent

event OnPlayerLoadGame()
	;Debug.Notification("foxHorse OnPlayerLoadGame")
	OnUpdate()
endEvent

event OnUpdate()
	ObjectReference ThisRef = Self.GetReference()
	if (!ThisRef)
		RegisterForSingleUpdate(2.0)
		return
	endif

	;We don't care if something goes wrong here, not the end of the world
	RegisterForAnimationEvent(ThisRef, "tailHorseMount")
	;RegisterForAnimationEvent(ThisRef, "tailHorseDismount")

	;Debug.Notification("foxHorse OnUpdate registered for animation events!")
	SetEssentialHorseAlias()
endEvent

event OnAnimationEvent(ObjectReference akSource, string asEventName)
	;Debug.Notification("foxHorse OnAnimationEvent " + asEventName)
	SetEssentialHorseAlias()
endEvent

event OnPlayerFastTravelEnd(float afTravelGameTimeHours)
	;Debug.Notification("foxHorse OnPlayerFastTravelEnd " + afTravelGameTimeHours)
	SetEssentialHorseAlias()
endEvent

;event OnLocationChange(Location akOldLoc, Location akNewLoc)
;	;Debug.Notification("foxHorse OnLocationChange " + akNewLoc.GetName())
;	SetEssentialHorseAlias()
;endEvent

function SetEssentialHorseAlias()
	Actor NewHorseActor = Game.GetPlayersLastRiddenHorse()
	if (!NewHorseActor)
		return
	endif

	;While we're here, also fix items (Ammo from projectiles mostly) slowly piling up in iventory...
	ObjectReference ThisRef = Self.GetReference()
	if (ThisRef)
		NewHorseActor.RemoveAllItems(ThisRef, false, true)
	endif

	;If we've switched horses, update accordingly
	Actor OldHorseActor = EssentialHorseAlias.GetReference() as Actor
	if (OldHorseActor != NewHorseActor)
		;Also set teammate status (and clear on old horse) so it doesn't detect us sneaking
		;Note that we don't allow orders to be given, though it might be a nice touch if we had foxPet-style item dropping
		if (OldHorseActor)
			OldHorseActor.SetPlayerTeammate(false)
		endif
		EssentialHorseAlias.ForceRefTo(NewHorseActor)
		NewHorseActor.SetPlayerTeammate(true, false)
		;Debug.Notification("foxHorse SetEssentialHorseAlias!")
	endif
endFunction
