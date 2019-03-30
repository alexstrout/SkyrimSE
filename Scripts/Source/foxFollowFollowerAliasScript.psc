Scriptname foxFollowFollowerAliasScript extends ReferenceAlias
{Rewrite of FollowerAliasScript with rad new stuff - see DialogueFollowerScript too, which had to stay the same name}

;Begin Vanilla FollowerAliasScript Members
;DialogueFollowerScript Property DialogueFollower Auto
;GlobalVariable Property PlayerFollowerCount  Auto
;Faction Property CurrentHirelingFaction Auto
;End Vanilla FollowerAliasScript Members

foxFollowDialogueFollowerScript Property DialogueFollower Auto

Actor Property PlayerRef Auto
FormList Property LearnedSpellBookList Auto

int FollowerAdjSpeedMult
int FollowerAdjMagicka
int FollowerAdjMagickaCost

bool GlobTeleport
float GlobMaxDist
bool GlobAdjMagicka

float Property CombatWaitUpdateTime = 12.0 AutoReadOnly
float Property FollowUpdateTime = 4.5 AutoReadOnly

;Reset all FollowerAdj* values to 0
;This should never be needed, but called on DialogueFollower's SetFollowerAlias and RemoveFollowerAlias as a safeguard
function ResetAdjValues()
	FollowerAdjSpeedMult = 0
	FollowerAdjMagicka = 0
	FollowerAdjMagickaCost = 0
endFunction

;Update our cached global values so we don't have to call GetValue every update
;Currently called on DialogueFollower's CheckForModUpdate (and anywhere that's called - e.g. our OnActivate)
function UpdateGlobalValueCache()
	GlobTeleport = DialogueFollower.GlobalTeleport.GetValue() as bool
	GlobMaxDist = DialogueFollower.GlobalMaxDist.GetValue()
	GlobAdjMagicka = DialogueFollower.GlobalAdjMagicka.GetValue() as bool
endFunction

event OnUpdateGameTime()
	Actor ThisActor = Self.GetReference() as Actor
	if (!ThisActor)
		return
	endif

	;Per Vanilla - "kill the update if the follower isn't waiting anymore"
	;Not needed as we use RegisterForSingleUpdateGameTime instead
	;UnRegisterForUpdateGameTime()
	if (ThisActor.GetActorValue("WaitingForPlayer") == 1)
		DialogueFollower.DismissMultiFollower(Self, DialogueFollower.IsFollower(ThisActor), 5)
	endif
endEvent

event OnUnload()
	Actor ThisActor = Self.GetReference() as Actor
	if (!ThisActor)
		return
	endif

	;Per Vanilla - "if follower unloads while waiting for the player, wait three days then dismiss him"
	if (ThisActor.GetActorValue("WaitingForPlayer") == 1)
		DialogueFollower.FollowerMultiFollowWait(Self, DialogueFollower.IsFollower(ThisActor), 1)
	endif
endEvent

event OnCombatStateChanged(Actor akTarget, int aeCombatState)
	Actor ThisActor = Self.GetReference() as Actor

	if (akTarget == PlayerRef)
		DialogueFollower.DismissMultiFollower(Self, DialogueFollower.IsFollower(ThisActor), 0, 0)
	endif

	;HACK Begin registering combat check to fix getting stuck in combat (bug in bleedouts for animals)
	;This should be bloat-friendly as it will never fire more than once at a time, even if OnActivate is called multiple times in this time frame
	if (aeCombatState == 1)
		SetSpeedup(ThisActor, false)
		RegisterForSingleUpdate(CombatWaitUpdateTime)
	endif
endEvent

event OnDeath(Actor akKiller)
	;Just let DismissMultiFollower handle death via express dismissal - iMessage -1 tells DismissMultiFollower to skip any messages
	DialogueFollower.DismissMultiFollower(Self, DialogueFollower.IsFollower(Self.GetReference() as Actor), -1, 0)
endEvent

event OnItemAdded(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akSourceContainer)
	Book SomeBook = akBaseItem as Book
	if (SomeBook)
		AddBookSpell(SomeBook)
	endif
endEvent
function AddBookSpell(Book SomeBook, bool ShowMessage = true)
	Spell BookSpell = SomeBook.GetSpell()
	if (BookSpell)
		Actor ThisActor = Self.GetReference() as Actor
		if (!ThisActor.HasSpell(BookSpell))
			LearnedSpellBookList.AddForm(SomeBook)
			ThisActor.AddSpell(BookSpell)
			;Debug.Trace(ThisActor + " learning " + BookSpell + BookSpell.GetName())
			if (ShowMessage)
				;Debug.MessageBox("Follower learning " + BookSpell.GetName()) ;Temp until make message durr
				DialogueFollower.FollowerLearnSpellMessage.Show()
				DialogueFollower.FollowerLearnSpellSound.Play(PlayerRef)
			endif
			SetMinMagicka(ThisActor, BookSpell.GetMagickaCost())
		;else
		;	Debug.MessageBox("Follower already knows " + BookSpell.GetName() + "!")
		endif
	endif
endFunction

event OnItemRemoved(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akDestContainer)
	Book SomeBook = akBaseItem as Book
	if (SomeBook)
		RemoveBookSpell(SomeBook, RemoveCondition = LearnedSpellBookList.HasForm(SomeBook) && (Self.GetReference() as Actor).GetItemCount(akBaseItem) == 0)
	endif
endEvent
function RemoveBookSpell(Book SomeBook, bool ShowMessage = true, bool RemoveCondition = true)
	Spell BookSpell = SomeBook.GetSpell()
	if (BookSpell)
		Actor ThisActor = Self.GetReference() as Actor
		;Note: ThisActor could theoretically be None here if we're cleaning up an invalid alias
		;If this is the case, we're being called from RemoveAllBookSpells and LearnedSpellBookList will be reverted anyways, so we can safely skip this block
		if (RemoveCondition && ThisActor && ThisActor.HasSpell(BookSpell))
			LearnedSpellBookList.RemoveAddedForm(SomeBook)
			ThisActor.RemoveSpell(BookSpell)
			;Debug.Trace(ThisActor + " forgetting " + BookSpell + BookSpell.GetName())
			if (ShowMessage)
				;Debug.MessageBox("Follower forgetting " + BookSpell.GetName()) ;Temp until make message durr
				DialogueFollower.FollowerForgetSpellMessage.Show()
				DialogueFollower.FollowerForgetSpellSound.Play(PlayerRef)
			endif
			SetMinMagicka(ThisActor, BookSpell.GetMagickaCost(), true)
		endif
	endif
endFunction

Spell function GetNthBookSpell(int i)
	Book SomeBook = LearnedSpellBookList.GetAt(i) as Book
	if (SomeBook)
		return SomeBook.GetSpell()
	endif
	return None
endFunction

function AddAllBookSpells()
	;RemoveAllBookSpells first just in case we got out of sync somehow (should never happen! But doesn't hurt)
	;This isn't run often, so we can afford to be extra-cautious here
	RemoveAllBookSpells()

	Actor ThisActor = Self.GetReference() as Actor
	int i = ThisActor.GetNumItems()
	Book SomeBook = None
	while (i)
		i -= 1
		SomeBook = ThisActor.GetNthForm(i) as Book
		if (SomeBook)
			AddBookSpell(SomeBook, false)
		endif
	endwhile
endFunction

function RemoveAllBookSpells()
	int i = LearnedSpellBookList.GetSize()
	Book SomeBook = None
	while (i)
		i -= 1
		SomeBook = LearnedSpellBookList.GetAt(i) as Book
		if (SomeBook)
			RemoveBookSpell(SomeBook, false)
		endif
	endwhile

	;Fully revert just in case we missed any (we shouldn't! Unless our reference ended up None somehow. Oops!)
	LearnedSpellBookList.Revert()
endFunction

;Many followers have classes that don't put any weight into Magicka - so make sure we have the minimum required to at least cast a spell
function SetMinMagicka(Actor ThisActor, int cost = -1, bool enumSpellsOnEqualCost = false)
	;Factor in GlobAdjMagicka - if not desired, treat every spell as zero-cost (actually negative cost, so we force-check)
	;This way, existing code will either never set FollowerAdjMagicka, or clear it if previously set
	if (!GlobAdjMagicka)
		cost = -2
		enumSpellsOnEqualCost = false
	endif

	;If we already have the minimum required magicka to cast this spell, no changes are needed
	;Debug.Trace("foxFollowActor - magicka stuff starting...")
	if (cost >= 0 && cost < FollowerAdjMagickaCost)
		;Debug.Trace("foxFollowActor - magicka stuff skipping, too low - cost " + cost)
		return
	endif

	;Find our highest-cost spell if we didn't pass in cost, or if we had the highest cost (could be a different spell, but who cares)
	if (cost == -1 || (enumSpellsOnEqualCost && cost == FollowerAdjMagickaCost))
		FollowerAdjMagickaCost = 0
		cost = 0
		int i = LearnedSpellBookList.GetSize()
		Spell BookSpell = None
		while (i)
			i -= 1
			BookSpell = GetNthBookSpell(i)
			if (BookSpell)
				cost = BookSpell.GetMagickaCost()
				;Debug.Trace("foxFollowActor - magicka stuff found BookSpell cost " + cost + "\t" + BookSpell + BookSpell.GetName())
				if (cost > FollowerAdjMagickaCost)
					FollowerAdjMagickaCost = cost
				endif
			endif
		endwhile
		cost = FollowerAdjMagickaCost
	endif

	;Calculate our required magicka, and add that if necessary - also clear our old buff if no longer needed
	int reqMagicka = cost - ThisActor.GetBaseActorValue("Magicka") as int
	if (reqMagicka == FollowerAdjMagicka)
		return
	endif
	if (FollowerAdjMagicka)
		ThisActor.ModActorValue("Magicka", -FollowerAdjMagicka)
		;Debug.Trace("foxFollowActor - magicka stuff debuffing by old required minimum calc " + FollowerAdjMagicka)
		if (reqMagicka <= 0)
			FollowerAdjMagicka = 0
			FollowerAdjMagickaCost = 0
			;Debug.Trace("foxFollowActor - magicka stuff clearing and skipping, calc too low - cost " + cost + "\treqMagicka " + reqMagicka)
			return
		endif
	elseif (reqMagicka <= 0)
		;Debug.Trace("foxFollowActor - magicka stuff skipping, calc too low - cost " + cost + "\treqMagicka " + reqMagicka)
		return
	endif

	FollowerAdjMagicka = reqMagicka
	FollowerAdjMagickaCost = cost
	ThisActor.ModActorValue("Magicka", FollowerAdjMagicka)
	;Debug.Trace("foxFollowActor - magicka stuff buffing by required minimum calc " + FollowerAdjMagicka)
endFunction

;Track last follower activated so we have something to fall back on later
event OnActivate(ObjectReference akActivator)
	;Debug.Trace("foxFollowActor - activated! :|")
	if (akActivator == PlayerRef)
		;Debug.Trace("foxFollowActor - activated by Player! :D")
		DialogueFollower.CheckForModUpdate()
		DialogueFollower.UpdateFollowerCount()

		;Set CommandMode based on hotkey being held down
		int commandMode = 0
		if (DialogueFollower.RequestingCommandMode())
			commandMode = 1
			DialogueFollower.FollowerCommandModeMessage.Show()
		endif
		DialogueFollower.SetCommandMode(commandMode)

		;Set ourself as the preferred follower until we've quit gabbing
		;CommandMode will also stay valid during this time, until either consumed by a command or cleared by ClearCommandMode
		Actor ThisActor = Self.GetReference() as Actor
		SetMinMagicka(ThisActor, FollowerAdjMagickaCost)
		DialogueFollower.SetPreferredFollowerAlias(ThisActor)
		;Debug.Trace("foxFollowActor - finished being activated by Player :(")
	endif
endEvent

event OnUpdate()
	Actor ThisActor = Self.GetReference() as Actor
	if (!ThisActor)
		RegisterForSingleUpdate(CombatWaitUpdateTime)
		return
	endif

	;Register for longer-interval update as long as we're in combat
	;Otherwise use a shorter-interval update to handle catchup
	if (ThisActor.IsInCombat())
		;If we've exited combat then actually stop combat - this fixes perma-bleedout issues
		if (!PlayerRef.IsInCombat())
			ThisActor.StopCombat()
		endif
	elseif (GlobMaxDist > 0.0 \
	&& ThisActor.GetActorValue("WaitingForPlayer") == 0 \
	&& !ThisActor.IsDoingFavor())
		float maxDist = GlobMaxDist ;4096.0
		if (!PlayerRef.HasLOS(ThisActor))
			maxDist *= 0.5
		endif
		float dist = ThisActor.GetDistance(PlayerRef)
		if (GlobTeleport && dist > maxDist && !PlayerRef.IsOnMount())
			;Ideally, we'd teleport to the nearest nav node behind player, but that's not exposed to papyrus as far as I can tell
			;However, if we teleport into the ground, Skyrim will eventually place us somewhere valid
			;Where's Unreal's LastAnchor property when you need it? :|
			;Teleporting 32 units above player allows some leeway with slopes while preventing too many falling noises
			float aZ = PlayerRef.GetAngleZ()
			ThisActor.Disable(false)
			ThisActor.MoveTo(PlayerRef, -192.0 * Math.Sin(aZ), -192.0 * Math.Cos(aZ), 32.0, true)
			ThisActor.Enable(true)
			ThisActor.EvaluatePackage()
			SetSpeedup(ThisActor, false)
			;Debug.Trace("foxFollowActor - initiating hyperjump!")
		else
			SetSpeedup(ThisActor, dist > maxDist * 0.5)
		endif

		RegisterForSingleUpdate(FollowUpdateTime)
		return
	else
		SetSpeedup(ThisActor, false)
	endif

	RegisterForSingleUpdate(CombatWaitUpdateTime)
endEvent

function SetSpeedup(Actor ThisActor, bool punchIt)
	if (punchIt)
		;This will compound over time until we actually catch up - 2x, 3x, 4x... 88x. lols
		if (FollowerAdjSpeedMult > 8700)
			return
		endif

		FollowerAdjSpeedMult += 100
		ThisActor.ModActorValue("SpeedMult", 100.0)
		ApplySpeedMult(ThisActor)
		;Debug.Trace("foxFollowActor - initiating warp speed... Mach " + FollowerAdjSpeedMult)
	elseif (FollowerAdjSpeedMult)
		ThisActor.ModActorValue("SpeedMult", -FollowerAdjSpeedMult)
		FollowerAdjSpeedMult = 0
		ApplySpeedMult(ThisActor)
		;Debug.Trace("foxFollowActor - dropping to impulse power")
	endif
endFunction
function ApplySpeedMult(Actor ThisActor)
	;CarryWeight must be adjusted for SpeedMult to apply
	float wt = ThisActor.GetBaseActorValue("CarryWeight")
	ThisActor.SetActorValue("CarryWeight", wt + 1.0)
	ThisActor.SetActorValue("CarryWeight", wt)
endFunction
