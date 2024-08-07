;BEGIN FRAGMENT CODE - Do not edit anything between this and the end comment
;NEXT FRAGMENT INDEX 1
Scriptname foxPetDialDismiss Extends TopicInfo Hidden

;BEGIN FRAGMENT Fragment_0
Function Fragment_0(ObjectReference akSpeakerRef)
Actor akSpeaker = akSpeakerRef as Actor
;BEGIN CODE
DialogueFollowerScript dfScript = pDialogueFollower as DialogueFollowerScript
if (dfScript.pFollowerAlias.GetReference() == akSpeakerRef)
	;Match other dismiss dialogues - otherwise we say line (and run this) twice! D'oh
	dfScript.DismissFollower(0, 0)
else
	dfScript.DismissAnimal()
endif
akSpeaker.SetPlayerTeammate(false)
akSpeaker.SetActorValue("WaitingForPlayer", 0)
;END CODE
EndFunction
;END FRAGMENT

;END FRAGMENT CODE - Do not edit anything between this and the begin comment

Quest Property pDialogueFollower  Auto
