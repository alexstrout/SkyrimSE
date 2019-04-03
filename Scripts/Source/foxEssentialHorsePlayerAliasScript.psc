Scriptname foxEssentialHorsePlayerAliasScript extends ReferenceAlias
{Derpy script that just periodically sets EssentialHorseAlias to our current horse based on random events}

ReferenceAlias Property EssentialHorseAlias Auto

event OnInit()
	;Debug.Notification("foxHorse OnInit")
	SetEssentialHorseAlias()
endEvent

event OnPlayerFastTravelEnd(float afTravelGameTimeHours)
	;Debug.Notification("foxHorse OnPlayerFastTravelEnd " + afTravelGameTimeHours)
	SetEssentialHorseAlias()
endEvent

event OnPlayerLoadGame()
	;Debug.Notification("foxHorse OnPlayerLoadGame")
	SetEssentialHorseAlias()
endEvent

;event OnLocationChange(Location akOldLoc, Location akNewLoc)
;	;Debug.Notification("foxHorse OnLocationChange " + akNewLoc.GetName())
;	SetEssentialHorseAlias()
;endEvent

function SetEssentialHorseAlias()
	Actor HorseActor = Game.GetPlayersLastRiddenHorse()
	if (HorseActor && EssentialHorseAlias.GetReference() as Actor != HorseActor)
		EssentialHorseAlias.ForceRefTo(HorseActor)
		;Debug.Notification("foxHorse SetEssentialHorseAlias!")
	endif
endFunction
