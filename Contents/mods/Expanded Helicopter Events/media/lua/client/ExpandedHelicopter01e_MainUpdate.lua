require "ExpandedHelicopter01c_MainCore"
require "ExpandedHelicopter01a_MainVariables"
require "ExpandedHelicopter01b_MainSounds"

function eHelicopter:update()

	if self.state == "following" then
		return
	end

	if (self.state == "arrived" or self.state == "gotoTarget") and ((not self.target) or (not self.trueTarget)) then

		if (not self.target) then
			print(" - EHE: ERR: "..self:heliToString().." no target in update()")
		end
		if (not self.trueTarget) then
			print(" - EHE: ERR: "..self:heliToString().." no trueTarget in update()")
		end

		self.trueTarget = self:findTarget(self.attackDistance, "update")
		self.target = self.trueTarget
		self:setTargetPos()
		return
	end

	local timeStampMS = getTimestampMs()
	local thatIsCloseEnough = ((self.topSpeedFactor*self.speed)*tonumber(getGameSpeed()))+4
	local distanceToTrueTarget = self:getDistanceToIsoObject(self.trueTarget)

	--if trueTarget is within range
	if distanceToTrueTarget and (distanceToTrueTarget <= (self.attackDistance*4)) then
		--if trueTarget is outside then sync targets
		if self.trueTarget:isOutside() then
			if (distanceToTrueTarget <= self.attackDistance*2) then
				if (self.target ~= self.trueTarget) then
					self.target = self.trueTarget
					eventSoundHandler:playEventSound(self, "foundTarget")
				end
				self.timeSinceLastSeenTarget = timeStampMS
			end
		else
			--prevent constantly changing targets during roaming
			if (self.timeSinceLastRoamed < timeStampMS) then
				self.timeSinceLastRoamed = timeStampMS+10000 --10 seconds

				--random offset used for roaming
				local offset = self.attackDistance
				if self.crashing then
					offset = math.floor(offset*(ZombRand(13,26)/10))
				end
				local randOffset = {-offset,offset}

				local tx = self.trueTarget:getX()
				--50% chance to offset x
				if ZombRand(1,101) <= 50 then
					--pick from randOffset, 50% negative or positive
					tx = tx+randOffset[ZombRand(1,#randOffset+1)]
				end
				local ty = self.trueTarget:getY()
				--50% chance to offset y
				if ZombRand(1,101) <= 50 then
					--pick from randOffset, 50% negative or positive
					tx = tx+randOffset[ZombRand(1,#randOffset+1)]
				end
				--set target to square from calculated offset
				self.target = getCell():getOrCreateGridSquare(tx,ty,0)
			end
		end

		--if trueTarget is not a gridSquare and timeSinceLastSeenTarget exceeds searchForTargetDuration set trueTarget to current target
		if self.state == "arrived" and (not instanceof(self.trueTarget, "IsoGridSquare")) and (self.timeSinceLastSeenTarget+self.searchForTargetDuration < timeStampMS) then
			self.trueTarget = self.target
			eventSoundHandler:playEventSound(self, "lostTarget")
		end

		if self.state == "arrived" and instanceof(self.trueTarget, "IsoGridSquare") and self.hoverOnTargetDuration and (self.timeSinceLastSeenTarget+self.searchForTargetDuration < timeStampMS) then
			local newTarget = self:findTarget(self.attackDistance*4, "retrackTarget")
			if newTarget and not instanceof(newTarget, "IsoGridSquare") then
				self.trueTarget = newTarget
			else
				--look again later
				self.timeSinceLastSeenTarget = timeStampMS+(self.searchForTargetDuration/5)
			end
		end

	end

	self:setTargetPos()

	local distToTarget = self:getDistanceToIsoObject(self.trueTarget)
	local crashMin = ZombRand(75,150)
	local crashMax = ZombRand(151,325)
	if self.crashing and (distToTarget <= crashMax) and (distToTarget >= crashMin) then
		if self:crash() then
			--[[DEBUG]] print("EHE: crash: dist:"..math.floor(distToTarget).." ("..crashMin.." to "..crashMax..")")
			return
		end
	end

	--[[
	---EVENTS SHOULD HIT A MAX TICK THRESHOLD (TAKING INTO ACCOUNT HOVER TIME) THEN GET "SENT HOME" IF STUCK
	self.updateTicksPassed = (self.updateTicksPassed+1)*getGameSpeed()
	local maxTicksAllowed = eheBounds.threshold*10
	if self.hoverOnTargetDuration and self.hoverOnTargetDuration > 0 then
		maxTicksAllowed = maxTicksAllowed+(self.hoverOnTargetDuration*10)
	end
	if (self.updateTicksPassed > maxTicksAllowed) and (self.state ~= "goHome") then
		print(" - EHE: Update Tick Cap Reached: "..self:heliToString())
		self:goHome()
	end
	-]]

	local preventMovement = false

	if (self.state == "gotoTarget") and (distToTarget <= thatIsCloseEnough*2.5) then
		self.state = "arrived"
		if self.addedFunctionsToEvents then
			local eventFunction = self.addedFunctionsToEvents["OnArrive"]
			if eventFunction then
				eventFunction(self)
			end
		end
	end

	if (self.state == "arrived" or self.state == "gotoTarget") and (distToTarget <= thatIsCloseEnough*1.5) then
		if self.hoverOnTargetDuration then

			if type(self.hoverOnTargetDuration)=="number" and self.hoverOnTargetDuration>0 then

				eventSoundHandler:playEventSound(self, "hoverOverTarget", nil, true)

				if self.addedFunctionsToEvents then
					local eventFunction = self.addedFunctionsToEvents["OnHover"]
					if eventFunction then
						--[[DEBUG]] if getDebug() then self:hoverAndFlyOverReport(" - HOVERING OVER TARGET") end
						eventFunction(self)
					end
				end

				--[DEBUG]] if getDebug() then print("self.hoverOnTargetDuration: "..self.hoverOnTargetDuration.." "..self:heliToString()) end

				self.hoverOnTargetDuration = self.hoverOnTargetDuration-math.max(1,(1*getGameSpeed()))
				if self.hoverOnTargetDuration <= 0 then
					self.hoverOnTargetDuration = false
				end
				preventMovement=true
			else
				self.hoverOnTargetDuration = false
			end
		else

			--[[DEBUG]
			if getDebug() then
				local debugTargetText = " (square)"
				if self.trueTarget then
					if instanceof(self.trueTarget, "IsoPlayer") then debugTargetText = " ("..self.trueTarget:getFullName()..")" end
					self:hoverAndFlyOverReport(" - FLEW OVER TARGET"..debugTargetText)
				end
			end
			--]]

			eventSoundHandler:playEventSound(self, "hoverOverTarget",nil, nil, true)
			eventSoundHandler:playEventSound(self, "flyOverTarget")

			if self.addedFunctionsToEvents then
				local eventFunction = self.addedFunctionsToEvents["OnFlyaway"]
				if eventFunction then
					eventFunction(self)
				end
			end

			self:goHome()
		end
	end

	local lockOn = true
	if self.state == "goHome" then
		lockOn = false
	end

	--if it's ok to move do so, and update the shadow's position
	if not preventMovement then
		self:move(lockOn, true)
	end

	if self.eventMarkerIcon ~= false then
		EHE_SendMarker(self, self.eventMarkerIcon,10)
	end

	if self.announcerVoice and (not self.crashing) and (distToTarget <= thatIsCloseEnough*1000) then
		self:announce()
	end

	self:updateSubFunctions(thatIsCloseEnough, distToTarget, timeStampMS)
	for heli,offsets in pairs(self.formationFollowingHelis) do
		---@type eHelicopter
		local followingHeli = heli
		if followingHeli then
			followingHeli:updateSubFunctions(thatIsCloseEnough, distToTarget, timeStampMS)
		end
	end

	if not self:isInBounds() then
		self:unlaunch()
	end
end


function eHelicopter:updateSubFunctions(thatIsCloseEnough, distToTarget, timeStampMS)
	local currentSquare = self:getIsoGridSquare()
	--Wake up (Wake up) / Grab a brush and put a little make-up
	for character,value in pairs(EHEIsoPlayers) do
		---@type IsoGameCharacter p
		local p = character
		if self:getDistanceToIsoObject(p) < (self.flightVolume*3) then
			p:forceAwake()
		end
	end

	eventSoundHandler:checkEventSounds(self)

	--drop carpackage
	local packageDropRange = ZombRand(50, 75)
	local packageDropRateChance = ZombRand(101) <= ((distToTarget/packageDropRange)*100)+10
	if self.dropPackages and packageDropRateChance and (distToTarget <= packageDropRange) then
		local drop = self:dropCarePackage()
		if drop then
			if self.hoverOnTargetDuration then
				self.trueTarget = currentSquare
				self:setTargetPos()
			end
		else
			if self.hoverOnTargetDuration ~= false then
				self.hoverOnTargetDuration = false
			end
		end
	end

	--drop items
	local itemDropRange = math.min(225,thatIsCloseEnough*225)
	if self.dropItems and (distToTarget <= itemDropRange) then
		local dropChance = ((itemDropRange-distToTarget)/itemDropRange)*10
		self:tryToDropItem(dropChance)
	end

	if self.shadow ~= false then
		if self.shadow == true then
			local alpha = 0.25
			self.shadow = getWorldMarkers():addGridSquareMarker((self.shadowTexture or eHelicopter.shadowTexture), nil, currentSquare, 0.2, 0.2, 0.2, true, 1, 0, alpha, alpha)
			self.shadow:setAlpha(alpha)
			self.shadow:setSize(5)
		end

		local shadowSquare = getOutsideSquareFromAbove(currentSquare) or currentSquare
		if self.shadow and shadowSquare then
			self.shadow:setPos(shadowSquare:getX(),shadowSquare:getY(),shadowSquare:getZ())
		end
	end

	--[[
	--shadowBob
	if self.shadow and (self.shadow ~= true) and (self.timeSinceLastShadowBob < timeStampMS) then
		self.timeSinceLastShadowBob = timeStampMS+10
		local shadowExpansion = 5
		local shadowSize = self.shadow:getSize()-shadowExpansion
		shadowSize = shadowSize+self.shadowBobRate
		if shadowSize >= 1.05 then
			self.shadowBobRate = 0-math.abs(self.shadowBobRate)
		elseif shadowSize <= 1 then
			self.shadowBobRate = math.abs(self.shadowBobRate)
		end
		self.shadow:setSize(shadowSize+shadowExpansion)
	end
	--]]

	if self.flightVolume>0 then
		local volumeFactor = 1
		local zoneType = currentSquare:getZoneType()
		if (zoneType == "Forest") or (zoneType == "DeepForest") then
			volumeFactor = 0.25
		end
		addSound(nil, currentSquare:getX(),currentSquare:getY(), 0, (self.flightVolume*2)*volumeFactor, self.flightVolume*volumeFactor)
	end

	if self.hostilePreference and (not self.crashing) then
		self:lookForHostiles(self.hostilePreference)
	end
end


lastUpdateAllHelicopters = -1
function updateAllHelicopters()

	local timeStamp = getTimestampMs()
	if (lastUpdateAllHelicopters+5 >= timeStamp) then
		return
	else
		lastUpdateAllHelicopters = timeStamp
	end

	for _,helicopter in ipairs(ALL_HELICOPTERS) do
		---@type eHelicopter heli
		local heli = helicopter

		if heli and heli.state and (not (heli.state == "unLaunched")) and (not (heli.state == "following")) then
			heli:update()
		end
	end
end

Events.OnTick.Add(updateAllHelicopters)