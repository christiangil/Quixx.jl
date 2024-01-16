const legal_max_skips = 10
const too_many_skips = 2 * legal_max_skips + 1


function squares_skipped(dice_roll::Int, ts::TrackState, track_locked::Bool; progress::Int=ts.progress)
    proposed_progress = dice_number_to_progress(dice_roll, ts)
    skips = (proposed_progress - progress) - 1
    if track_locked || skips < 0 || (proposed_progress == 12 && ts.n_marked < marks_for_track_lock)
        return too_many_skips  # throw out illegal moves
    end
    return skips
end


function color_roll_skips_helper(ts::TrackState, color_roll::Int, white1::Int, white2::Int, track_locked::Bool; kwargs...)
    if ts.reversed
        earlier_white, later_white = white2, white1
    else
        earlier_white, later_white = white1, white2
    end
    current_roll = color_roll + earlier_white
    smaller_roll_skips = squares_skipped(current_roll, ts, track_locked; kwargs...)
    if 0 <= smaller_roll_skips <= legal_max_skips
        return smaller_roll_skips, current_roll
    end
    current_roll = color_roll + later_white
    return squares_skipped(current_roll, ts, track_locked; kwargs...), current_roll
end


# Matrices to hold the total amount of skips if you chose 2 dice. First dice x second dice (index is color dice then white dice for each color)
const costs_2dice = zeros(2 * n_track_colors, n_track_colors)
const costs_2dice_rolls = zeros(Int, 2 * n_track_colors, n_track_colors)


up_to_str(reversed::Bool) = reversed ? "down to" : "up to"
up_to_str(ts::TrackState) = up_to_str(ts.reversed)


"""
    minimize_skips_strategy(gs, player_index; max_cost=1, penalty_max_cost=3)

A strategy defined by taking dice, as long as they dont skip more than `max_cost` spaces. Greedy in a point-sense.
"""
function minimize_skips_strategy(gs::GameState, player_index::Int; max_cost::Int=1, penalty_max_cost::Int=3, verbose::Bool=true, debug::Bool=false)
    # TODO prioritize tracks with more marks
    @assert player_index <= length(gs.players)
    roll = gs.roll
    ps = gs.players[player_index]
    this_players_turn = player_index == gs.whose_turn
    @assert 0 <= max_cost <= legal_max_skips
    @assert 0 <= penalty_max_cost <= legal_max_skips
    white_roll = roll.white1 + roll.white2

    if this_players_turn

        costs_2dice_rolls .= 0
        costs_2dice .= too_many_skips

        color_roll_costs_and_rolls= [color_roll_skips_helper(ps(color), roll(color), roll.white1, roll.white2, gs(color)) for color in track_colors]
        color_roll_costs = [color_roll_costs_and_rolls[i][1] for i in eachindex(track_colors)]
        color_rolls = [color_roll_costs_and_rolls[i][2] for i in eachindex(track_colors)]
        white_roll_costs = [squares_skipped(white_roll, ps(color), gs(color)) for color in track_colors]
        if debug; println(color_roll_costs, white_roll_costs) end
        min_cost = min(minimum(color_roll_costs), minimum(white_roll_costs))

        if min_cost >= penalty_max_cost  # only take a dice if it is to our taste
            if verbose
                if min_cost == too_many_skips
                    println("Player $player_index is taking a penalty (couldn't take anything)") 
                else
                    println("Player $player_index is taking a penalty (would've had to skip $min_cost squares)") 
                end
            end
            return add_penalty!(gs, ps)
        end

        # check for best two dice taking combo
        for i in 1:n_track_colors  # first track, taking color first
            if color_roll_costs[i] == min_cost  # only check second dice if you would take the first
                for j in axes(costs_2dice, 2)  # second track
                    if i == j 
                        if white_roll_costs[j] > color_roll_costs[i]
                            costs_2dice[i,j] = white_roll_costs[j]
                        end
                    else
                        costs_2dice[i,j] = color_roll_costs[i] + white_roll_costs[j]
                    end
                end
            end
        end
        for i in (n_track_colors + 1):(2 * n_track_colors)  # first track, taking white first
            if white_roll_costs[i - n_track_colors] == min_cost  # only check second dice if you would take the first
                for j in axes(costs_2dice, 2)  # second track
                    if (i - n_track_colors) == j
                        costs_2dice[i,j], costs_2dice_rolls[i, j] = color_roll_skips_helper(ps(j), roll(j), roll.white1, roll.white2, gs(j); progress=dice_number_to_progress(white_roll, ps(j)))
                    else
                        costs_2dice[i,j] = white_roll_costs[i - n_track_colors] + color_roll_costs[j]
                    end
                end
            end
        end
        min_cost_2d = minimum(costs_2dice)

        # if second die is too costly, only take one
        if (min_cost_2d - min_cost) >= max_cost
            costs = Array{Int}(undef, n_track_colors)
            rolls = Array{Int}(undef, n_track_colors)
            is_white = Array{Bool}(undef, n_track_colors)
            for i in eachindex(track_colors)
                if color_roll_costs[i] < white_roll_costs[i]
                    costs[i] = color_roll_costs[i]
                    rolls[i] = color_rolls[i]
                    is_white[i] = false
                else
                    costs[i] = white_roll_costs[i]
                    rolls[i] = white_roll
                    is_white[i] = true
                end
            end
            choice = rand([i for i in 1:length(costs) if costs[i]==min_cost])  # choose the track with the smallest cost
            if verbose
                if is_white[choice]
                    println("Player $player_index is taking $(rolls[choice]) ($white_emoji$white_emoji) on $(color_emojis[choice])")
                else
                    println("Player $player_index is taking $(rolls[choice]) on $(color_emojis[choice])")
                end
            end
            return update_PlayerState!(gs, ps, choice, rolls[choice])
        end

        # take two dice
        ci = CartesianIndices(costs_2dice)
        costs_2dice_vec = vec(costs_2dice)  # might be unnecessary
        min_inds = [i for i in eachindex(costs_2dice_vec) if (costs_2dice_vec[i] == min_cost_2d)]
        choices = rand(ci[min_inds])
        choice1, choice2 = choices[1], choices[2]
        if choice1 <= n_track_colors  # chose a color dice first
            if choice1 == choice2  # then chose white dice in same color
                if verbose; println("Player $player_index is taking 2 die " * up_to_str(ps(choice2)) * " $white_roll on $(color_emojis[choice2]) ($(color_emojis[choice2])$white_emoji then $white_emoji$white_emoji)") end
                return update_PlayerState!(gs, ps, choice2, white_roll; n_marked_increase=2)
            end
            if verbose; println("Player $player_index is taking $(color_rolls[choice1]) on $(color_emojis[choice1]) and $white_roll ($white_emoji$white_emoji) on $(color_emojis[choice2])") end
            update_PlayerState!(gs, ps, choice1, color_rolls[choice1])
            return update_PlayerState!(gs, ps, choice2, white_roll)
        end
        # chose white die first
        choice1 -= n_track_colors
        if choice1 == choice2  # then chose color dice in same color
            if verbose; println("Player $player_index is taking 2 die " * up_to_str(ps(choice2)) * " $(costs_2dice_rolls[choice1 + n_track_colors, choice2]) on $(color_emojis[choice2]) ($white_emoji$white_emoji then $(color_emojis[choice2])$white_emoji)") end
            return update_PlayerState!(gs, ps, choice2, costs_2dice_rolls[choice1 + n_track_colors, choice2]; n_marked_increase=2)
        end
        if verbose; println("Player $player_index is taking $white_roll ($white_emoji$white_emoji) on $(color_emojis[choice1]) and $(color_rolls[choice2]) on $(color_emojis[choice2])") end
        update_PlayerState!(gs, ps, choice1, white_roll)
        return update_PlayerState!(gs, ps, choice2, color_rolls[choice2])

    else

        costs = [squares_skipped(white_roll, ps(color), gs(color)) for color in track_colors]
        if debug; println(costs) end
        min_cost = minimum(costs)
        if min_cost <= max_cost  # only take a dice if it is to our taste
            choice = rand([i for i in 1:length(costs) if costs[i]==min_cost])  # choose the track with the smallest cost
            if verbose; println("Player $player_index is taking $white_roll ($white_emoji$white_emoji) on $(color_emojis[choice])") end
            return update_PlayerState!(gs, ps, choice, white_roll)
        elseif verbose
            println("Player $player_index is skipping")
        end
        return gs.game_over

    end
end
