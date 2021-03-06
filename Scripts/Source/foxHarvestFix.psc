Scriptname foxHarvestFix Hidden
{Simple wrapper functions to abstract the ObjectReference "hooks"}

;Check if we're a valid HarvestFix target - if false, we're either not a plant or shouldn't have respawned yet
bool function IsValidHarvestRef(ObjectReference akRef, float afLastActivateTime) global
	;As IsHarvested is implemented for all ObjectReference types (hence "hooking" ObjectReference), we can simply call this function to determine if we:
	;	A) Are a valid plant (e.g. Flora / TreeObject reference, or anything else that supports IsHarvested)
	;	B) Have actually been harvested (no point in caring if we haven't!)
	;Note: Some ObjectReferences may not actually reference anything, and thus can't call native methods on themselves - so IsHarvested() can fail
	;As our "hooked" functions would otherwise be empty calls anyway, this appears harmless (other than printing an error to log)
	return akRef.IsHarvested() \
		&& (afLastActivateTime <= 0.0 || Utility.GetCurrentGameTime() > afLastActivateTime + 10.0) ;Adjust this last number to your desired respawn time in days (e.g. 3.0 = 3 days, 0.125 = 3 hours)
endFunction

;Process our OnActivate "hook" - our "foxHarvestFixLastActivateTime" in ObjectReference should both be passed as afLastActivateTime AND assigned the result of this function (so it may be updated)
float function OnActivate(ObjectReference akRef, float afLastActivateTime) global
	;If we're a valid HarvestFix target (we're a plant, and ready to be harvested), return our current game time
	if (IsValidHarvestRef(akRef, afLastActivateTime))
		return Utility.GetCurrentGameTime()
	endif
	;Otherwise, just return whatever afLastActivateTime was (so that the value remains unchanged)
	return afLastActivateTime
endFunction

;Brutal harvest fix here - don't try this at home! ... Wait
function OnCellAttach(ObjectReference akRef, float afLastActivateTime = -1.0) global
	if (IsValidHarvestRef(akRef, afLastActivateTime))
		;Unfortunately, SetHarvested seems to have an upper limit (10?) on how many meshes it can update at once
		;Disable/enable works fine, but having to disable/enable parent objects (e.g. all of Breezehome) is a bit awkward with Havoc objects flying about
		;However, we can nicely sidestep this with a quasi-unique wait time based on our Reference FormID (clamped to some reasonable time)
		;Absolute worst case, we miss a plant or two - I think this is an acceptable tradeoff for its simplicity and speed
		;Debug.Trace(akRef + " FormID " + akRef.GetFormID() + " was harvested OnCellAttach (" + akRef.GetBaseObject().GetName() + ")")
		Utility.Wait(Math.abs((akRef.GetFormID() % 2048) / 640.0)) ;3.2s max wait time
		akRef.SetHarvested(false)

		;Listen for future OnActivate events on these refs only
		;Otherwise, unrelated objects can get stuck repeatedly activating iff they:
		;	A) Activate themselves from their own OnActivate
		;	B) Do this from within a non-empty state
		;	C) Depend on another state (or empty state) to "block" another OnActivate event
		;	D) Don't define an empty OnActivate in said state (since it expects ObjectReference's to be empty)
		;This keeps empty state's OnActivate blank as expected so we don't break that contract
		;There are some drawbacks:
		;	A) Potential incompatibility if another script explicitly checks for empty state on this ref (unlikely, but worth noting)
		;	B) This ref gets tagged w/ "foxHarvestFixReceiveOnActivate" state in saves (harmless aside from above point)
		;	C) We get one instant respawn from initial harvests, since we're checking IsHarvested to arrive here in the first place
		;Of course, you can avoid this entirely by just using the instant-respawn variant, which does not touch saves or OnActivate at all :P
		if (afLastActivateTime >= 0.0 && akRef.GetState() == "")
			akRef.GoToState("foxHarvestFixReceiveOnActivate")
		endif
	endif
endFunction
