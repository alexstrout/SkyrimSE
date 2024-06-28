scriptname foxFollowMCMScript extends SKI_ConfigBase

foxFollowDialogueFollowerScript Property DialogueFollower Auto

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

event OnPageReset(string page)
	SetCursorFillMode(TOP_TO_BOTTOM)

	MaxDistSliderValue = DialogueFollower.GlobalMaxDist.GetValue()
	MaxDistSliderID = AddSliderOption("Speed-Up / Teleport Distance", MaxDistSliderValue, MaxDistSliderFormat)

	TeleportToggleValue = DialogueFollower.GlobalTeleport.GetValue() as bool
	TeleportToggleID = AddToggleOption("Allow Teleport", TeleportToggleValue)

	AdjMagickaToggleValue = DialogueFollower.GlobalAdjMagicka.GetValue() as bool
	AdjMagickaToggleID = AddToggleOption("Adjust Follower Magicka", AdjMagickaToggleValue)
endEvent

event OnOptionHighlight(int option)
	if (option == MaxDistSliderID)
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
	endif
endEvent

event OnOptionDefault(int option)
	if (option == MaxDistSliderID)
		OnOptionSliderAccept(option, MaxDistSliderDefaultValue)
	elseif (option == TeleportToggleID && TeleportToggleValue != TeleportToggleDefaultValue)
		OnOptionSelect(option)
	elseif (option == AdjMagickaToggleID && AdjMagickaToggleValue != AdjMagickaToggleDefaultValue)
		OnOptionSelect(option)
	endif
endEvent

event OnOptionSliderOpen(int option)
	if (option == MaxDistSliderID)
		SetSliderDialogStartValue(MaxDistSliderValue)
		SetSliderDialogDefaultValue(MaxDistSliderDefaultValue)
		SetSliderDialogRange(-1024.0, 16384.0)
		SetSliderDialogInterval(1024.0)
	endif
endEvent

event OnOptionSliderAccept(int option, float value)
	if (option == MaxDistSliderID)
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
	endif
endEvent
