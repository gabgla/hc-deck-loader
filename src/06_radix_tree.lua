-------------------------------------------------------------------------------

-- Implements a radix tree - https://github.com/markert/lua-radixtree

-------------------------------------------------------------------------------

local function new_radix_tree()
	local pairs = pairs
	local next = next
	local tinsert = table.insert
	local tremove = table.remove

	local new = function()
		local j = {}

		-- the table that holds the radix_tree
		j.radix_tree = {}

		-- elments that can be filled by several functions
		-- and be returned as set of possible hits
		j.radix_elements = {}

		-- internal tree instance or table of tree instances
		-- used to hold parts of the tree that may be interesting afterwards
		j.return_tree = {}

		-- this FSM is used for string comparison
		-- can evaluate if the radix tree contains or ends with a specific string
		local lookup_fsm = function(wordpart, next_state, next_letter)
			if wordpart:sub(next_state, next_state) ~= next_letter then
				if wordpart:sub(1, 1) ~= next_letter then
					return false, 0
				else
					return false, 1
				end
			end
			if #wordpart == next_state then
				return true, next_state
			else
				return false, next_state
			end
		end

		-- evaluate if the radix tree starts with a specific string
		-- returns pointer to subtree
		local root_lookup
		root_lookup = function(tree_instance, part)
			if #part == 0 then
				j.return_tree = tree_instance
			else
				local s = part:sub(1, 1)
				if tree_instance and tree_instance[s] ~= true then
					root_lookup(tree_instance[s], part:sub(2))
				end
			end
		end

		-- evaluate if the radix tree contains or ends with a specific string
		-- returns list of pointers to subtrees
		local leaf_lookup
		leaf_lookup = function(tree_instance, word, state)
			local next_state = state + 1
			if tree_instance then
				for k, v in pairs(tree_instance) do
					if v ~= true then
						local hit, next_state = lookup_fsm(word, next_state, k)
						if hit == true then
							tinsert(j.return_tree, v)
						else
							leaf_lookup(v, word, next_state)
						end
					end
				end
			end
		end

		-- takes a single tree or a list of trees
		-- traverses the trees and adds all elements to j.radix_elements
		local radix_traverse
		radix_traverse = function(tree_instance)
			for k, v in pairs(tree_instance) do
				if v == true then
					j.radix_elements[k] = true
				elseif v ~= true then
					radix_traverse(v)
				end
			end
		end

		-- adds a new element to the tree
		local add_to_tree = function(word)
			local t = j.radix_tree

			-- for char in word:gfind(".") do
			-- 	if word == "Smart Fella // Fart Smella" then
			-- 		print(char)
			-- 	end
			-- 	if t[char] == true or t[char] == nil then
			-- 		t[char] = {}
			-- 	end
			-- 	t = t[char]
			-- end
			-- t[word] = true

			for i = 1, #word do
				local char = word:sub(i, i)
				if t[char] == true or t[char] == nil then
					t[char] = {}
				end
				t = t[char]
			end
			t[word] = true
		end

		-- removes an element from the tree
		local remove_from_tree = function(word)
			local t = j.radix_tree

			-- for char in word:gfind(".") do
			-- 	if t[char] == true then
			-- 		return
			-- 	end
			-- 	t = t[char]
			-- end
			-- t[word] = nil

			for i = 1, #word do
				local char = word:sub(i, i)
				if t[char] == true then
					return
				end
				t = t[char]
			end
			t[word] = nil
		end

		-- performs the respective actions for the parts of a fetcher
		-- that can be handled by a radix tree
		-- fills j.radix_elements with all hits that were found
		local match_parts = function(tree_instance, parts)
			j.radix_elements = {}

			local temp_tree = tree_instance
			for _, op in ipairs(parts) do
				print(op.expr, op.value)
				if op.expr == 'equals' then
					j.return_tree = {}
					root_lookup(temp_tree, op.value)
					if j.return_tree[op.value] == true then
						j.radix_elements[op.value] = true
					end
					break
				else
					if op.expr == 'startsWith' then
						j.return_tree = {}
						root_lookup(temp_tree, op.value)
						temp_tree = j.return_tree
					end
					if op.expr == 'contains' then
						j.return_tree = {}
						leaf_lookup(temp_tree, op.value, 0)
						temp_tree = j.return_tree
					end
					if op.expr == 'endsWith' then
						j.return_tree = {}
						leaf_lookup(temp_tree, op.value, 0)
						for k, t in pairs(j.return_tree) do
							for _, v in pairs(t) do
								if v ~= true then
									j.return_tree[k] = nil
									break
								end
							end
						end
						temp_tree = j.return_tree
					end
				end
			end
			if temp_tree then
				radix_traverse(temp_tree)
			end
		end

		-- evaluates if the fetch operation can be handled
		-- completely or partially by the radix tree
		-- returns elements from the j.radix_tree if it can be handled
		-- and nil otherwise
		local get_possible_matches = function(path, is_case_insensitive)
			local level = 'impossible'
			local radix_expressions = {}
			local expressions_to_evaluate = {}

			if not is_case_insensitive then
				for _, op in ipairs(path) do
					if op.expr == 'equals' or op.expr == 'startsWith' or op.expr == 'endsWith' or op.expr == 'contains' then
						-- if radix_expressions[op.expr] then
						-- 	level = 'impossible'
						-- 	break
						-- end
						radix_expressions[op.expr] = op.value
						table.insert(expressions_to_evaluate, op)
						if level == 'partial_pending' then
							level = 'partial'
						elseif level ~= 'partial' then
							level = 'all'
						end
					else
						if level == 'easy' or level == 'partial' then
							level = 'partial'
						else
							level = 'partial_pending'
						end
					end
				end
				if level == 'partial_pending' then
					level = 'impossible'
				end
			end

			if level ~= 'impossible' then
				match_parts(j.radix_tree, expressions_to_evaluate)
				return j.radix_elements, level
			else
				return nil, level
			end
		end

		j.add = function(word)
			add_to_tree(word)
		end
		j.remove = function(word)
			remove_from_tree(word)
		end
		j.get_possible_matches = get_possible_matches

		-- for unit testing

		j.match_parts = function(parts, xxx)
			match_parts(j.radix_tree, parts, xxx)
		end
		j.found_elements = function()
			return j.radix_elements
		end

		return j
	end

	return new()
end
