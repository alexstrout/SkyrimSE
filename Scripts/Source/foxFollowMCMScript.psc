scriptname foxFollowMCMScript extends SKI_ConfigBase

foxFollowDialogueFollowerScript Property DialogueFollower Auto

int MaxFollowersSliderID = 0
float MaxFollowersSliderValue = 0.0
float Property MaxFollowersSliderDefaultValue = 3.0 AutoReadOnly
string Property MaxFollowersSliderFormat = "{0} Followers" AutoReadOnly

int MaxDistSliderID = 0
float MaxDistSliderValue = 0.0
float Property MaxDistSliderDefaultValue = 4096.0 AutoReadOnly
string Property MaxDistSliderFormat = "{0} Units" AutoReadOnly

int TeleportToggleID
bool TeleportToggleValue = false
bool Property TeleportToggleDefaultValue = true AutoReadOnly

int AdjMagickaToggleID
bool AdjMagickaToggleValue = false
bool Property AdjMagickaToggleDefaultValue = true AutoReadOnly

int DismissFollowersToggleID
bool DismissFollowersToggleValue = false
bool Property DismissFollowersToggleDefaultValue = false AutoReadOnly

event OnPageReset(string page)
	SetCursorFillMode(TOP_TO_BOTTOM)
	AddHeaderOption("Options")

	MaxFollowersSliderValue = DialogueFollower.GlobalMaxFollowers.GetValue()
	MaxFollowersSliderID = AddSliderOption("Max Follower Count", MaxFollowersSliderValue, MaxFollowersSliderFormat)

	MaxDistSliderValue = DialogueFollower.GlobalMaxDist.GetValue()
	MaxDistSliderID = AddSliderOption("Speed-Up / Teleport Distance", MaxDistSliderValue, MaxDistSliderFormat)

	TeleportToggleValue = DialogueFollower.GlobalTeleport.GetValue() as bool
	TeleportToggleID = AddToggleOption("Allow Teleport", TeleportToggleValue)

	AdjMagickaToggleValue = DialogueFollower.GlobalAdjMagicka.GetValue() as bool
	AdjMagickaToggleID = AddToggleOption("Adjust Follower Magicka", AdjMagickaToggleValue)

	AddEmptyOption()
	AddHeaderOption("Uninstall")

	DismissFollowersToggleValue = DismissFollowersToggleDefaultValue
	DismissFollowersToggleID = AddToggleOption("Dismiss Followers", DismissFollowersToggleValue)
endEvent

event OnOptionHighlight(int option)
	if (option == MaxFollowersSliderID)
		SetInfoText("Maximum allowed followers. (Only applies to new followers.)" \
			+ "\nDefault: 3 Followers")
	elseif (option == MaxDistSliderID)
		SetInfoText("Follower teleport distance. Speed-up distance is half this number." \
			+ "\n0 Units: Nearly constant teleporting. Oops!" \
			+ "\nNegative Units: Completely disable speed-up / teleport functionality." \
			+ "\nDefault: 4096 Units")
	elseif (option == TeleportToggleID)
		SetInfoText("Allow follower teleporting?" \
			+ "\nDisable if you'd still like them to speed up without magically teleporting." \
			+ "\nDefault: True")
	elseif (option == AdjMagickaToggleID)
		SetInfoText("Allow follower magicka adjustment for learned spells?" \
			+ "\nMost vanilla followers have 50 magicka regardless of level, rendering them unable to cast heavier spells." \
			+ "\nIf enabled, their maximum magicka is adjusted up to match the most expensive spell they currently know." \
			+ "\nDefault: True")
	elseif (option == DismissFollowersToggleID)
		SetInfoText("Dismiss all followers?" \
			+ "\nTo uninstall, please first dismiss all followers by checking this toggle. (Takes effect on closing config menu.)" \
			+ "\nOtherwise, they will permanently remember spell tomes, and may be stuck in a follow state. Please avoid doing this!" \
			+ "\nDefault: False")
	endif
endEvent

event OnOptionDefault(int option)
	if (option == MaxFollowersSliderID)
		OnOptionSliderAccept(option, MaxFollowersSliderDefaultValue)
	elseif (option == MaxDistSliderID)
		OnOptionSliderAccept(option, MaxDistSliderDefaultValue)
	elseif (option == TeleportToggleID && TeleportToggleValue != TeleportToggleDefaultValue)
		OnOptionSelect(option)
	elseif (option == AdjMagickaToggleID && AdjMagickaToggleValue != AdjMagickaToggleDefaultValue)
		OnOptionSelect(option)
	elseif (option == DismissFollowersToggleID && DismissFollowersToggleValue != DismissFollowersToggleDefaultValue)
		OnOptionSelect(option)
	endif
endEvent

event OnOptionSliderOpen(int option)
	if (option == MaxFollowersSliderID)
		SetSliderDialogStartValue(MaxFollowersSliderValue)
		SetSliderDialogDefaultValue(MaxFollowersSliderDefaultValue)
		SetSliderDialogRange(0.0, 10.0)
		SetSliderDialogInterval(1.0)
	elseif (option == MaxDistSliderID)
		SetSliderDialogStartValue(MaxDistSliderValue)
		SetSliderDialogDefaultValue(MaxDistSliderDefaultValue)
		SetSliderDialogRange(-1024.0, 16384.0)
		SetSliderDialogInterval(1024.0)
	endif
endEvent

event OnOptionSliderAccept(int option, float value)
	if (option == MaxFollowersSliderID)
		DialogueFollower.GlobalMaxFollowers.SetValue(value)
		MaxFollowersSliderValue = value
		SetSliderOptionValue(MaxFollowersSliderID, MaxFollowersSliderValue, MaxFollowersSliderFormat)
	elseif (option == MaxDistSliderID)
		DialogueFollower.GlobalMaxDist.SetValue(value)
		MaxDistSliderValue = value
		SetSliderOptionValue(MaxDistSliderID, MaxDistSliderValue, MaxDistSliderFormat)
	endif
endEvent

event OnOptionSelect(int option)
	if (option == TeleportToggleID)
		TeleportToggleValue = !TeleportToggleValue
		DialogueFollower.GlobalTeleport.SetValue(TeleportToggleValue as float)
		SetToggleOptionValue(TeleportToggleID, TeleportToggleValue)
	elseif (option == AdjMagickaToggleID)
		AdjMagickaToggleValue = !AdjMagickaToggleValue
		DialogueFollower.GlobalAdjMagicka.SetValue(AdjMagickaToggleValue as float)
		SetToggleOptionValue(AdjMagickaToggleID, AdjMagickaToggleValue)
	elseif (option == DismissFollowersToggleID)
		DismissFollowersToggleValue = !DismissFollowersToggleValue
		SetToggleOptionValue(DismissFollowersToggleID, DismissFollowersToggleValue)
	endif
endEvent

event OnConfigClose()
	RegisterForSingleUpdate(1.0) ;Wait until menu fully closed
endEvent

event OnUpdate()
	if (DismissFollowersToggleValue)
		DialogueFollower.SetCommandMode(1)
		DialogueFollower.DismissMultiFollower(None, true) ;isFollower N/A in CommandMode
	endif
	DialogueFollower.CheckForModUpdate() ;Propegate new GVs to all followers
endEvent
