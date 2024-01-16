# Minimizing rolls to lock with absorbing markov chains (AMC)
# https://en.wikipedia.org/wiki/Absorbing_Markov_chain
# based off of https://www.reddit.com/r/boardgames/comments/5l62f6/qwixx_analysis_and_strategy/ and https://drive.google.com/file/d/0B0E4VFlFjnCuazZYVE5idFJBWDg/view?resourcekey=0-iFBYeJbhhIz7EwfCrMMd_Q
using LinearAlgebra

const two_d6_pdf = [0, 1/36, 1/18, 1/12, 1/9, 5/36, 1/6, 5/36, 1/9, 1/12, 1/18, 1/36]
@assert isapprox(sum(two_d6_pdf), 1)

const r = 1 # only one absorbing state (getting to 5 marks i.e., getting to being able to lock)
const t = 1 + 4*6  # no progress + states that could lead to locking for transient states
P = zeros(r+t, r+t)  # transition matrix
Q = zeros(t, t)  # transient state transition matrix
N = zeros(t, t)  # expected number of visits to each transient site
T = zeros(t)  # expected number of steps before being absorbed for each transient state


"""
    amc_index(n_marked::Int, progress::Int)

Helper function to go from to n_marked and progress to their transient state index
"""
function amc_index(n_marked::Int, progress::Int)
    # println("$n_marked, $progress")
    @assert marks_for_track_lock > n_marked > -1
    if n_marked == 0
        return 1
    end
    @assert (n_marked) < progress
    @assert progress < (n_marked+7)
    return (n_marked-1)*5 + progress
end


"""
    amc_index(n_marked::Int, progress::Int)

Update Q, N, and t based on the the given transition matrix
"""
function update_QNT!(P::Matrix, Q::Matrix, N::Matrix, T::Vector)
    Q .= P[1:t, 1:t]
    N .= inv(I(t) - Q)
    T .= N * ones(25)
end

## Basic AMC analysis

# intialize absorbing markov chain transition matrix
P[1,1] = 1 - sum(two_d6_pdf[2:7])  # 0 to 0
P[1, amc_index.(1, 2:7)] .= two_d6_pdf[2:7]  # 0 to anything
P[end, end] = 1  # lockable to lockable
P[amc_index.(4, 5:10), end] .= [sum(two_d6_pdf[i:11]) for i in 5:10] # 4 progress to lockable
for n_marked in 1:4  # anything to itself
    for i in (1+n_marked):(6+n_marked)
        P[amc_index(n_marked, i), amc_index(n_marked, i)] = 1 - sum(two_d6_pdf[(i+1):(7+n_marked)])
    end
end
for n_marked in 1:3  # progressing to next progress
    for i in (1+n_marked):(6+n_marked)
        for j in (i+1):(7+n_marked)
            P[amc_index(n_marked, i), amc_index(n_marked+1, j)] = two_d6_pdf[j]
        end
    end
end
update_QNT!(P, Q, N, T)
const basic_amc_T = copy(T)  # expected number of steps before being absorbed for each transient state


## Repeatedly pruning to remove branches that you wouldn't take

for k in 1:10
    # removing bad branches back to front
    for n_marked in reverse(1:3)  # for each n_marked
        for i in reverse((1+n_marked):(6+n_marked))  # for each starting branch
            for j in reverse((i+1):(7+n_marked))  # for each ending branch
                if T[amc_index(n_marked, i)] < T[amc_index(n_marked+1, j)]
                    P[amc_index(n_marked, i), amc_index(n_marked, i)] += P[amc_index(n_marked, i), amc_index(n_marked+1, j)]
                    P[amc_index(n_marked, i), amc_index(n_marked+1, j)] = 0
                    update_QNT!(P, Q, N, T)
                end
            end
        end
    end
    # removing bad frontmost branches
    for i in 2:7
        if T[1] < T[amc_index(1, i)]
            P[1,1] += P[1, amc_index(1, i)]
            P[1, amc_index(1, i)] = 0
            update_QNT!(P, Q, N, T)
        end
    end
end
const updated_amc_T = copy(T)


# Bmhowe34'sm values (slide 15)
# https://drive.google.com/file/d/0B0E4VFlFjnCuazZYVE5idFJBWDg/view?resourcekey=0-iFBYeJbhhIz7EwfCrMMd_Q
const bmhowe34_amc_T = [26.2, 17.17, 18.7, 20.5, 23.2, 29.4, 46.2, 8.8, 9.7, 12.9, 15.8, 23.4, 39.0, 4.3, 5.0, 6.7, 9.4, 16.2, 30.0, 1.4, 1.8, 2.6, 4.0, 7.2, 18.0]

const high_cost = 100
const rolls_to_lockable_to_score = 1.


function amc_cost_function(T::Vector{<:Real}, dice_roll::Int, ts::TrackState, track_locked::Bool; progress::Int=ts.progress, n_marked_increase::Int=1)
    # TODO: make it a points-based cost function? ~3 points per turn
    @assert 0 < n_marked_increase <= 2
    proposed_progress = dice_number_to_progress(dice_roll, ts)
    skips = (proposed_progress - progress) - 1
    # println("$dice_roll, $proposed_progress, $(ts.n_marked), $(ts.progress), $(ts.reversed), $track_locked, $progress, $n_marked_increase")
    
    # ignore illegal moves
    if track_locked || skips < 0 || (proposed_progress == 12 && ts.n_marked < marks_for_track_lock)
        return high_cost
    end

    # lock if you can!
    if proposed_progress == 12 && ts.n_marked >= marks_for_track_lock
        return -high_cost
    end

    # heavily discourage moves that would make the track impossible to lock
    if ((ts.n_marked + n_marked_increase) < marks_for_track_lock) && proposed_progress >= (ts.n_marked + 7 + n_marked_increase)
        return high_cost/2
    end

    # TODO: decide how to weight progress after lockability (taking into account points, spaces skipped, etc.)
    if ts.n_marked >= marks_for_track_lock
        return -rolls_to_lockable_to_score * n_marked_increase
    end

    if (ts.n_marked + n_marked_increase) >= marks_for_track_lock
        return -T[amc_index(ts.n_marked, ts.progress)] - rolls_to_lockable_to_score * (ts.n_marked + n_marked_increase - marks_for_track_lock)
    end

    return T[amc_index(ts.n_marked + n_marked_increase, proposed_progress)] - T[amc_index(ts.n_marked, ts.progress)]

end


function color_roll_costs_helper(T::Vector{<:Real}, ts::TrackState, color_roll::Int, white1::Int, white2::Int, track_locked::Bool; kwargs...)
    if ts.reversed
        earlier_white, later_white = white2, white1
    else
        earlier_white, later_white = white1, white2
    end
    current_roll = color_roll + earlier_white
    smaller_roll_costs = amc_cost_function(T, current_roll, ts, track_locked; kwargs...)
    if smaller_roll_costs < high_cost
        return smaller_roll_costs, current_roll
    end
    current_roll = color_roll + later_white
    return amc_cost_function(T, current_roll, ts, track_locked; kwargs...), current_roll
end


"""
    amc_strategy(gs, player_index)

A strategy defined by taking dice to minimize the amount of dice rolls to locking out a track
"""
function amc_strategy(gs::GameState, player_index::Int; max_cost::Int=0, penalty_max_cost::Int=0, verbose::Bool=true, debug::Bool=false, T::Vector=basic_amc_T)
    # TODO prioritize tracks with more marks
    @assert player_index <= length(gs.players)
    roll = gs.roll
    ps = gs.players[player_index]
    this_players_turn = player_index == gs.whose_turn
    white_roll = roll.white1 + roll.white2

    if this_players_turn

        costs_2dice_rolls .= 0
        costs_2dice .= high_cost

        color_roll_costs_and_rolls = [color_roll_costs_helper(T, ps(color), roll(color), roll.white1, roll.white2, gs(color)) for color in track_colors]
        color_roll_costs = [color_roll_costs_and_rolls[i][1] for i in eachindex(track_colors)]
        color_rolls = [color_roll_costs_and_rolls[i][2] for i in eachindex(track_colors)]
        white_roll_costs = [amc_cost_function(T, white_roll, ps(color), gs(color)) for color in track_colors]
        if debug; println(color_roll_costs, white_roll_costs) end
        min_cost = min(minimum(color_roll_costs), minimum(white_roll_costs))

        # check for best two dice taking combo
        for i in 1:n_track_colors  # first track, taking color first
            for j in axes(costs_2dice, 2)  # second track
                if i == j
                    if color_roll_costs[i] < high_cost  # only check second dice if you could take the first
                        costs_2dice[i,j] = amc_cost_function(T, white_roll, ps(j), gs(j); progress=dice_number_to_progress(color_rolls[j], ps(j)), n_marked_increase=2)
                    end
                else
                    costs_2dice[i,j] = color_roll_costs[i] + white_roll_costs[j]
                end
            end
        end
        for i in (n_track_colors + 1):(2 * n_track_colors)  # first track, taking white first
            for j in axes(costs_2dice, 2)  # second track
                if (i - n_track_colors) == j
                    if white_roll_costs[i - n_track_colors] < high_cost
                        costs_2dice[i,j], costs_2dice_rolls[i, j] = color_roll_costs_helper(T, ps(j), roll(j), roll.white1, roll.white2, gs(j); progress=dice_number_to_progress(white_roll, ps(j)), n_marked_increase=2)
                    end
                else
                    costs_2dice[i,j] = white_roll_costs[i - n_track_colors] + color_roll_costs[j]
                end
            end
        end
        min_cost_2d = minimum(costs_2dice)

        if min(min_cost, min_cost_2d) >= penalty_max_cost  # only take a dice if it is to our taste
            if verbose
                if min_cost == high_cost
                    println("Player $player_index is taking a penalty (couldn't take anything)") 
                else
                    println("Player $player_index is taking a penalty") 
                end
            end
            return add_penalty!(gs, ps)
        end

        # if second die isn't helpful
        if min_cost < min_cost_2d
            costs = Array{Float64}(undef, n_track_colors)
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

        costs = [amc_cost_function(T, white_roll, ps(color), gs(color)) for color in track_colors]
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


# for k in 1:10
#     # removing bad branches
#     for n_marked in reverse(1:3)  # progressing to next progress
#         for i in reverse((1+n_marked):(6+n_marked))
#             for j in reverse((i+1):(7+n_marked))
#                 if ER[amc_index(n_marked, i)] < ER[amc_index(n_marked+1, j)]
#                     P[amc_index(n_marked, i), amc_index(n_marked, i)] += P[amc_index(n_marked, i), amc_index(n_marked+1, j)]
#                     P[amc_index(n_marked, i), amc_index(n_marked+1, j)] = 0
#                     update_ER!()
#                 end
#             end
#         end
#     end
#     for i in 2:7
#         if ER[1] < ER[amc_index(1, i)]
#             P[1,1] += P[1, amc_index(1, i)]
#             P[1, amc_index(1, i)] = 0
#             update_ER!()
#         end
#     end
# end
# plot(ER)

# myheat(M) = yflip!(heatmap(M))
# myheat(Q)
# myheat(N)

# function use_dr!(n_marked_progress, dr)
#     n_marked, progress = n_marked_progress
#     if (max(progress, 1+n_marked) < dr < (n_marked+8)) && (n_marked==4 || (ER[amc_index(n_marked, progress)] > ER[amc_index(n_marked+1, dr)]))
#         n_marked_progress[1] += 1
#         n_marked_progress[2] = dr
#         return true
#     end
#     return false
# end
# function use_dr!(n_marked_progress, dr1, dr2)

#     n_marked, progress = n_marked_progress
#     if dr1 > dr2
#         hold = dr1
#         dr1 = dr2
#         dr2 = hold
#     end

#     # if only the higher one is usable, just use that
#     if (dr1 <= progress) || (dr1==dr2); return use_dr!(n_marked_progress, dr2) end

#     # if dr1 and 2 are unique and > progress, try using dr1 then dr2
#     used_dr = use_dr!(n_marked_progress, dr1)
#     use_dr!(n_marked_progress, dr2)

#     # see if we should use both if using dr1
#     if !used_dr && n_marked < 4
#         if (max(progress, 2+n_marked) < dr2 < (n_marked+9)) && (n_marked==4 || (ER[amc_index(n_marked, progress)] > ER[amc_index(n_marked+2, dr2)]))
#             println("chose double!")
#             println("nm: ", n_marked, "cur: ", progress, "d1: ", dr1, "d2: ", dr2)
#             n_marked_progress[1] += 2
#             n_marked_progress[2] = dr2
#             return true
#         end
#     end
#     return used_dr
# end

# function sample_rolls(n_marked::Int=0, progress::Int=0)
#     n_marked_progress = [n_marked, progress]
#     rolls = 0
#     while rolls < 500 && n_marked_progress[1] < 5
#         rolls += 1
#         dr = roll(two_d6)
#         use_dr!(n_marked_progress, dr)
#     end
#     return rolls
# end

# n_test = 10000
# empirical = zeros(t)
# empirical[1] = mean([sample_rolls() for i in 1:n_test])
# for n_marked in 1:4
#     empirical[amc_index.(n_marked, (n_marked+1):(n_marked+6))] .= [mean([sample_rolls(n_marked, i) for j in 1:n_test]) for i in (n_marked+1):(n_marked+6)]
# end

# rolls_to_lockable = zeros(4,10) .+ Inf
# for n_marked in 1:4
#     rolls_to_lockable[n_marked, (n_marked+1):(n_marked+6)] .= ER[amc_index.(n_marked, (n_marked+1):(n_marked+6))]
# end
# rolls_to_lockable[1] = ER[1]
# rolls_to_lockable_emp = zeros(4,10) .+ Inf
# for n_marked in 1:4
#     rolls_to_lockable_emp[n_marked, (n_marked+1):(n_marked+6)] .= empirical[amc_index.(n_marked, (n_marked+1):(n_marked+6))]
# end
# rolls_to_lockable_emp[1] = empirical[1]
# rolls_to_lockable_emp
# rolls_to_lockable

# function sample_rolls2(n_marked::Int=0, progress::Int=0)
#     n_marked_progress = [n_marked, progress]
#     rolls = 0
#     while rolls < 500 && n_marked_progress[1] < 5
#         if iseven(rolls)
#             dr = roll(d6)
#             use_dr!(n_marked_progress, dr + roll(d6), dr + roll(d6))
#         else
#             dr = roll(two_d6)
#             use_dr!(n_marked_progress, dr)
#         end
#     end
#     return rolls
# end

# sample_rolls2()


