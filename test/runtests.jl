import Quixx as Q
using Test
using LinearAlgebra

const n_trials = 1000

@testset "Singleplayer" begin

    function strategy_integration_test(strategies)
        for strategy in strategies
            for i in 1:n_trials
                Q.run_game([Q.PlayerState(strategy)]; verbose=false);
            end
        end
        return true
    end
    
    @test strategy_integration_test([(gs, player_index; kwargs...) -> Q.minimize_skips_strategy(gs, player_index; max_cost=i, kwargs...) for i in 0:2])
    @test strategy_integration_test([(gs, player_index; kwargs...) -> Q.minimize_skips_strategy(gs, player_index; penalty_max_cost=i, kwargs...) for i in 1:3])
    @test strategy_integration_test([(gs, player_index; kwargs...) -> Q.amc_strategy(gs, player_index; T=amc_T, kwargs...) for amc_T in [Q.basic_amc_T, Q.updated_amc_T, Q.bmhowe34_amc_T]])
end


@testset "Multiplayer" begin
    strategy1(gs, player_index; kwargs...) = Q.minimize_skips_strategy(gs, player_index; max_cost=1, kwargs...)
    strategy2(gs, player_index; kwargs...) = Q.minimize_skips_strategy(gs, player_index; max_cost=2, kwargs...)
    for i in 1:n_trials
        Q.run_game([Q.PlayerState(strategy1), Q.PlayerState(strategy2)]; verbose=false);
    end
    @test true  # we got through the games without erroring out
end


# @testset "Absorbing Markov Chain strategies" begin
#     n_test = 10000
#     empirical = zeros(Quixx.t)
#     empirical[1] = mean([sample_rolls() for i in 1:n_test])
#     for n_marked in 1:4
#         empirical[index.(n_marked, (n_marked+1):(n_marked+6))] .= [mean([sample_rolls(n_marked, i) for j in 1:n_test]) for i in (n_marked+1):(n_marked+6)]
#     end
# end
