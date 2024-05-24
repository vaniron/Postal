Postal.open = {}

local wait_for_update, open, process, stop

local controller = (function()
	local controller
	return function()
		controller = controller or Postal.control.controller()
		return controller
	end
end)()

function wait_for_update(k)
	return controller().wait(function() return true end, k)
end

function Postal.open.start(isreturn,selected, callback)
	controller().wait(function()
		process(isreturn,selected, function()
			callback()
		end)
	end)
end

function Postal.open.stop()
	controller().wait(function() end)
end

function process(isreturn,selected, k)
	if getn(selected) == 0 then
		return k()
	else
		local index = selected[1]
		local inbox_count = GetInboxNumItems()
		if isreturn then
			returnmail(index, inbox_count, function(skipped)
				tremove(selected, 1)
				if not skipped then
					for i, _ in ipairs(selected) do
						selected[i] = selected[i] - 1
					end
				end
				return process(isreturn,selected, k)
			end)
		else
			open(index, inbox_count, function(skipped)
				tremove(selected, 1)
				if not skipped then
					for i, _ in ipairs(selected) do
						selected[i] = selected[i] - 1
					end
				end
				return process(isreturn,selected, k)
			end)
		end
	end
end

function money_str(amount)
	local gold = floor(abs(amount / 10000))
	local silver = floor(abs(mod(amount / 100, 100)))
	local copper = floor(abs(mod(amount, 100)))
	if gold > 0 then
		return format("%d gold, %d silver, %d copper", gold, silver, copper)
	elseif silver > 0 then
		return format("%d silver, %d copper", silver, copper)
	else
		return format("%d copper", copper)
	end
end

function returnmail(i,inbox_count, k)
	wait_for_update(function()
		local _, _, sender, subject, money, COD_amount, _, has_item, _, was_returned = GetInboxHeaderInfo(i)

		if was_returned then
			Postal:Print("Mail from, |cff00ff00"..sender.."|r: "..subject..", can not be returned, it is a returned item.", 1, 1, 0)
			controller().wait(function() return GetInboxNumItems() < inbox_count end, function()
				return open(i, inbox_count, k)
			end)
		elseif has_item then
			local itm_name, _, itm_qty, _, _ = GetInboxItem(i)
			Postal:Print("Returning to |cff00ff00"..sender.."|r: "..itm_name.." (x"..itm_qty..")", 1, 1, 0)
			ReturnInboxItem(i)
			controller().wait(function() return not ({GetInboxHeaderInfo(i)})[8] or GetInboxNumItems() < inbox_count end, function()
				return open(i, inbox_count, k)
			end)
		elseif money > 0 then
			Postal:Print("Returning to |cff00ff00"..sender.."|r: "..money_str(money), 1, 1, 0)
			ReturnInboxItem(i)
			controller().wait(function() return ({GetInboxHeaderInfo(i)})[5] == 0 or GetInboxNumItems() < inbox_count end, function()
				return open(i, inbox_count, k)
			end)
		end
		controller().wait(function() return GetInboxNumItems() < inbox_count end, function()
			return open(i, inbox_count, k)
		end)
	end)
end

function open(i, inbox_count, k)
	wait_for_update(function()
		local _, _, sender, subject, money, COD_amount, _, has_item = GetInboxHeaderInfo(i)
        -- local ix

		-- if subject then
		-- 	_,ix = strfind(subject, "Auction successful: ",1,true)
		-- 	if ix then subject = strsub(subject,ix) end end

		if GetInboxNumItems() < inbox_count then
			return k(false)
		elseif COD_amount > 0 then
			return k(true)
		elseif has_item then
			local itm_name, _, itm_qty, _, _ = GetInboxItem(i)
			TakeInboxItem(i)
			Postal:Print("Received from |cff00ff00"..sender.."|r: "..itm_name.." (x"..itm_qty..")", 1, 1, 0)
			controller().wait(function() return not ({GetInboxHeaderInfo(i)})[8] or GetInboxNumItems() < inbox_count end, function()
				return open(i, inbox_count, k)
			end)
		elseif money > 0 then
			TakeInboxMoney(i)
			local _,ix = strfind(subject, "Auction successful: ",1,true)
			local sub
			if ix then sub = strsub(subject,ix) end
			if ix
			  then Postal:Print("Sold"..sub..": "..money_str(money), 1, 1, 0)
			  else Postal:Print("Received from |cff00ff00"..sender.."|r: "..money_str(money), 1, 1, 0)
			end
			controller().wait(function() return ({GetInboxHeaderInfo(i)})[5] == 0 or GetInboxNumItems() < inbox_count end, function()
				return open(i, inbox_count, k)
			end)
		else
			DeleteInboxItem(i)
			controller().wait(function() return GetInboxNumItems() < inbox_count end, function()
				return open(i, inbox_count, k)
			end)
		end
	end)
end