aux 'filter_util' local info = aux.info

function default_filter(str)
    return {
        input_type = '',
        validator = function()
            return function(auction_record)
                return any(auction_record.tooltip, function(entry)
                    return strfind(strlower(entry.left_text or ''), str, 1, true) or strfind(strlower(entry.right_text or ''), str, 1, true)
                end)
            end
        end,
    }
end

public.filters = {

    ['utilizable'] = {
        input_type = '',
        validator = function()
            return function(auction_record)
                return auction_record.usable and not info.tooltip_match(ITEM_SPELL_KNOWN, auction_record.tooltip)
            end
        end,
    },

    ['tooltip'] = {
        input_type = 'string',
        validator = function(str)
            return default_filter(str).validator()
        end,
    },

    ['item'] = {
        input_type = 'string',
        validator = function(name)
            return function(auction_record)
                return strlower(info.item(auction_record.item_id).name) == name
            end
        end
    },

    ['left'] = {
        input_type = -list('30m', '2h', '8h', '24h'),
        validator = function(index)
            return function(auction_record)
                return auction_record.duration == index
            end
        end
    },

    ['rarity'] = {
        input_type = -list('poor', 'common', 'uncommon', 'rare', 'epic'),
        validator = function(index)
            return function(auction_record)
                return auction_record.quality == index - 1
            end
        end
    },

    ['min-lvl'] = {
        input_type = 'number',
        validator = function(level)
            return function(auction_record)
                return auction_record.level >= level
            end
        end
    },

    ['max-lvl'] = {
        input_type = 'number',
        validator = function(level)
            return function(auction_record)
                return auction_record.level <= level
            end
        end
    },

    ['min-unit-bid'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                return auction_record.unit_bid_price >= amount
            end
        end
    },

    ['min-unit-buy'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                return auction_record.unit_buyout_price >= amount
            end
        end
    },

    ['max-unit-bid'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                return auction_record.unit_bid_price <= amount
            end
        end
    },

    ['max-unit-buy'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                return auction_record.buyout_price > 0 and auction_record.unit_buyout_price <= amount
            end
        end
    },

    ['bid-pct'] = {
        input_type = 'number',
        validator = function(pct)
            return function(auction_record)
                return auction_record.unit_buyout_price > 0
                        and history.value(auction_record.item_key)
                        and auction_record.unit_buyout_price / history.value(auction_record.item_key) * 100 <= pct
            end
        end
    },

    ['buy-pct'] = {
        input_type = 'number',
        validator = function(pct)
            return function(auction_record)
                return auction_record.unit_buyout_price > 0
                        and history.value(auction_record.item_key)
                        and auction_record.unit_buyout_price / history.value(auction_record.item_key) * 100 <= pct
            end
        end
    },

    ['bid-profit'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                return history.value(auction_record.item_key) and history.value(auction_record.item_key) * auction_record.aux_quantity - auction_record.bid_price >= amount
            end
        end
    },

    ['buy-profit'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                return auction_record.buyout_price > 0 and history.value(auction_record.item_key) and history.value(auction_record.item_key) * auction_record.aux_quantity - auction_record.buyout_price >= amount
            end
        end
    },

    ['bid-dis-profit'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                local disenchant_value = disenchant.value(auction_record.slot, auction_record.quality, auction_record.level)
                return disenchant_value and disenchant_value - auction_record.bid_price >= amount
            end
        end
    },

    ['buy-dis-profit'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                local disenchant_value = disenchant.value(auction_record.slot, auction_record.quality, auction_record.level)
                return auction_record.buyout_price > 0 and disenchant_value and disenchant_value - auction_record.buyout_price >= amount
            end
        end
    },

    ['bid-vend-profit'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                local vendor_price = aux.cache.merchant_info(auction_record.item_id)
                return vendor_price and vendor_price * auction_record.aux_quantity - auction_record.bid_price >= amount
            end
        end
    },

    ['buy-vend-profit'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                local vendor_price = aux.cache.merchant_info(auction_record.item_id)
                return auction_record.buyout_price > 0 and vendor_price and vendor_price * auction_record.aux_quantity - auction_record.buyout_price >= amount
            end
        end
    },

    ['discard'] = {
        input_type = '',
        validator = function()
            return function()
                return false
            end
        end
    },
}

function operator(str)
    local operator = str == 'not' and -list('operator', 'not', 1)
    for name in -temp-set('and', 'or') do
	    for arity in present(select(3, strfind(str, '^'..name..'(%d*)$'))) do
		    arity = tonumber(arity)
		    operator = not (arity and arity < 2) and -list('operator', name, arity)
	    end
    end
    return operator or nil
end

do
	local mt = {
		__call = function(self, str, i)
			if not str then
				self.max_level = self.max_level or self.min_level
				return self
			end
			if self.exact then
				return
			end
			for number in present(tonumber(select(3, strfind(str, '^(%d+)$')))) do
				if number >= 1 and number <= 60 then
					for filter in -temp-set('min_level', 'max_level') do
						if not self[filter] then
							self[filter] = {str, number}
							return true
						end
					end
				end
			end
			for _, parser in -list(
				-list('class', info.item_class_index),
				-list('subclass', L(info.item_subclass_index, index(self.class, 2) or 0, _1)),
				-list('slot', L(info.item_slot_index, index(self.class, 2) or 0, index(self.subclass, 2) or 0, _1)),
				-list('quality', info.item_quality_index)
			) do
				if not self[parser[1]] then
					tinsert(parser, str)
					for index, label in present(parser[2](select(3, unpack(parser)))) do
						self[parser[1]] = {label, index}
						return true
					end
				end
			end
			if not self[str] and (str == 'usable' or str == 'exact' and self.name and size(self) == 1) then
				self[str] = {str, 1}
			elseif i == 1 and strlen(str) <= 63 then
				self.name = -list(str, unquote(str))
--				return nil, 'The name filter must not be longer than 63 characters'
			else
				return
			end
			return true
		end,
	}

	function blizzard_filter_parser()
	    return setmetatable(t, mt)
	end
end

function parse_parameter(input_type, str)
    if input_type == 'money' then
        local money = money.from_string(str)
        return money and money > 0 and money or nil
    elseif input_type == 'number' then
        local number = tonumber(str)
        return number and number > 0 and mod(number, 1) == 0 and number or nil
    elseif input_type == 'string' then
        return str ~= '' and str or nil
    elseif type(input_type) == 'table' then
        return key(str, input_type)
    end
end

function public.parse_query_string(str)
    local post_filter = {}
    local blizzard_filter_parser = blizzard_filter_parser()
    local parts = map(split(str, '/'), function(part) return strlower(trim(part)) end)

    local i = 1
    while parts[i] do
	    local operator = operator(parts[i])
        if operator then
            tinsert(post_filter, operator)
        elseif filters[parts[i]] then
            local input_type = filters[parts[i]].input_type
            if input_type ~= '' then
                if not parts[i + 1] or not parse_parameter(input_type, parts[i + 1]) then
                    if parts[i] == 'item' then
                        return nil, 'Invalid item name', _G.aux_auctionable_items
                    elseif type(input_type) == 'table' then
                        return nil, 'Invalid choice for '..parts[i], input_type
                    else
                        return nil, 'Invalid input for '..parts[i]..'. Expecting: '..input_type
                    end
                end
                tinsert(post_filter, -list('filter', parts[i], parts[i + 1]))
                i = i + 1
            else
                tinsert(post_filter, -list('filter', parts[i]))
            end
        elseif not blizzard_filter_parser(parts[i], i) then
	        if parts[i] ~= '' then
		        tinsert(post_filter, -list('filter', 'tooltip', parts[i]))
	        else
	            return nil, 'Empty modifier'
	        end
        end
        i = i + 1
    end

    return -object('blizzard', blizzard_filter_parser(), 'post', post_filter)
end

function public.query(query_string)
    local components, error, suggestions = parse_query_string(query_string)

    if not components then
        return nil, suggestions or t, error
    end

    local polish_notation_counter = 0
    for _, component in components.post do
        if component[1] == 'operator' then
            polish_notation_counter = max(polish_notation_counter, 1)
            polish_notation_counter = polish_notation_counter + (tonumber(component[2]) or 1) - 1
        elseif component[1] == 'filter' then
            polish_notation_counter = polish_notation_counter - 1
        end
    end

    if polish_notation_counter > 0 then
        local suggestions = t
        for key in filters do
            tinsert(suggestions, strlower(key))
        end
        tinsert(suggestions, 'and')
        tinsert(suggestions, 'or')
        tinsert(suggestions, 'not')
        return nil, suggestions, 'Malformed expression'
    end

    return {
        blizzard_query = blizzard_query(components),
        validator = validator(components),
        prettified = prettified_query_string(components),
    }, M.suggestions(components)
end

function public.queries(query_string)
    local parts = split(query_string, ';')
    local queries = t
    for _, str in parts do
        str = trim(str)
        local query, _, error = query(str)
        if not query then
            log('Invalid filter:', error)
            return
        else
            tinsert(queries, query)
        end
    end
    return queries
end

function suggestions(components)
    local suggestions = t

    if components.blizzard.name and size(components.blizzard) == 1 then tinsert(suggestions, 'exact') end

    tinsert(suggestions, 'and'); tinsert(suggestions, 'or'); tinsert(suggestions, 'not'); tinsert(suggestions, 'tooltip')

    for key in filters do tinsert(suggestions, key) end

    -- classes
    if not components.blizzard.class then
        for _, class in temp-{GetAuctionItemClasses()} do tinsert(suggestions, class) end
    end

    -- subclasses
    if not components.blizzard.subclass then
        for _, subclass in temp-{GetAuctionItemSubClasses(index(components.blizzard.class, 2) or 0)} do
            tinsert(suggestions, subclass)
        end
    end

    -- slots
    if not components.blizzard.slot then
        for _, invtype in temp-{GetAuctionInvTypes(index(components.blizzard.class, 2) or 0, index(components.blizzard.subclass, 2) or 0)} do
            tinsert(suggestions, _G[invtype])
        end
    end

    -- usable
    if not components.blizzard.usable then tinsert(suggestions, 'usable') end

    -- rarities
    if not components.blizzard.quality then
        for i = 0, 4 do tinsert(suggestions, _G['ITEM_QUALITY'..i..'_DESC']) end
    end

    -- item names
    if size(components.blizzard) + getn(components.post) == 1 and components.blizzard.name == '' then
        for _, name in _G.aux_auctionable_items do
            tinsert(suggestions, name..'/exact')
        end
    end

    return suggestions
end

function public.query_string(components)
    local query_builder = query_builder()

    for _, filter in components.blizzard do
        query_builder.append(filter[2] or filter[1])
    end

    for _, component in components.post do
        if component[1] == 'operator' then
            query_builder.append(component[2]..(component[2] ~= 'not' and tonumber(component[3]) or ''))
        elseif component[1] == 'filter' then
            query_builder.append(component[2])
            for parameter in present(component[3]) do
	            if filter.filters[component[2]].input_type == 'money' then
		            parameter = money.to_string(money.from_string(parameter), nil, true, nil, nil, true)
	            end
                query_builder.append(parameter)
            end
        end
    end

    return query_builder.get()
end

function prettified_query_string(components)
    local prettified = query_builder()

    for key, filter in components.blizzard do
        if key == 'exact' then
            prettified.prepend(info.display_name(aux.cache.item_id(components.blizzard.name[2])) or color.blizzard('['..components.blizzard.name[2]..']'))
        elseif key ~= 'name' then
            prettified.append(color.blizzard(filter[1]))
        end
    end

    if components.blizzard.name and not components.blizzard.exact and components.blizzard.name[2] ~= '' then
        prettified.prepend(color.blizzard(components.blizzard.name[2]))
    end

    for _, component in components.post do
        if component[1] == 'operator' then
			prettified.append(color.aux(component[2]..(component[2] ~= 'not' and tonumber(component[3]) or '')))
        elseif component[1] == 'filter' then
            if component[2] ~= 'tooltip' then
                prettified.append(color.aux(component[2]))
            end
            for parameter in present(component[3]) do
	            if component[2] == 'item' then
		            prettified.append(info.display_name(aux.cache.item_id(parameter)) or color.label.enabled('['..parameter..']'))
	            else
		            if filters[component[2]].input_type == 'money' then
			            prettified.append(money.to_string(money.from_string(parameter), nil, true, nil, gui.inline_color.label.enabled))
		            else
			            prettified.append(color.label.enabled(parameter))
		            end
	            end
            end
        end
    end
    if prettified.get() == '' then
        return color.blizzard'<>'
    else
        return prettified.get()
    end
end

function public.quote(name)
    return '<'..name..'>'
end

function public.unquote(name)
    return select(3, strfind(name, '^<(.*)>$')) or name
end

function blizzard_query(components)
    local filters = components.blizzard

    local query = -object('name', filters.name and filters.name[2])

    local item_info, class_index, subclass_index, slot_index
    local item_id = aux.cache.item_id(filters.name[2])
    item_info = item_id and info.item(item_id)
    if filters.exact and item_info then
	    item_info = info.item(item_id)
        class_index = info.item_class_index(item_info.class)
        subclass_index = info.item_subclass_index(class_index or 0, item_info.subclass)
        slot_index = info.item_slot_index(class_index or 0, subclass_index or 0, item_info.slot)
    end

    if item_info then
        query.min_level = item_info.level
        query.max_level = item_info.level
        query.usable = item_info.usable
        query.class = class_index
        query.subclass = subclass_index
        query.slot = slot_index
        query.quality = item_info.quality
    else
	    for key in -temp-set('min_level', 'max_level', 'class', 'subclass', 'slot', 'usable', 'quality') do
            query[key] = index(filters[key], 2)
	    end
    end
    return query
end

function validator(components)

    local validators = tt
    for i, component in components.post do
        if component[1] == 'filter' then
            validators[i] = filters[component[2]].validator(parse_parameter(filters[component[2]].input_type, component[3]))
        end
    end

    return function(record)
        if components.blizzard.exact and strlower(info.item(record.item_id).name) ~= components.blizzard.name[2] then
            return false
        end
        local stack = {}
        for i = getn(components.post), 1, -1 do
            local type, name, param = unpack(components.post[i])
            if type == 'operator' then
                local args = {}
                while (not param or param > 0) and getn(stack) > 0 do
                    tinsert(args, tremove(stack))
                    param = param and param - 1
                end
                if name == 'not' then
                    tinsert(stack, not args[1])
                elseif name == 'and' then
                    tinsert(stack, all(args))
                elseif name == 'or' then
                    tinsert(stack, any(args))
                end
            elseif type == 'filter' then
                tinsert(stack, validators[i](record) and true or false)
            end
        end
        return all(stack)
    end
end

function public.query_builder()
    local filter
    return -object(
        'appended', function(part)
            return query_builder(not filter and part or filter..'/'..part)
        end,
		'prepended', function(part)
            return query_builder(not filter and part or part..'/'..filter)
        end,
		'append', function(part)
            filter = not filter and part or filter..'/'..part
        end,
		'prepend', function(part)
            filter = not filter and part or part..'/'..filter
        end,
		'get', function()
            return filter or ''
        end
    )
end