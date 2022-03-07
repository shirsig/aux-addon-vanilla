module 'aux.core.post'

local aux = require 'aux'
local info = require 'aux.util.info'
local stack = require 'aux.core.stack'
local history = require 'aux.core.history'
local disenchant = require 'aux.core.disenchant'

local state

function aux.handle.CLOSE()
	stop()
end

function process()
	if state.posted < state.count then

		local stacking_complete

		local send_signal, signal_received = aux.signal()
		aux.when(signal_received, function()
			local slot = signal_received()[1]
			if slot then
				return post_auction(slot, process)
			else
				return stop()
			end
		end)

		return stack.start(state.item_key, state.stack_size, send_signal)
	end

	return stop()
end

function post_auction(slot, k)
	local item_info = info.container_item(unpack(slot))
	if item_info.item_key == state.item_key and info.auctionable(item_info.tooltip, nil, true) and item_info.aux_quantity == state.stack_size then

		ClearCursor()
		ClickAuctionSellItemButton()
		ClearCursor()
		PickupContainerItem(unpack(slot))
		ClickAuctionSellItemButton()
		ClearCursor()
		
		local start_price = state.unit_start_price
		local buyout_price = state.unit_buyout_price
		local kz_daily = 0
		local kz_pricing = 0
		
		--use autoprice heuristic if start bid 0 is set
		if start_price == 0 then
			
			if buyout_price > 0 then
				kz_pricing=1
			end
			
			if history.market_value(state.item_key) ~= nil then 
					local tmp = tonumber(history.market_value(state.item_key))
					tmp = max(0.99*tmp,tmp-50)
					buyout_price = max(buyout_price,tmp)
					kz_daily = 1
			end	
			
			if disenchant.value(item_info.slot, item_info.quality, item_info.level) ~= nil then 
				buyout_price = max(buyout_price,0.85* tonumber(disenchant.value(item_info.slot, item_info.quality, item_info.level)))
			end
					
			if aux.account_data.merchant_sell[item_info.item_id] ~= nil then 		
				if kz_daily == 0 then
					start_price = max(start_price,tonumber(aux.account_data.merchant_sell[item_info.item_id]) * (1.35+3.65*math.exp(-(1/4000)* tonumber(aux.account_data.merchant_sell[item_info.item_id] ))))
					buyout_price = max(buyout_price,start_price)
				else
					start_price = max(start_price,tonumber(aux.account_data.merchant_sell[item_info.item_id]) * 1.35)
					buyout_price = max(buyout_price,start_price)
				end
			end
			
			if aux.account_data.merchant_buy[item_info.item_id] ~= nil then 
				local tmp = tostring(aux.account_data.merchant_buy[item_info.item_id])
				tmp = strsub(tmp,1,-3)
				start_price = max(start_price,tonumber(tmp) * 1.1)
				buyout_price = max(buyout_price,tonumber(tmp) * 1.15)
			end
			
			if history.value(state.item_key) ~= nil then 
				if kz_pricing == 1 and kz_daily == 1 then
					buyout_price = max(buyout_price,1.0*tonumber(history.value(state.item_key)))
				elseif kz_daily == 1 then
					start_price = max(start_price,0.91*tonumber(history.value(state.item_key)))
					buyout_price = max(buyout_price,0.91*tonumber(history.value(state.item_key)))
				else
					buyout_price = max(buyout_price,0.99* tonumber(history.value(state.item_key)))
				end
			end
			
			start_price = max(start_price,0.75 * buyout_price)
		end
		
		StartAuction(max(1, aux.round(start_price * item_info.aux_quantity)), aux.round(buyout_price * item_info.aux_quantity), state.duration)

		local send_signal, signal_received = aux.signal()
		aux.when(signal_received, function()
			state.posted = state.posted + 1
			return k()
		end)

		local posted
		aux.event_listener('CHAT_MSG_SYSTEM', function(kill)
			if arg1 == ERR_AUCTION_STARTED then
				send_signal()
				kill()
			end
		end)
	else
		return stop()
	end
end

function M.stop()
	if state then
		aux.kill_thread(state.thread_id)

		local callback = state.callback
		local posted = state.posted

		state = nil

		if callback then
			callback(posted)
		end
	end
end

function M.start(item_key, stack_size, duration, unit_start_price, unit_buyout_price, count, callback)
	stop()
	state = {
		thread_id = aux.thread(process),
		item_key = item_key,
		stack_size = stack_size,
		duration = duration,
		unit_start_price = unit_start_price,
		unit_buyout_price = unit_buyout_price,
		count = count,
		posted = 0,
		callback = callback,
	}
end