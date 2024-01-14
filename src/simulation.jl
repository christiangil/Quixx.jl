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


"""
    update_TrackState!(ts::TrackState, dice_roll::Int; n_marked_increase::Int=1)

Update a track state with new progress, returns whether or not the track was locked
"""
function update_TrackState!(ts::TrackState, dice_roll::Int; n_marked_increase::Int=1)
    @assert 1 <= n_marked_increase <= 2  # could be recording two dice rolls of progress at once
    proposed_progress = track_convert(dice_roll, ts)
    @assert proposed_progress > ts.progress
    just_locked = proposed_progress == 12
    if just_locked; @assert ts.n_marked >= 5 end
    ts.progress = proposed_progress
    ts.n_marked += just_locked + n_marked_increase
    validate_TrackState(ts)
    return just_locked
end


is_locked(ts::TrackState) = ts.progress==12


track_convert(progress::Int, ts::TrackState) = ts.reversed ? (14 - progress) : progress


"""
    validate_PlayerState(penalties)

Ensures that the proposed PlayerState is valid
"""
function validate_PlayerState(red, yellow, green, blue, penalties)
    validate_TrackState(red)
    validate_TrackState(yellow)
    validate_TrackState(green)
    validate_TrackState(blue)
    @assert 0 <= penalties < 5
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
    str = ""
    for i in eachindex(track_colors)
        str *= color_emojis[i] * ": $(roll(i)) "
    end
    str *= white_emoji * white_emoji * ": $(roll.white1), $(roll.white2)"
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
function println(roll::Roll)
    str = ""
    for i in eachindex(track_colors)
        str *= color_emojis[i] * ": $(roll(i)) "
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
(ps::GameState)(s::String) = getproperty(ps, Symbol(s * "_locked"))
(ps::GameState)(i::Int) = getproperty(ps, Symbol(track_colors[i]))


"""
    update_PlayerState!(ts::TrackState, dice_roll::Int; n_marked_increase::Int=1)

Update a player's track state with new progress, returns whether or not the game is over
"""
function update_PlayerState!(gs::GameState, ps::PlayerState, choice::String, dice_roll::Int; kwargs...)
    setproperty!(gs, Symbol(choice * "_locked"), update_TrackState!(ps(choice), dice_roll; kwargs...) || gs(choice))
    if sum([gs(color) for color in track_colors]) >= 2
        gs.game_over = true
    end
    return gs.game_over
    # if choice == 1
    #     gs.red_locked = update_TrackState(ps.red, dice_roll; kwargs...) || gs.red_locked
    # end
    # if choice == 2
    #     gs.yellow_locked = update_TrackState(ps.yellow, dice_roll; kwargs...) || gs.yellow_locked
    # end
    # if choice == 3
    #     gs.green_locked = update_TrackState(ps.green, dice_roll; kwargs...) || gs.green_locked
    # end
    # if choice == 4
    #     gs.blue_locked = update_TrackState(ps.blue, dice_roll; kwargs...) || gs.blue_locked
    # end    
end
update_PlayerState!(gs::GameState, ps::PlayerState, choice::Int, dice_roll::Int; kwargs...) = 
    update_PlayerState!(gs, ps, track_colors[choice], dice_roll; kwargs...)


const max_penalties = 4


function add_penalty!(gs::GameState, ps::PlayerState; max_pen::Int=max_penalties)
    ps.penalties += 1
    if ps.penalties >= max_pen
        gs.game_over = true
    end
    return gs.game_over
end


const triangular_numbers = Int.([n*(n+1)/2 for n in 0:12])
score(ts::TrackState) = triangular_numbers[ts.n_marked+1]
"""
    score(ps)

Calulates the player's current score
"""
score(ps::PlayerState) = score(ps.red) + score(ps.yellow) + score(ps.blue) + score(ps.green) - 5 * penalties


function run_game(players; verbose::Bool=true)
    if verbose; println("Let's Quixx!") end
    gs = GameState(players)
    while !gs.game_over
        if verbose
            println("Player $(gs.whose_turn)'s turn")
            println(gs.roll)
        end
        for i in eachindex(players)
            players[i].strategy(gs, i; verbose=verbose)
        end
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
        if length(winning_score) > 0
            println("Players $winners tied for the win!")
        else
            pritnln("Player $(winners[1]) won!")
        end
    end
    return winners
end