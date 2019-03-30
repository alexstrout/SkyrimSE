ScriptName DialogueFollowerScript extends Quest Conditional
{Rewrite of DialogueFollowerScript that redirects functionality to foxFollowDialogueFollowerScript - this could not just be a new script itself due to use in other scripts}

;Begin Vanilla DialogueFollowerScript Members
GlobalVariable Property pPlayerFollowerCount Auto
GlobalVariable Property pPlayerAnimalCount Auto
ReferenceAlias Property pFollowerAlias Auto
ReferenceAlias property pAnimalAlias Auto
Faction Property pDismissedFollower Auto
Faction Property pCurrentHireling Auto
Message Property  FollowerDismissMessage Auto
Message Property AnimalDismissMessage Auto
Message Property  FollowerDismissMessageWedding Auto
Message Property  FollowerDismissMessageCompanions Auto
Message Property  FollowerDismissMessageCompanionsMale Auto
Message Property  FollowerDismissMessageCompanionsFemale Auto
Message Property  FollowerDismissMessageWait Auto
SetHirelingRehire Property HirelingRehireScript Auto

;Property to tell follower to say dismissal line
Int Property iFollowerDismiss Auto Conditional

; PATCH 1.9: 77615: remove unplayable hunting bow when follower is dismissed
Weapon Property FollowerHuntingBow Auto
Ammo Property FollowerIronArrow Auto
;End Vanilla DialogueFollowerScript Members

foxFollowDialogueFollowerScript Property foxFollowDialogueFollower Auto

;On the off chance we're actually running this on a new game (DialogueFollower is ever-present!), signal to foxFollowDialogueFollower to hide its update message
event OnInit()
	foxFollowDialogueFollower.foxFollowVer = -1
endEvent

function SetFollower(ObjectReference FollowerRef)
	foxFollowDialogueFollower.SetMultiFollower(FollowerRef, true)
endFunction
function SetAnimal(ObjectReference AnimalRef)
	foxFollowDialogueFollower.SetMultiFollower(AnimalRef, false)
endFunction

function FollowerWait()
	foxFollowDialogueFollower.FollowerMultiFollowWait(None, true, 1)
endFunction
function AnimalWait()
	foxFollowDialogueFollower.FollowerMultiFollowWait(None, false, 1)
endFunction
function FollowerFollow()
	foxFollowDialogueFollower.FollowerMultiFollowWait(None, true, 0)
endFunction
function AnimalFollow()
	foxFollowDialogueFollower.FollowerMultiFollowWait(None, false, 0)
endFunction

function DismissFollower(int iMessage = 0, int iSayLine = 1)
	foxFollowDialogueFollower.DismissMultiFollower(None, true, iMessage, iSayLine)
endFunction
function DismissAnimal()
	foxFollowDialogueFollower.DismissMultiFollower(None, false)
endFunction
