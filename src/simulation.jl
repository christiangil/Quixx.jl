import Base.println

"""
    validate_TrackState(n_marked, progress)

Ensures that the proposed TrackState is valid
"""
function validate_TrackState(n_marked, progress)
    @assert 0 <= n_marked <= 12
    @assert 1 <= progress <= 12
    if progress==12
        @assert n_marked > 6
        @assert n_marked <= progress
    else
        @assert n_marked < progress
    end
end


"""
    TrackState

Keeps track of a given track (haha)
"""
mutable struct TrackState
    "How many marks have been made in the track"
    n_marked::Int
    "What number they are on on the track from 2-12 (1 indicates they haven't started yet)"
    progress::Int
    "Whether the track is 2-12 or 12-2 (false for red and yellow tracks, true for green and blue tracks)"
    reversed::Bool
    function TrackState(n_marked, progress, reversed)
		validate_TrackState(n_marked, progress)
		return new(n_marked, progress, reversed)
	end
end
validate_TrackState(ts::TrackState) = validate_TrackState(ts.n_marked, ts.progress)
TrackState(reversed) = TrackState(0, 1, reversed)


const marks_for_track_lock = 5


"""
    update_TrackState!(ts::TrackState, dice_roll::Int; n_marked_increase::Int=1)

Update a track state with new progress, returns whether or not the track was locked
"""
function update_TrackState!(ts::TrackState, dice_roll::Int; n_marked_increase::Int=1)
    @assert 1 <= n_marked_increase <= 2  # could be recording two dice rolls of progress at once
    proposed_progress = dice_number_to_progress(dice_roll, ts)
    @assert proposed_progress > ts.progress
    just_locked = proposed_progress == 12
    if just_locked; @assert ts.n_marked >= marks_for_track_lock end
    ts.progress = proposed_progress
    ts.n_marked += just_locked + n_marked_increase
    validate_TrackState(ts)
    return just_locked
end


is_locked(ts::TrackState) = ts.progress==12


dice_number_to_progress(dice_number::Int, reversed::Bool) = reversed ? (14 - dice_number) : dice_number
dice_number_to_progress(dice_number::Int, ts::TrackState) = dice_number_to_progress(dice_number, ts.reversed)
progress_to_dice_number(progress::Int, x) = dice_number_to_progress(progress, x)


const max_penalties = 4


"""
    validate_PlayerState(penalties)

Ensures that the proposed PlayerState is valid
"""
function validate_PlayerState(red, yellow, green, blue, penalties)
    validate_TrackState(red)
    validate_TrackState(yellow)
    validate_TrackState(green)
    validate_TrackState(blue)
    @assert 0 <= penalties <= max_penalties
end


const track_colors = ["red", "yellow", "green", "blue"]
const n_track_colors = length(track_colors)
const track_color_to_ind = Dict("red" => 1, "yellow" => 2, "green" => 3, "blue" => 4)


"""
    PlayerState

Keeps track of a player's board state
"""
mutable struct PlayerState
    red::TrackState
    yellow::TrackState
    green::TrackState
    blue::TrackState
    penalties::Int
    strategy::Function
    function PlayerState(red, yellow, green, blue, penalties, strategy)
		validate_PlayerState(red, yellow, green, blue, penalties)
		return new(red, yellow, green, blue, penalties, strategy)
	end
end
validate_PlayerState(ps::PlayerState) = validate_PlayerState(ps.red, ps.yellow, ps.green, ps.blue, ps.penalties)
PlayerState(strategy) = PlayerState(TrackState(0, 1, false), TrackState(0, 1, false), TrackState(0, 1, true), TrackState(0, 1, true), 0, strategy)
(ps::PlayerState)(s::String) = getproperty(ps, Symbol(s))
(ps::PlayerState)(i::Int) = getproperty(ps, Symbol(track_colors[i]))
function println(ps::PlayerState)
    str = "Player progress, "
    for i in eachindex(track_colors)
        ts = ps(i)
        ts.progress == 1 ? dice_number = "None" : dice_number = string(progress_to_dice_number(ts.progress, ts))
        str *= color_emojis[i] * ": $dice_number ($(ts.n_marked)) "
    end
    str *= "Penalties: $(ps.penalties)"
    println(str)
end

"""
    validate_GameState(red_locked, yellow_locked, green_locked, blue_locked, game_over)

Ensures that the proposed validate_GameState is valid
"""
function validate_GameState(red_locked, yellow_locked, green_locked, blue_locked, game_over, whose_turn, players)
    @assert game_over || (sum(red_locked + yellow_locked + green_locked + blue_locked) < 2)
    @assert 0 < whose_turn < (length(players) + 1)
    for player in players
        validate_PlayerState(player)
    end
end


roll_d6() = rand(1:6)
roll_two_d6() = roll_d6() + roll_d6()


"""
    Roll

Simulates a roll with the 6 Quixx die
"""
struct Roll
    red::Int
    yellow::Int
    green::Int
    blue::Int
    white1::Int
    white2::Int
    function Roll()
        white1 = roll_d6()
        white2 = roll_d6()
        if white1 > white2
            hold = white1
            white1 = white2
            white2 = hold
        end
        @assert white1 <= white2
		return new(roll_d6(), roll_d6(), roll_d6(), roll_d6(), white1, white2)
	end
end
(roll::Roll)(s::String) = getproperty(roll, Symbol(s))
(roll::Roll)(i::Int) = getproperty(roll, Symbol(track_colors[i]))
const color_emojis = ["🟥", "🟨", "🟩", "🟦"]
const white_emoji = "⬜"
function println(roll::Roll; locks::Vector{Bool}=[false, false, false, false])
    @assert length(locks) == n_track_colors
    str = ""
    for i in eachindex(track_colors)
        if locks[i]
            str *= color_emojis[i] * ": 🔒 "
        else
            str *= color_emojis[i] * ": $(roll(i)) "
        end
    end
    str *= white_emoji * white_emoji * ": $(roll.white1), $(roll.white2)"
    println(str)
end


"""
    GameState

Keeps track of the total game state
"""
mutable struct GameState
    red_locked::Bool
    yellow_locked::Bool
    green_locked::Bool
    blue_locked::Bool
    game_over::Bool
    whose_turn::Int
    players::Vector{<:PlayerState}
    roll::Roll
    function GameState(red_locked, yellow_locked, green_locked, blue_locked, game_over, whose_turn, players, roll)
		validate_GameState(red_locked, yellow_locked, green_locked, blue_locked, game_over, whose_turn, players)
		return new(red_locked, yellow_locked, green_locked, blue_locked, game_over, whose_turn, players, roll)
	end
end
validate_GameState(gs::GameState) = validate_GameState(gs.red_locked, gs.yellow_locked, gs.green_locked, gs.blue_locked, gs.game_over, gs.whose_turn, gs.players)
GameState(players) = GameState(false, false, false, false, false, 1, players, Roll())
(gs::GameState)(s::String) = getproperty(gs, Symbol(s * "_locked"))
(gs::GameState)(i::Int) = gs(track_colors[i])


const max_colors_locked = 2


"""
    update_PlayerState!(ts::TrackState, dice_roll::Int; n_marked_increase::Int=1)

Update a player's track state with new progress, returns whether or not the game is over
"""
function update_PlayerState!(gs::GameState, ps::PlayerState, choice::String, dice_roll::Int; kwargs...)
    setproperty!(gs, Symbol(choice * "_locked"), gs(choice) || update_TrackState!(ps(choice), dice_roll; kwargs...) )
    if sum([gs(color) for color in track_colors]) >= max_colors_locked
        gs.game_over = true
    end
    return gs.game_over
end
update_PlayerState!(gs::GameState, ps::PlayerState, choice::Int, dice_roll::Int; kwargs...) = 
    update_PlayerState!(gs, ps, track_colors[choice], dice_roll; kwargs...)


function add_penalty!(gs::GameState, ps::PlayerState; max_pen::Int=max_penalties)
    ps.penalties += 1
    if ps.penalties >= max_pen
        gs.game_over = true
    end
    return gs.game_over
end


const triangular_numbers = Int.([n*(n+1)/2 for n in 0:12])
const penalty_score_cost = 5


score(ts::TrackState) = triangular_numbers[ts.n_marked+1]
"""
    score(ps)

Calulates the player's current score
"""
score(ps::PlayerState) = score(ps.red) + score(ps.yellow) + score(ps.blue) + score(ps.green) - penalty_score_cost * ps.penalties


function run_game(players; verbose::Bool=true)
    if verbose; println("Let's Quixx!") end
    gs = GameState(players)
    colors_locked_previous_turn = [false for i in 1:n_track_colors]  # enables players to lock the same color on the same turn
    colors_locked = [false for i in 1:n_track_colors]  
    game_over = false  # enables players to all get their turn in final round
    total_rolls = 0
    while !gs.game_over
        total_rolls += 1
        if verbose
            println("Player $(gs.whose_turn)'s turn")
            println(gs.roll; locks=[gs(color) for color in track_colors])
        end
        for i in eachindex(players)
            if verbose; println(players[i]) end
            players[i].strategy(gs, i; verbose=verbose)
            for i in 1:n_track_colors
                colors_locked[i] = gs(i) || colors_locked[i]
                setproperty!(gs, Symbol(track_colors[i] * "_locked"), colors_locked_previous_turn[i])
            end
            game_over = gs.game_over || game_over
            gs.game_over = false
        end
        colors_locked_previous_turn .= colors_locked
        for i in 1:n_track_colors
            setproperty!(gs, Symbol(track_colors[i] * "_locked"), colors_locked[i])
        end
        if sum([gs(color) for color in track_colors]) >= max_colors_locked  # dealing with there being 0 locks then two separate colors being locked by different players in one turn
            game_over = true
        end
        gs.game_over = game_over
        gs.roll = Roll()
        gs.whose_turn = (gs.whose_turn % length(players)) + 1
        validate_GameState(gs)
    end
    scores = score.(players)
    winning_score = maximum(scores)
    winners = [i for i in eachindex(players) if scores[i]==winning_score]
    @assert 0 < length(winners) <= length(scores)
    if verbose
        println("Final Score")
        scores_string = ""
        for i in eachindex(players)
            scores_string *= "P$(i): $(scores[i]) "
        end
        println(scores_string)
        println("")
        if length(winning_score) > 1
            println("Players $winners tied for the win!")
        else
            println("Player $(winners[1]) won!")
        end
    end
    return winners, gs, total_rolls
end