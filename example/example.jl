using Pkg
Pkg.activate("examples")
Pkg.instantiate()

# Pkg.develop(;path="C:\\Users\\Christian\\Dropbox\\Quixx")

import Quixx as Q

strategy1(gs, player_index; kwargs...) = Q.minimize_skips_strategy(gs, player_index; max_skip=1, kwargs...)
strategy2(gs, player_index; kwargs...) = Q.minimize_skips_strategy(gs, player_index; max_skip=2, kwargs...)

Q.run_game([Q.PlayerState(strategy1), Q.PlayerState(strategy2)]; verbose=true)