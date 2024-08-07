Scriptname foxDeathQuestScript extends Quest Conditional
{Contains death-handling stuff that was originally all in foxDeathPlayerAliasScript as a monolithic mess}

int Property RequestedVendorAIState = 0 Auto Conditional

Quest Property FollowerFinderQuest Auto
GlobalVariable Property FollowerFinderMaxDist Auto

GlobalVariable Property MinReviveTime Auto

foxDeathPlayerAliasScript Property PlayerAlias Auto
foxDeathVendorAliasScript Property VendorAlias Auto
foxDeathVendorChestAliasScript Property VendorChestAlias Auto
foxDeathFadeManagerAliasScript Property FadeManagerAlias Auto
foxDeathItemManagerAliasScript Property ItemManagerAlias Auto
LocationAlias Property VendorDestinationAlias Auto

Spell Property CalmSpell Auto
GlobalVariable Property DifficultySetting Auto
MiscObject Property DifficultyGoldItem Auto
GlobalVariable Property AllowSellback Auto

;Set directly by foxDeathWeaknessEffectScript
;Used by foxDeathSummonVendorEffectScript to determine if we can summon vendor, among other things
;Also used here to stack effect without duplicating it in active effects
ActiveMagicEffect Property ActiveWeaknessEffect Auto
Spell Property WeaknessSpell Auto
int CurrentWeaknessSpellDuration
float CurrentWeaknessSpellMagnitude

;Similar to above - note same duration, so shares the same duration var
;Ideally this would be a nice array but I don't feel like writing save-updating functions for that
ActiveMagicEffect Property ActiveStrengthEffect Auto
Spell Property StrengthSpell Auto
Perk Property StrengthPerk Auto ;Can get via MagicEffect, but for convenience
float CurrentStrengthSpellMagnitude

Message Property UninstallMessage Auto
Message Property UninstallCompleteMessage Auto

bool ProcessingDeath = false
bool GracePeriod = false

float Property FollowerFinderUpdateTime = 6.0 AutoReadOnly

;================
;Defeat Stuff
;================
;Full death handling
event OnUpdate()
	;Only allow one ProcessingDeath or FollowerFinderQuest thread
	;This could legitimately happen if we repeatedly enter bleedout before we'd finished ProcessingDeath
	;If we're actually getting our ass kicked that much, a normal non-punishing bleedout is fine :)
	;We'll also handle a separate "grace period" here
	if (ProcessingDeath || FollowerFinderQuest.IsRunning() \
	|| (GracePeriod && ActiveWeaknessEffect && ActiveWeaknessEffect.GetTimeElapsed() < 30.0))
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

	;Oof, flop over dead
	PlayerActor.PushActorAway(PlayerActor, 0.0)

	;Begin fading - this will also lock out player controls
	;At this point, we're considered committed to our fate, and should not be interrupted
	FadeManagerAlias.FadeOut()

	;Figure out which equipment we should strip
	;ItemManagerAlias.EnumerateItemsToStrip(PlayerActor) ;This is actually done first in PlayerAlias::OnEnterBleedout
	ItemManagerAlias.EnumerateItemsToStripOnFollowers()

	;Calm all nearby actors - should be enough time to escape cleanly
	ApplyCalmSpell(PlayerActor, 12)

	;Warp vendor to us - he should begin moving immediately on EvaluatePackage
	VendorActor.Disable(false)
	VendorActor.MoveTo(PlayerActor, 0.0, 0.0, 0.0, true)
	VendorAlias.ApplySpeedMult(800.0) ;Zoom!
	VendorActor.Enable(false)
	VendorAlias.SetInvisible(true)
	VendorAlias.SetMovementState(1)

	;Handle pre-strip difficulty options
	;-1 = Easy - no changes on death
	;0 = Normal - clear previous Vendor gold on death
	int Difficulty = DifficultySetting.GetValue() as int
	if (Difficulty > -1)
		VendorChest.RemoveItem(DifficultyGoldItem, 999999)

		;1 = Hard - clear previous items on death (souls-ish)
		if (Difficulty > 0)
			;RemoveAllItems' abRemoveQuestItems does not seem to function here, so roll our own function
			VendorChestAlias.RemoveAllNonQuestItems(VendorActor)
		endif
	endif

	;Actually strip equipment
	;This must be done before we exit bleedout, since we ClearItemsToStrip there (in case this didn't happen)
	ItemManagerAlias.SetNoPlayerEquipmentDrop(false)
	ItemManagerAlias.StripAllItems(VendorChest)

	;Handle post-strip difficulty options
	;2 = Brutal - clear all items on death
	if (Difficulty > 1)
		VendorChestAlias.RemoveAllNonQuestItems(VendorActor)
	endif

	;Prepare to warp to vendor - exit bleedout, and hold until we're ready to move
	PlayerActor.SetGhost(true) ;Should probably make sure we don't get killed before teleporting, oops!
	PlayerAlias.ExitBleedout(30.0, 1) ;We'll apply weakness later, due to SetGhost (which should come first)
	Utility.Wait(8.0)
	while (PlayerActor.IsBleedingOut())
		Utility.Wait(1.0)
	endwhile

	;Engage!
	VendorAlias.SetMovementState(0)
	int WaitingForCellLoad = 2
	int RemainingCombatChecks = 3
	while (WaitingForCellLoad > 0)
		;If we've arrived, try again to place us somewhere sane on the navmesh (this isn't guaranteed while cell is unloaded)
		;If not, we'll just reset WaitingForCellLoad and go again to do the above
		while (!PlayerAlias.TryFullTeleport(VendorActor, WaitingForCellLoad == 2))
			WaitingForCellLoad = 2
			Utility.Wait(1.0)
		endwhile
		;Debug.Trace("foxDeath - HandleDeath WaitingForCellLoad " + WaitingForCellLoad)
		WaitingForCellLoad -= 1

		;Do a combat check - if we end up in combat, we should attempt to relocate
		if (WaitingForCellLoad <= 0 && RemainingCombatChecks > 0)
			SendModEvent("foxDeathDispelCalmEffect")
			Utility.Wait(1.0)
			if (PlayerActor.IsInCombat())
				ApplyCalmSpell(PlayerActor, 12)
				VendorAlias.SetMovementState(1)
				Utility.Wait(8.0)

				;Again!
				VendorAlias.SetMovementState(0)
				WaitingForCellLoad = 2
				RemainingCombatChecks -= 1
			endif
		endif
	endwhile

	;We're done teleporting - begin cleaning up
	PlayerActor.SheatheWeapon() ;Fixes weirdness if we were mid-action on a previously equipped weapon
	PlayerActor.SetGhost(false) ;Safe to get killed again
	ApplyWeaknessSpell(PlayerActor, true) ;Must be done after SetGhost, also apply grace period

	;My work here is done
	VendorAlias.ApplySpeedMult(100.0)
	VendorAlias.SetInvisible(false)
	VendorActor.Disable(false)
	VendorActor.MoveToMyEditorLocation()
	VendorActor.Enable(false)
	VendorAlias.SetMovementState(0)

	;Good to go!
	;SendModEvent("foxDeathDispelCalmEffect")
	ApplyCalmSpell(PlayerActor, 4) ;Actually, let us try to escape without getting insta-nuked on wakeup
	FadeManagerAlias.FadeIn()
	ProcessingDeath = false
endFunction

;Are we currently processing death?
bool function IsProcessingDeath()
	return ProcessingDeath
endFunction

;================
;Calm / Defeat Spell Stuff
;================
;Apply CalmSpell with desired Duration
function ApplyCalmSpell(Actor TargetActor, int Duration)
	CalmSpell.SetNthEffectDuration(0, Duration)
	TargetActor.DoCombatSpellApply(CalmSpell, TargetActor)
endFunction

;Apply WeaknessSpell, taking into account ActiveWeaknessEffect already being applied
;Also applies new StrengthSpell in a similar manner - should probably be "ApplyDefeatSpell" but keeping for compatibility
function ApplyWeaknessSpell(Actor TargetActor, bool AwardsGracePeriod = false)
	;Potentially stack additional duration and magnitude onto effects before reapplying
	if (ActiveWeaknessEffect)
		ActiveWeaknessEffect.Dispel() ;SetActiveDefeatEffect keeps this thread-safe
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

	;Only award half strength for non-defeat bleedouts
	float StrengthMult = 1.0
	if (!AwardsGracePeriod)
		StrengthMult = 0.5
	endif
	if (ActiveStrengthEffect)
		ActiveStrengthEffect.Dispel()
		if (CurrentStrengthSpellMagnitude < 20.0)
			CurrentStrengthSpellMagnitude += 2.0 * StrengthMult
		endif
	else
		CurrentStrengthSpellMagnitude = 10.0 * StrengthMult ;Should be 10.0 default in editor
	endif
	StrengthSpell.SetNthEffectDuration(0, CurrentWeaknessSpellDuration) ;Same duration as WeaknessSpell
	StrengthSpell.SetNthEffectMagnitude(0, CurrentStrengthSpellMagnitude)
	AdjustStrengthPerk()

	TargetActor.DoCombatSpellApply(WeaknessSpell, TargetActor)
	TargetActor.DoCombatSpellApply(StrengthSpell, TargetActor)
	GracePeriod = AwardsGracePeriod
endFunction

;Convenience function for applying our StrengthPerk magnitude
;Called from ApplyWeaknessSpell and PlayerAlias' OnPlayerLoadGame
function AdjustStrengthPerk()
	StrengthPerk.SetNthEntryValue(0, 0, 1.0 + CurrentStrengthSpellMagnitude / 100.0)
endFunction

;Convenience function for foxDeathDefeatEffectScripts
function SetActiveDefeatEffect(int DefeatEffectType, ActiveMagicEffect DefeatEffect, ActiveMagicEffect OldDefeatEffect = None)
	if (DefeatEffectType == 0)
		if (DefeatEffect || ActiveWeaknessEffect == OldDefeatEffect)
			ActiveWeaknessEffect = DefeatEffect
		endif
	elseif (DefeatEffectType == 1)
		if (DefeatEffect || ActiveStrengthEffect == OldDefeatEffect)
			ActiveStrengthEffect = DefeatEffect
		endif
	endif
endFunction

;================
;Uninstallation
;================
;Uninstall!
bool function UninstallMod()
	UninstallMessage.Show()

	;Remove our weakness effect if it exists
	if (ActiveWeaknessEffect)
		ActiveWeaknessEffect.Dispel()
	endif
	if (ActiveStrengthEffect)
		ActiveStrengthEffect.Dispel()
	endif

	;Stop FollowerFinderQuest if it's running (shouldn't be needed, but just in case)
	if (FollowerFinderQuest.IsRunning())
		FollowerFinderQuest.Stop()
	endif

	;Try to query our aliases - if any are messed up, recommend a quest restart so they can get filled
	;This should never happen, so it's fine staying as a Debug.MessageBox for useful diagnostics
	Actor PlayerActor = PlayerAlias.GetReference() as Actor
	Actor VendorActor = VendorAlias.GetReference() as Actor
	ObjectReference VendorChest = VendorChestAlias.GetReference()
	if (!PlayerActor || !VendorActor || !VendorChest)
		Debug.MessageBox("An error occurred - one of the following is invalid:" \
			+ "\nPlayer: " + PlayerActor \
			+ "\nVendor: " + VendorActor \
			+ "\nChest: " + VendorChest \
			+ "\n\nTry restarting the quest and trying again:" \
			+ "\nstartquest 1foxDeathQuest")
		return true
	endif

	;Wait if bleeding out or ProcessingDeath, or vendor is summoned
	while (PlayerActor.IsBleedingOut())
		PlayerAlias.ExitBleedout(9999.0, 1)
		Utility.Wait(2.0)
	endwhile
	if (ProcessingDeath || RequestedVendorAIState > 0)
		return false ;Will retry in a few seconds
	endif

	;Return items back to player
	FadeManagerAlias.FadeIn() ;Shouldn't be needed, but just in case
	VendorActor.RemoveAllItems(PlayerActor, true, true) ;Same here
	VendorChestAlias.GoToState("NoEvents")
	VendorChest.RemoveAllItems(PlayerActor, true, true)
	VendorChestAlias.GoToState("")

	;Done!
	UninstallCompleteMessage.Show()
	return true
endFunction
