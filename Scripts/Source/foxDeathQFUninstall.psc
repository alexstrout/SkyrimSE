;BEGIN FRAGMENT CODE - Do not edit anything between this and the end comment
;NEXT FRAGMENT INDEX 1
Scriptname foxDeathQFUninstall Extends Quest Hidden

;BEGIN ALIAS PROPERTY FadeManagerAlias
;ALIAS PROPERTY TYPE ReferenceAlias
ReferenceAlias Property Alias_FadeManagerAlias Auto
;END ALIAS PROPERTY

;BEGIN ALIAS PROPERTY PlayerAlias
;ALIAS PROPERTY TYPE ReferenceAlias
ReferenceAlias Property Alias_PlayerAlias Auto
;END ALIAS PROPERTY

;BEGIN ALIAS PROPERTY VendorDestination
;ALIAS PROPERTY TYPE LocationAlias
LocationAlias Property Alias_VendorDestination Auto
;END ALIAS PROPERTY

;BEGIN ALIAS PROPERTY VendorChestAlias
;ALIAS PROPERTY TYPE ReferenceAlias
ReferenceAlias Property Alias_VendorChestAlias Auto
;END ALIAS PROPERTY

;BEGIN ALIAS PROPERTY VendorAlias
;ALIAS PROPERTY TYPE ReferenceAlias
ReferenceAlias Property Alias_VendorAlias Auto
;END ALIAS PROPERTY

;BEGIN ALIAS PROPERTY ItemManagerAlias
;ALIAS PROPERTY TYPE ReferenceAlias
ReferenceAlias Property Alias_ItemManagerAlias Auto
;END ALIAS PROPERTY

;BEGIN FRAGMENT Fragment_0
Function Fragment_0()
;BEGIN AUTOCAST TYPE foxDeathQuestScript
Quest __temp = self as Quest
foxDeathQuestScript kmyQuest = __temp as foxDeathQuestScript
;END AUTOCAST
;BEGIN CODE
	while (!kmyQuest.UninstallMod())
		Utility.Wait(5.0)
	endwhile
;END CODE
EndFunction
;END FRAGMENT

;END FRAGMENT CODE - Do not edit anything between this and the begin comment
