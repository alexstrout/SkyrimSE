Scriptname foxDeathQuestScript extends Quest Conditional
{Contains death-handling stuff that was originally all in foxDeathPlayerAliasScript as a monolithic mess}

int Property RequestedVendorAIState = 0 Auto Conditional

Quest Property FollowerFinderQuest Auto
foxDeathPlayerAliasScript Property PlayerAlias Auto
foxDeathVendorAliasScript Property VendorAlias Auto
ReferenceAlias Property VendorChestAlias Auto
foxDeathFadeManagerAliasScript Property FadeManagerAlias Auto

bool ProcessingDeath = false

;0 = TryFullTeleport passed - In loaded cell and placed on navmesh - done
;1 = TryFullTeleport passed - In loaded cell, waiting to be placed on navmesh
;2 = Undetermined (starting state) - call TryFullTeleport, either 1 or 3 from here
;3 = TryFullTeleport failed - In totally new cell, awaiting callback from OnCellLoad
int WaitingForCellLoad = 0

float Property FollowerFinderUpdateTime = 6.0 AutoReadOnly
float Property VendorFinalPlacementDist = 512.0 AutoReadOnly

;Full death handling
event OnUpdate()
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
	RegisterForSingleUpdate(FollowerFinderUpdateTime)
endEvent
function HandleDeath()
	;OnUpdate will guard against this being called more than once while ProcessingDeath
	ProcessingDeath = true
	PlayerAlias.UnRegisterForUpdate()
	;Debug.MessageBox("You died")

	;Ensure our aliases are set up right - we purposefully only check this once
	;After this point, we must assume all actors are valid, and let functions fail when they are not
	;TryFullTeleport is the one exception, since that handles the delicate task of player transport
	Actor PlayerActor = PlayerAlias.GetReference() as Actor
	Actor VendorActor = VendorAlias.GetReference() as Actor
	ObjectReference VendorChest = VendorAlias.GetReference()
	if (!PlayerActor || !VendorActor || !VendorChest)
		PlayerAlias.ExitBleedout()
		ProcessingDeath = false
		return
	endif

	;This will just kill us - maybe hook up as an option later?
	;PlayerAlias.ExitBleedout()
	;PlayerAlias.Clear()
	;Utility.Wait(0.5)
	;PlayerActor.Kill()

	;Begin fading - this will also lock out player controls
	;As such, we should first switch PlayerAlias to ProcessingDeath state to enable events for equipment stripping etc.
	;At this point, we're considered committed to our fate, and should not be interrupted
	PlayerAlias.GoToState("ProcessingDeath")
	FadeManagerAlias.FadeOut()

	;Strip equipment and warp vendor to us - he should begin moving immediately on EvaluatePackage
	PlayerActor.UnequipAll() ;This will hand over all equipment to vendor while ProcessingDeath - see OnObjectUnequipped
	RequestedVendorAIState = 1
	VendorActor.Disable(false)
	VendorActor.MoveTo(PlayerActor, 0.0, 0.0, 0.0, true)
	VendorAlias.ApplySpeedMult(200.0) ;Zoom!
	VendorActor.Enable(false)
	VendorActor.EvaluatePackage()
	VendorActor.AddSpell(VendorAlias.InvisibilityAbility)
	Utility.Wait(8.0)

	;Prepare to warp to vendor - exit bleedout, and hold until we're ready to move
	PlayerActor.SetGhost(true) ;Should probably make sure we don't get killed before teleporting, oops!
	PlayerAlias.ExitBleedout(30.0) ;This will exit bleedout
	Utility.Wait(2.0)
	while (PlayerActor.IsBleedingOut())
		Utility.Wait(1.0)
	endwhile

	;Engage!
	VendorAlias.ApplySpeedMult(100.0)
	WaitingForCellLoad = 2
	while (WaitingForCellLoad)
		;If we've arrived, try again to place us somewhere sane on the navmesh (this isn't guaranteed while cell is unloaded)
		;If not, we'll just reset WaitingForCellLoad and go again to do the above
		while (WaitingForCellLoad > 2 || !PlayerAlias.TryFullTeleport(VendorActor))
			WaitingForCellLoad = 3
		endwhile
		;Debug.Trace("foxDeathScript - HandleDeath WaitingForCellLoad " + WaitingForCellLoad)
		WaitingForCellLoad -= 1
	endwhile
	PlayerActor.SheatheWeapon() ;Fixes weirdness if we were mid-action on a previously equipped weapon
	PlayerActor.SetGhost(false) ;Safe to get killed again

	;Place vendor at a nice location in front of us
	float aZ = PlayerActor.GetAngleZ()
	VendorActor.Disable(false)
	VendorActor.MoveTo(PlayerActor, VendorFinalPlacementDist * Math.Sin(aZ), VendorFinalPlacementDist * Math.Cos(aZ), 0.0, true)
	VendorActor.Enable(false)
	VendorActor.RemoveSpell(VendorAlias.InvisibilityAbility)

	;Signal vendor to approach, and fade in
	RequestedVendorAIState = 2
	VendorActor.EvaluatePackage()
	PlayerAlias.GoToState("")
	FadeManagerAlias.FadeIn()
	Utility.Wait(5.0)

	;Oops! We dragged player somewhere unsafe, guess we can help fight
	;This is mostly here to avoid the upcoming EvaluatePackage in the middle of combat
	while (VendorActor.IsInCombat())
		Utility.Wait(5.0)
	endwhile

	;Signal vendor to wait for us to make a decision
	RequestedVendorAIState = 0
	VendorActor.EvaluatePackage()
	Utility.Wait(10.0)

	;Also, don't run off while the player is still blabbing (or we're fighting again somehow), how rude
	while (VendorActor.IsInCombat() \
	|| VendorActor.IsInDialogueWithPlayer())
		Utility.Wait(5.0)
	endwhile

	;I must go, my planet needs me
	RequestedVendorAIState = 1
	VendorActor.EvaluatePackage()
	Utility.Wait(10.0)
	PlayerAlias.RegisterForSingleLOSLost(PlayerActor, VendorActor)
endFunction

;Forwarded from PlayerAlias
function PlayerAliasOnCellLoad()
	;Debug.Trace("foxDeathScript - PlayerAliasOnCellLoad WaitingForCellLoad " + WaitingForCellLoad)
	WaitingForCellLoad = 2
endFunction
function PlayerAliasOnLostLOS(Actor akViewer, ObjectReference akTarget)
	;This appears to be safe and always fires, even if we previously looked away or even zoned
	;Debug.Notification("foxDeath - OnLostLOS")
	RequestedVendorAIState = 0
	akTarget.Disable(false)
	akTarget.MoveToMyEditorLocation()
	akTarget.Enable(false)
	(akTarget as Actor).EvaluatePackage()
	ProcessingDeath = false
endFunction
