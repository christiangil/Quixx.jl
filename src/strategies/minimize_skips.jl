const legal_max_skips = 10
const too_many_skips = 2 * legal_max_skips + 1


function squares_skipped(dice_roll::Int, ts::TrackState; progress::Int=ts.progress)
    proposed_progress = track_convert(dice_roll, ts)
    skips = (proposed_progress - progress) - 1
    if skips < 0; return too_many_skips end  # throw out illegal moves
    return skips
end


function color_roll_skips_helper(ts::TrackState, color_roll::Int, white1::Int, white2::Int; kwargs...)
    smaller_roll_skips = squares_skipped(color_roll + white1, ts; kwargs...)
    if 0 <= smaller_roll_skips <= legal_max_skips
        return smaller_roll_skips
    end
    return squares_skipped(color_roll + white2, ts; kwargs...)
end


# Matrices to hold the total amount of skips if you chose 2 dice. First dice x second dice (index is color dice then white dice for each color)
const skips_2dice = zeros(2 * n_track_colors, n_track_colors) .+ too_many_skips


"""
    minimize_skips_strategy(gs, player_index; max_skip=1, penalty_max_skip=3)

A strategy defined by taking dice, as long as they dont skip more than `max_skip` spaces. Greedy in a point-sense.
"""
function minimize_skips_strategy(gs::GameState, player_index::Int; max_skip::Int=1, penalty_max_skip::Int=3, verbose::Bool=true)

    @assert player_index <= length(gs.players)
    roll = gs.roll
    ps = gs.players[player_index]
    this_players_turn = player_index == gs.whose_turn
    @assert 0 <= max_skip <= legal_max_skips
    white_roll = roll.white1 + roll.white2

    if this_players_turn

        color_roll_skips = [color_roll_skips_helper(ps(color), roll(color), roll.white1, roll.white2) for color in track_colors]
        white_roll_skips = [squares_skipped(white_roll, ps(color)) for color in track_colors]
        min_skip = min(minimum(color_roll_skips), minimum(white_roll_skips))

        # TODO: add different threshold for avoiding penalties
        if min_skip > max_skip  # only take a dice if it is to our taste
            if verbose; println("Player $player_index is taking a penalty") end
            return add_penalty!(gs, ps)
        end

        # check for best two dice taking combo
        for i in 1:n_track_colors  # first track
            if color_roll_skips[i] == min_skip  # only check second dice if you would take the first
                for j in axes(skips_2dice, 2)  # second track
                    if i == j && white_roll_skips[j] > color_roll_skips[i]
                        skips_2dice[i,j] = white_roll_skips[j]
                    else
                        skips_2dice[i,j] = color_roll_skips[i] + white_roll_skips[j]
                    end
                end
            end
        end
        for i in (n_track_colors + 1):(2 * n_track_colors)  # first track
            if white_roll_skips[i - n_track_colors] == min_skip  # only check second dice if you would take the first
                for j in axes(skips_2dice, 2)  # second track
                    if (i - n_track_colors) == j
                        skips_2dice[i,j] = color_roll_skips_helper(ps(j), roll(j), roll.white1, roll.white2; progress=track_convert(white_roll, ps(j)))
                    else
                        skips_2dice[i,j] = white_roll_skips[i - n_track_colors] + color_roll_skips[j]
                    end
                end
            end
        end
        min_skip_2d = minimum(skips_2dice)

        # if second die is too skippy, only take one
        if (min_skip_2d - min_skip) > max_skip
            skips = Array{Int}(undef, n_track_colors)
            rolls = Array{Int}(undef, n_track_colors)
            for i in eachindex(track_colors)
                if color_roll_skips[i] < white_roll_skips[i]
                    skips[i] = color_roll_skips[i]
                    rolls[i] = roll(i)
                else
                    skips[i] = white_roll_skips[i]
                    rolls[i] = white_roll
                end
            end
            choice = rand([i for i in 1:length(skips) if skips[i]==min_skip])  # choose the track with the smallest skip
            if verbose; println("Player $player_index is taking $(rolls[choice]) on $(color_emojis[choice])") end
            return update_PlayerState!(gs, ps, choice, rolls[choice])
        end

        # take two dice
        ci = CartesianIndices(skips_2dice)
        min_inds = [i for i in eachindex(skips_2dice) if (skips_2dice[i] == min_skip_2d)]
        choices = rand(ci[min_inds])
        choice1, choice2 = choices[1], choices[2]
        if choice1 <= n_track_colors  # chose a color dice first
            if choice1 == choice2  # then chose white dice in same color
                if verbose; println("Player $player_index is taking 2 die up to $white_roll on $(color_emojis[choice2])") end
                return update_PlayerState!(gs, ps, choice2, white_roll; n_marked_increase=2)
            end
            if verbose; println("Player $player_index is taking $(roll(choice1)) on $(color_emojis[choice1]) and $white_roll on $(color_emojis[choice2])") end
            update_PlayerState!(gs, ps, choice1, roll(choice1))
            return update_PlayerState!(gs, ps, choice2, white_roll)
        end
        # chose white die first
        choice1 -= n_track_colors
        if choice1 == choice2  # then chose color dice in same color
            if verbose; println("Player $player_index is taking 2 die up to $(roll(choice2)) on $(color_emojis[choice2])") end
            return update_PlayerState!(gs, ps, choice2, roll(choice2); n_marked_increase=2)
        end
        if verbose; println("Player $player_index is taking $white_roll on $(color_emojis[choice1]) and $(roll(choice2)) on $(color_emojis[choice2])") end
        update_PlayerState!(gs, ps, choice1, white_roll)
        return update_PlayerState!(gs, ps, choice2, roll(choice2))

    else

        skips = [squares_skipped(white_roll, ps(color)) for color in track_colors]
        min_skip = minimum(skips)
        if min_skip <= max_skip  # only take a dice if it is to our taste
            choice = rand([i for i in 1:length(skips) if skips[i]==min_skip])  # choose the track with the smallest skip
            if verbose; println("Player $player_index is taking $white_roll on $(color_emojis[choice])") end
            return update_PlayerState!(gs, ps, choice, white_roll)
        elseif verbose
            println("Player $player_index is skipping")
        end
        return gs.game_over

    end
end
