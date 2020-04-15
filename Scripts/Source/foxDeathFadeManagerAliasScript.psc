Scriptname foxDeathFadeManagerAliasScript extends ReferenceAlias
{Pretty much just handles our screen fading. Exciting!}

float Property FadeTime = 2.0 AutoReadOnly

;Fade out our screen over FadeTime, then hold that fade after - see Fade:OnBeginState
;Latent - will wait until fully faded out
function FadeOut()
	GoToState("Fade")
endFunction

;Empty - implemented in Fade state (no fade to hold yet)
function HoldFade()
endFunction

;Empty - implemented in Fade state (nothing to fade in yet)
function FadeIn()
endFunction

;Actual fade state
state Fade
	;Implement empty state's FadeOut
	event OnBeginState()
		Game.FadeOutGame(true, true, 0.0, FadeTime + 0.2)
		Utility.Wait(FadeTime)
		HoldFade()
	endEvent

	;Continue holding our fade after game load
	event OnPlayerLoadGame()
		HoldFade()
	endEvent

	;Empty - implemented in empty state
	function FadeOut()
	endFunction

	;Hold our fade - this might expire if we get stuck in a wait loop in DeathQuest
	;But by then, we probably want to see what's going on anyway
	function HoldFade()
		Game.FadeOutGame(false, true, 60.0, FadeTime)
	endFunction

	;Fade in our screen over FadeTime
	;Instant - does not wait until faded in
	function FadeIn()
		GoToState("")
	endFunction

	;Implement FadeIn
	event OnEndState()
		Game.FadeOutGame(false, true, 0.0, FadeTime)
	endEvent
endState
