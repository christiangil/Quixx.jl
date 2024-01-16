using Pkg
Pkg.activate("examples")
Pkg.instantiate()

# Pkg.develop(;path="C:\\Users\\Christian\\Dropbox\\Quixx")

import Quixx as Q
using Statistics
using Random

skip_strategy(gs, player_index; kwargs...) = Q.minimize_skips_strategy(gs, player_index; max_cost=2, kwargs...)
amc_basic_strategy(gs, player_index; kwargs...) = Q.amc_strategy(gs, player_index; T=Q.basic_amc_T, penalty_max_cost=3, kwargs...)
amc_improved_strategy(gs, player_index; kwargs...) = Q.amc_strategy(gs, player_index; T=Q.updated_amc_T, penalty_max_cost=3, kwargs...)
amc_bmhowe_strategy(gs, player_index; kwargs...) = Q.amc_strategy(gs, player_index; T=Q.bmhowe34_amc_T, penalty_max_cost=3, kwargs...)

strategies = [skip_strategy, amc_basic_strategy, amc_improved_strategy, amc_bmhowe_strategy]
n_players = length(strategies)

player_inds = 1:n_players
n_trials = 10000
scores = Array{Float64}(undef, (n_trials, n_players))
wins = zeros(Int, n_players)
total_rolls = 0
for i in 1:n_trials
    order = shuffle(player_inds)
    players = Q.PlayerState.(strategies)
    winners, gs, total_roll = Q.run_game(players[order]; verbose=false)
    for winner in winners
        wins[order[winner]] += 1
    end
    for j in 1:length(players)
        scores[i, order[j]] = Q.score(gs.players[j])
    end
    total_rolls += total_roll
end

println("Average scores: ", mean(scores, dims=1))
println("Win %: ", 100 .* (wins ./ sum(wins)))
println("Average rolls: ", (total_rolls / n_trials))
