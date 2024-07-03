scriptname foxDeathMCMScript extends SKI_ConfigBase

foxDeathQuestScript Property DeathQuest Auto

int MaxDistSliderID = 0
float MaxDistSliderValue = 0.0
float Property MaxDistSliderDefaultValue = 4096.0 AutoReadOnly
string Property MaxDistSliderFormat = "{0} Units" AutoReadOnly
int ReviveTimeSliderID = 0
float ReviveTimeSliderValue = 0.0
float Property ReviveTimeSliderDefaultValue = 0.0 AutoReadOnly
string Property ReviveTimeSliderFormat = "{0} Seconds" AutoReadOnly

string[] DifficultySettingList
int DifficultySettingMenuID = 0
int DifficultySettingMenuValue = 0
int Property DifficultySettingMenuDefaultValue = 1 AutoReadOnly

int AllowSellbackToggleID
bool AllowSellbackToggleValue = false
bool Property AllowSellbackToggleDefaultValue = false AutoReadOnly

int QuestActiveToggleID
bool QuestActiveToggleValue = false
bool Property QuestActiveToggleDefaultValue = true AutoReadOnly

event OnConfigInit()
	DifficultySettingList = new string[4]
	DifficultySettingList[0] = " Easy "
	DifficultySettingList[1] = " Normal "
	DifficultySettingList[2] = " Hard "
	DifficultySettingList[3] = " Brutal "
endEvent

event OnPageReset(string page)
	SetCursorFillMode(TOP_TO_BOTTOM)
	AddHeaderOption("Options")

	MaxDistSliderValue = DeathQuest.FollowerFinderMaxDist.GetValue()
	MaxDistSliderID = AddSliderOption("Maximum Revive Distance", MaxDistSliderValue, MaxDistSliderFormat)
	ReviveTimeSliderValue = DeathQuest.MinReviveTime.GetValue()
	ReviveTimeSliderID = AddSliderOption("Minimum Revive Time", ReviveTimeSliderValue, ReviveTimeSliderFormat)

	DifficultySettingMenuValue = DeathQuest.DifficultySetting.GetValue() as int + 1
	if (DifficultySettingMenuValue < 0)
		DifficultySettingMenuValue = 0
	elseif (DifficultySettingMenuValue > 3)
		DifficultySettingMenuValue = 3
	endif
	DifficultySettingMenuID = AddMenuOption("Difficulty", DifficultySettingList[DifficultySettingMenuValue])

	AllowSellbackToggleValue = DeathQuest.AllowSellback.GetValue() as bool
	AllowSellbackToggleID = AddToggleOption("Vendor Sellback", AllowSellbackToggleValue)

	AddEmptyOption()
	AddHeaderOption("Uninstall")

	QuestActiveToggleValue = DeathQuest.IsRunning()
	QuestActiveToggleID = AddToggleOption("Quest Running", QuestActiveToggleValue)
endEvent

event OnOptionHighlight(int option)
	if (option == MaxDistSliderID)
		SetInfoText("Allies within this distance will prevent you from being fully defeated." \
			+ "\n0 Units: No range, always defeated." \
			+ "\nNegative Units: Infinite range, never defeated." \
			+ "\nDefault: 4096 Units")
	elseif (option == ReviveTimeSliderID)
		SetInfoText("Minimum time to allow revive from bleedout via healing." \
			+ "\nFor example, Wintersun's Arkayn Cycle can still revive you if this is set to 1 second or more." \
			+ "\nIt's recommended to leave this at 0, especially if you are immediately reviving for no reason." \
			+ "\nDefault: 0 Seconds")
	elseif (option == DifficultySettingMenuID)
		SetInfoText("Easy: No changes on defeat." \
			+ "\nNormal: Clear vendor gold on defeat." \
			+ "\nHard: Clear previously confiscated non-quest equipment on defeat. (Souls-ish)" \
			+ "\nBrutal: Clear ALL confiscated non-quest equipment on defeat. Careful!" \
			+ "\nDefault: Normal")
	elseif (option == AllowSellbackToggleID)
		SetInfoText("Allow selling items back to vendor?" \
			+ "\nIf disabled, there is effectively no difference between Easy and Normal." \
			+ "\nDefault: False")
	elseif (option == QuestActiveToggleID)
		SetInfoText("Quest running?" \
			+ "\nTo uninstall, please first stop the quest by unchecking this toggle. (Takes effect on closing config menu.)" \
			+ "\nThis will recover all items from the vendor and stop all effects. Please do this before uninstalling!" \
			+ "\nDefault: True")
	endif
endEvent

event OnOptionDefault(int option)
	if (option == MaxDistSliderID)
		OnOptionSliderAccept(option, MaxDistSliderDefaultValue)
	elseif (option == ReviveTimeSliderID)
		OnOptionSliderAccept(option, ReviveTimeSliderDefaultValue)
	elseif (option == DifficultySettingMenuID)
		OnOptionMenuAccept(option, DifficultySettingMenuDefaultValue)
	elseif (option == AllowSellbackToggleID && AllowSellbackToggleValue != AllowSellbackToggleDefaultValue)
		OnOptionSelect(option)
	elseif (option == QuestActiveToggleID && QuestActiveToggleValue != QuestActiveToggleDefaultValue)
		OnOptionSelect(option)
	endif
endEvent

event OnOptionSliderOpen(int option)
	if (option == MaxDistSliderID)
		SetSliderDialogStartValue(MaxDistSliderValue)
		SetSliderDialogDefaultValue(MaxDistSliderDefaultValue)
		SetSliderDialogRange(-1024.0, 16384.0)
		SetSliderDialogInterval(1024.0)
	elseif (option == ReviveTimeSliderID)
		SetSliderDialogStartValue(ReviveTimeSliderValue)
		SetSliderDialogDefaultValue(ReviveTimeSliderDefaultValue)
		SetSliderDialogRange(0.0, 30.0)
		SetSliderDialogInterval(1.0)
	endif
endEvent

event OnOptionMenuOpen(int option)
	if (option == DifficultySettingMenuID)
		SetMenuDialogOptions(DifficultySettingList)
		SetMenuDialogStartIndex(DifficultySettingMenuValue)
		SetMenuDialogDefaultIndex(DifficultySettingMenuDefaultValue)
	endif
endEvent

event OnOptionSliderAccept(int option, float value)
	if (option == MaxDistSliderID)
		DeathQuest.FollowerFinderMaxDist.SetValue(value)
		MaxDistSliderValue = value
		SetSliderOptionValue(MaxDistSliderID, MaxDistSliderValue, MaxDistSliderFormat)
	elseif (option == ReviveTimeSliderID)
		DeathQuest.MinReviveTime.SetValue(value)
		ReviveTimeSliderValue = value
		SetSliderOptionValue(ReviveTimeSliderID, ReviveTimeSliderValue, ReviveTimeSliderFormat)
	endif
endEvent

event OnOptionMenuAccept(int option, int index)
	if (option == DifficultySettingMenuID)
		DeathQuest.DifficultySetting.SetValue(index - 1)
		DifficultySettingMenuValue = index
		SetMenuOptionValue(DifficultySettingMenuID, DifficultySettingList[DifficultySettingMenuValue])
	endif
endEvent

event OnOptionSelect(int option)
	if (option == AllowSellbackToggleID)
		AllowSellbackToggleValue = !AllowSellbackToggleValue
		DeathQuest.AllowSellback.SetValue(AllowSellbackToggleValue as float)
		SetToggleOptionValue(AllowSellbackToggleID, AllowSellbackToggleValue)
	elseif (option == QuestActiveToggleID)
		QuestActiveToggleValue = !QuestActiveToggleValue
		SetToggleOptionValue(QuestActiveToggleID, QuestActiveToggleValue)
	endif
endEvent

event OnConfigClose()
	RegisterForSingleUpdate(1.0) ;Wait until menu fully closed
endEvent

event OnUpdate()
	if (DeathQuest.IsRunning())
		if (!QuestActiveToggleValue)
			DeathQuest.Stop()
		endif
	elseif (QuestActiveToggleValue)
		DeathQuest.Start()
	endif
endEvent
