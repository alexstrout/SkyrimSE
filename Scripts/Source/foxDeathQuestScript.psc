Scriptname foxDeathQuestScript extends Quest Conditional
{Contains death-handling stuff that was originally all in foxDeathPlayerAliasScript as a monolithic mess}

int Property RequestedVendorAIState = 0 Auto Conditional

Quest Property FollowerFinderQuest Auto
GlobalVariable Property FollowerFinderMaxDist Auto

foxDeathPlayerAliasScript Property PlayerAlias Auto
foxDeathVendorAliasScript Property VendorAlias Auto
ReferenceAlias Property VendorChestAlias Auto
foxDeathFadeManagerAliasScript Property FadeManagerAlias Auto
foxDeathItemManagerAliasScript Property ItemManagerAlias Auto
LocationAlias Property VendorDestinationAlias Auto

GlobalVariable Property DifficultySetting Auto
MiscObject Property DifficultyGoldItem Auto

;Set directly by foxDeathWeaknessEffectScript
;Used by foxDeathSummonVendorEffectScript to determine if we can summon vendor, among other things
;Also used here to stack effect without duplicating it in active effects
ActiveMagicEffect Property ActiveWeaknessEffect Auto
Spell Property WeaknessSpell Auto
int CurrentWeaknessSpellDuration
float CurrentWeaknessSpellMagnitude

bool ProcessingDeath = false

float Property FollowerFinderUpdateTime = 6.0 AutoReadOnly

;Full death handling
event OnUpdate()
	;Only allow one ProcessingDeath or FollowerFinderQuest thread
	;This could legitimately happen if we repeatedly enter bleedout before we'd finished ProcessingDeath
	;If we're actually getting our ass kicked that much, a normal non-punishing bleedout is fine :)
	if (ProcessingDeath || FollowerFinderQuest.IsRunning())
		return
	endif

	;Quick distance checks - anything below 0 means disabled, 0 means always HandleDeath
	float MaxDist = FollowerFinderMaxDist.GetValue()
	if (MaxDist <= 0.0)
		if (MaxDist == 0.0)
			HandleDeath()
		endif
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
	ObjectReference VendorChest = VendorChestAlias.GetReference()
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
	;At this point, we're considered committed to our fate, and should not be interrupted
	FadeManagerAlias.FadeOut()

	;Figure out which equipment we should strip
	;ItemManagerAlias.EnumerateItemsToStrip(PlayerActor) ;This is actually done first in PlayerAlias::OnEnterBleedout
	ItemManagerAlias.EnumerateItemsToStripOnFollowers() ;Must be done before SetGhost, due to using DoCombatSpellApply

	;Warp vendor to us - he should begin moving immediately on EvaluatePackage
	VendorActor.Disable(false)
	VendorActor.MoveTo(PlayerActor, 0.0, 0.0, 0.0, true)
	VendorAlias.ApplySpeedMult(400.0) ;Zoom!
	VendorActor.Enable(false)
	RequestedVendorAIState = 1
	VendorActor.EvaluatePackage()
	VendorAlias.SetInvisible(true)
	float StartingDist = VendorActor.GetDistance(PlayerActor)
	Utility.Wait(1.0)

	;Switch to alternate package if we're not moving
	if (Math.abs(VendorActor.GetDistance(PlayerActor) - StartingDist) < 2.0)
		RequestedVendorAIState = 3
		VendorActor.EvaluatePackage()
	endif
	Utility.Wait(7.0)

	;Handle pre-strip difficulty options
	;-1 = Easy - no changes on death
	;0 = Normal - clear previous Vendor gold on death
	int Difficulty = DifficultySetting.GetValue() as int
	if (Difficulty > -1)
		VendorActor.RemoveItem(DifficultyGoldItem, 999999)
		VendorChest.RemoveItem(DifficultyGoldItem, 999999)

		;1 = Hard - clear previous items on death (souls-ish)
		if (Difficulty > 0)
			VendorActor.RemoveAllItems() ;Will keep quest items intact
			VendorChest.RemoveAllItems()
		endif
	endif

	;Actually strip equipment
	;This must be done before we exit bleedout, since we ClearItemsToStrip there (in case this didn't happen)
	ItemManagerAlias.SetNoPlayerEquipmentDrop(false)
	ItemManagerAlias.StripAllItems(VendorChest)

	;Handle post-strip difficulty options
	;2 = Brutal - clear all items on death
	if (Difficulty > 1)
		VendorActor.RemoveAllItems()
		VendorChest.RemoveAllItems()
	endif

	;Prepare to warp to vendor - exit bleedout, and hold until we're ready to move
	PlayerActor.SetGhost(true) ;Should probably make sure we don't get killed before teleporting, oops!
	PlayerAlias.ExitBleedout()
	Utility.Wait(2.0)
	while (PlayerActor.IsBleedingOut())
		Utility.Wait(1.0)
	endwhile

	;Engage!
	VendorAlias.ApplySpeedMult(100.0)
	RequestedVendorAIState = 0
	VendorActor.EvaluatePackage()
	int WaitingForCellLoad = 2
	while (WaitingForCellLoad)
		;If we've arrived, try again to place us somewhere sane on the navmesh (this isn't guaranteed while cell is unloaded)
		;If not, we'll just reset WaitingForCellLoad and go again to do the above
		while (!PlayerAlias.TryFullTeleport(VendorActor, WaitingForCellLoad == 2))
			WaitingForCellLoad = 2
			Utility.Wait(1.0)
		endwhile
		;Debug.Trace("foxDeath - HandleDeath WaitingForCellLoad " + WaitingForCellLoad)
		WaitingForCellLoad -= 1
	endwhile
	PlayerActor.SheatheWeapon() ;Fixes weirdness if we were mid-action on a previously equipped weapon
	PlayerActor.SetGhost(false) ;Safe to get killed again

	;We are weak now (must be applied here due to SetGhost)
	ApplyWeaknessSpell(PlayerActor)

	;My work here is done
	VendorAlias.SetInvisible(false)
	VendorActor.Disable(false)
	VendorActor.MoveToMyEditorLocation()
	VendorActor.Enable(false)
	RequestedVendorAIState = 0
	VendorActor.EvaluatePackage()

	;Good to go!
	FadeManagerAlias.FadeIn()
	ProcessingDeath = false
endFunction

;Are we currently processing death?
bool function IsProcessingDeath()
	return ProcessingDeath
endFunction

;Apply WeaknessSpell, taking into account ActiveWeaknessEffect already being applied
function ApplyWeaknessSpell(Actor TargetActor)
	if (ActiveWeaknessEffect)
		ActiveWeaknessEffect.Dispel()
		while (ActiveWeaknessEffect)
			Utility.Wait(0.1)
		endwhile

		;Stack additional duration and magnitude onto effect before reapplying
		if (CurrentWeaknessSpellMagnitude < 80.0)
			CurrentWeaknessSpellDuration += 180
			CurrentWeaknessSpellMagnitude += 10.0
		endif
	else
		CurrentWeaknessSpellDuration = 720 ;Should be 720s default in editor
		CurrentWeaknessSpellMagnitude = 20.0 ;Should be 20.0 default in editor
	endif
	WeaknessSpell.SetNthEffectDuration(0, CurrentWeaknessSpellDuration)
	WeaknessSpell.SetNthEffectMagnitude(0, CurrentWeaknessSpellMagnitude)
	TargetActor.DoCombatSpellApply(WeaknessSpell, TargetActor)
endFunction
