Scriptname foxDeathPlayerAliasScript extends ReferenceAlias
{Derpy script that handles bleedout}

Quest Property FollowerFinderQuest Auto
ReferenceAlias Property VendorAlias Auto
ReferenceAlias Property VendorChestAlias Auto

float Property BleedoutUpdateTime = 0.1 AutoReadOnly
float Property FollowerFinderUpdateGameTime = 0.05 AutoReadOnly

float HealthToHealTo = 0.0
bool IsProcessingDeath = false
bool WaitingForCellLoad = false

event OnEnterBleedout()
	;If we don't exist or already have NoBleedoutRecovery set (e.g. some other death-handling event is happening?), bail immediately
	Actor ThisActor = Self.GetReference() as Actor
	if (!ThisActor || ThisActor.GetNoBleedoutRecovery())
		return
	endif

	;Player bleedout is weird, so SetNoBleedoutRecovery and start manually ticking up our health
	ThisActor.SetNoBleedoutRecovery(true)
	HealthToHealTo = 10.0
	RegisterForSingleUpdate(BleedoutUpdateTime)

	;Also start checking for nearby friendlies via FollowerFinderQuest
	RegisterForSingleUpdateGameTime(FollowerFinderUpdateGameTime)
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
		float adjHealth = ThisActor.GetActorValue("Health") - HealthToHealTo
		if (adjHealth > 0.0)
			ThisActor.DamageActorValue("Health", adjHealth)
		endif

		HealthToHealTo = 0.0
		return
	endif

	;Otherwise, slowly heal up (just heal the amount of our update interval)
	ThisActor.RestoreActorValue("Health", BleedoutUpdateTime)
	RegisterForSingleUpdate(BleedoutUpdateTime)
endEvent

event OnUpdateGameTime()
	if (IsProcessingDeath || FollowerFinderQuest.IsRunning())
		return
	endif
	Actor ThisActor = Self.GetReference() as Actor
	if (!ThisActor)
		return
	endif

	;TODO Debug test
	HandleDeath(ThisActor)
	return

	;If we don't have any around, then bail and handle our actual death
	FollowerFinderQuest.Start()
	if (!(FollowerFinderQuest.GetAlias(0) as ReferenceAlias).GetReference())
		FollowerFinderQuest.Stop()
		HandleDeath(ThisActor)
		return
	endif

	FollowerFinderQuest.Stop()
	RegisterForSingleUpdateGameTime(FollowerFinderUpdateGameTime)
endEvent

function HandleDeath(Actor ThisActor)
	IsProcessingDeath = true
	UnRegisterForUpdate()
	UnRegisterForUpdateGameTime()
	;Debug.MessageBox("You died")

	;ThisActor.ForceActorValue("Health", 1.0)
	;while (!Self.TryToClear())
	;	Utility.Wait(0.1)
	;endwhile
	;Utility.Wait(0.5)
	;ThisActor.Kill()

	Actor VendorActor = VendorAlias.GetReference() as Actor
	ObjectReference VendorChest = VendorAlias.GetReference()
	if (!VendorActor || !VendorChest)
		IsProcessingDeath = false
		RegisterForSingleUpdate(BleedoutUpdateTime)
		return
	endif

	Game.FadeOutGame(true, true, 0.0, 2.2)
	Utility.Wait(2.0)

	Game.FadeOutGame(false, true, 60.0, 0.0)
	;ThisActor.RemoveAllItems(VendorChest, true, false)
	;StripItems(ThisActor, VendorChest)
	;StripItems(VendorChest, ThisActor)
	ThisActor.UnequipAll()
	VendorActor.Disable(false)
	VendorActor.MoveTo(ThisActor, 0.0, 0.0, 0.0, true)
	ApplySpeedMult(VendorActor, 200.0)
	VendorActor.Enable(false)
	VendorActor.EvaluatePackage()
	Utility.Wait(8.0)

	HealthToHealTo = 30.0
	ThisActor.RestoreActorValue("Health", Math.abs(ThisActor.GetActorValue("Health")) + HealthToHealTo)
	RegisterForSingleUpdate(BleedoutUpdateTime)
	Utility.Wait(BleedoutUpdateTime + 1.0)

	ApplySpeedMult(VendorActor, 100.0)
	FullTeleport(ThisActor, VendorActor)
	while (WaitingForCellLoad)
		FullTeleport(ThisActor, VendorActor)
	endwhile

	GetOwningQuest().SetStage(1)
	VendorActor.EvaluatePackage()
	Game.FadeOutGame(false, true, 0.0, 2.0)
	Utility.Wait(2.0)

	GetOwningQuest().SetStage(2)
	VendorActor.EvaluatePackage()
	Utility.Wait(10.0)

	while (VendorActor.IsInDialogueWithPlayer())
		Utility.Wait(1.0)
	endwhile

	GetOwningQuest().Reset()
	VendorActor.EvaluatePackage()
	Utility.Wait(5.0)

	VendorActor.Disable(true)
	VendorActor.MoveToMyEditorLocation()
	VendorActor.Enable(false)

	IsProcessingDeath = false
endFunction
function ApplySpeedMult(Actor VendorActor, float SpeedMult)
	VendorActor.SetActorValue("SpeedMult", SpeedMult)

	;CarryWeight must be adjusted for SpeedMult to apply
	VendorActor.ModActorValue("CarryWeight", 1.0)
	VendorActor.ModActorValue("CarryWeight", -1.0)
endFunction
function FullTeleport(Actor ThisActor, Actor VendorActor)
	VendorActor.Disable(false)
	ThisActor.MoveTo(VendorActor, 0.0, 0.0, 0.0, true)
	VendorActor.Enable(false)
	Utility.Wait(1.0)
	if (!ThisActor.GetParentCell() \
	|| !ThisActor.Is3DLoaded() \
	|| !VendorActor.Is3DLoaded())
		WaitingForCellLoad = true
	endif
endFunction

event OnObjectUnequipped(Form akBaseObject, ObjectReference akReference)
	if (IsProcessingDeath)
		int count = akBaseObject.GetType()
		if (count == 42) ;kAmmo
			count = Self.GetReference().GetItemCount(akBaseObject)
			count = Utility.RandomInt(count / 2, count)
		else
			count = 1
		endif
		Self.GetReference().RemoveItem(akBaseObject, count, true, VendorChestAlias.GetReference())
	endif
endEvent

event OnCellLoad()
	WaitingForCellLoad = false
endEvent

; function StripItems(Actor ThisActor, ObjectReference VendorChest, int minValue = 50)
; 	int i = ThisActor.GetNumItems()
; 	Form SomeForm = None
; 	int value
; 	while i
; 		i -= 1
; 		SomeForm = ThisActor.GetNthForm(i)
; 		value = SomeForm.GetGoldValue()
; 		if (value == 0 || value > Utility.RandomInt(1, minValue))
; 			ThisActor.RemoveItem(SomeForm, Utility.RandomInt(1, Math.Floor(ThisActor.GetItemCount(SomeForm) * 1.5)), true, VendorChest)
; 		endif
; 	endwhile
; endFunction
; function StripItems(ObjectReference SourceRef, ObjectReference DestionationRef)
; 	int i = SourceRef.GetNumItems()
; 	Form SomeForm = None
; 	int type
; 	while i
; 		i -= 1
; 		SomeForm = SourceRef.GetNthForm(i)
; 		type = SomeForm.GetType()
; 		;eturn kKey
; 		if (type == 45)
; 			SourceRef.RemoveItem(SomeForm, SourceRef.GetItemCount(SomeForm), true, DestionationRef)
; 		endif
; 	endwhile
; endFunction
