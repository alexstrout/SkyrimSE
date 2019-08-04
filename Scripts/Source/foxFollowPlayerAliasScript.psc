Scriptname foxFollowPlayerAliasScript extends ReferenceAlias
{Basically exists to forward OnPlayerLoadGame events to foxFollowDialogueFollowerScript}

foxFollowDialogueFollowerScript Property DialogueFollower Auto

;================
;Mod Initialization and Updating
;================
;Check for updates (and thus event registrations) on game load, provided we've been init once (we're not filled until then)
event OnPlayerLoadGame()
	;Debug.Trace("foxFollow OnPlayerLoadGame " + DialogueFollower.foxFollowVer)
	DialogueFollower.CheckForModUpdate()
endEvent
