import Quixx as Q
using Test
using LinearAlgebra

@testset "Running some games" begin
    strategy1(gs, player_index; kwargs...) = Q.minimize_skips_strategy(gs, player_index; max_skip=1, kwargs...)
    strategy2(gs, player_index; kwargs...) = Q.minimize_skips_strategy(gs, player_index; max_skip=2, kwargs...)
    for i in 1:1000
        Q.run_game([Q.PlayerState(strategy1), Q.PlayerState(strategy2)]; verbose=false);
    end
    @test true  # we got through the games without erroring out
end
