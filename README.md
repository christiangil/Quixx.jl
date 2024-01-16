# Quixx.jl [![Build Status](https://github.com/christiangil/Quixx.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/christiangil/Quixx.jl/actions/workflows/CI.yml?query=branch%3Amain) [![Coverage](https://codecov.io/gh/christiangil/Quixx.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/christiangil/Quixx.jl)

<p align="center">
    <img width="400px" src="https://raw.githubusercontent.com/christiangil/Quixx.jl/main/logo/quixx.png"/>
</p>

QWIXX is a trademark of Gamewright, a division of Ceaco, Inc. No copywright infringment is intended by this project.

This is a Julia package that can run around 50000(!) Quixx games per second I made to try out different Quixx strategies. It's a fun game that you should [buy](https://gamewright.com/product/Qwixx)!

Will be running some strategy tournaments with strategies such as
- Minimizing rolls to locking with [absorbing Markov chains](https://en.wikipedia.org/wiki/Absorbing_Markov_chain) (improving upon analysis by [Bmhowe34](https://www.reddit.com/r/boardgames/comments/5l62f6/qwixx_analysis_and_strategy/))
- Taking dice as greedily as possible
- Avoiding a constant number of box skips
