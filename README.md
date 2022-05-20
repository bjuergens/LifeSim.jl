# LifeSim.jl

## getting started 

dont install julia from apt-get, because it's too old. Use official release instead: https://julialang.org/downloads/

```zsh
 
# install julia from download
sudo apt remove julia
sudo mv julia-1.7.2 /opt/julia
sudo ln -s /opt/julia/bin/julia /usr/local/bin/julia


git clone ssh://git@wotanii.de:22123/wotanii/LifeSim.jl.git
cd LifeSim.jl
julia -e 'using Pkg; Pkg.develop(path=".")'
julia -e 'using LifeSim; main()'
```

```zsh
julia -e 'import Pkg; Pkg.activate("."); using LifeSim; main()'
```

Now you can hot-reload the repo by clicking the "revise"-button in the gui. 

Note: hot-reloading only works when starting as a module. Also not all parts of the code can be hot-reloaded. 

to run individual files directly from VSCode:

* File -> Preferences -> setting -> workspace -> extentions -> julia
* todo??


# dev notes

## hotloading in REPL

```julia
using Revise
import LifeSim.LSEvolutionTest.doTest
doTest()
```

## add deps


```
# julia -> ']'
activate .
add $packet
resolve
# git commit Project.toml
# ggf noch (warum?)
import Pkg
Pkg.resolve()
```

## workflow

every src-file exept the main-sourcefile contains a main module and a test module. The latter is executed when running the sourcefile as a script. 

The general workflow is to start the main loop from the module. Then modifying a sourcefile, then running the sourcefile directly (ctrl+f5 in vscode) to see if the tests still pass and at last clicking the revise-button to hot-reload into the running window. 

## benchmark

benchmark funktioniert nicht gut mit scripten. Daher folgendes einzeln in einen julia REPL kopieren:

```julia
include("src/neural.jl")
using StaticArrays
using BenchmarkTools
using .LSNaturalNet
dim_in,dim_N,dim_out = (20,50,10)
gen_size = genome_size(dim_in,dim_N,dim_out)

rand_gen = randn((SVector){gen_size, Float32})
           
rand_net = NaturalNet(rand_gen, input_dim=dim_in, neural_dim=dim_N, output_dim=dim_out)

@benchmark NaturalNet(rand_genome, input_dim=dim_in, neural_dim=dim_N, output_dim=dim_out) setup=( rand_genome=randn((SVector){gen_size, Float32}) )
@benchmark step!(rand_net, rand_input) setup=(rand_input = randn((SVector){dim_in, Float32}))
```

result as of now:

```
julia> @benchmark NaturalNet(rand_genome, input_dim=dim_in, neural_dim=dim_N, output_dim=dim_out) setup=( rand_genome=randn((SVector){gen_size, Float32}) )

BenchmarkTools.Trial: 10000 samples with 1 evaluation.
 Range (min … max):  19.743 μs …  1.243 ms  ┊ GC (min … max): 0.00% … 90.82%
 Time  (median):     20.969 μs              ┊ GC (median):    0.00%
 Time  (mean ± σ):   24.066 μs ± 41.462 μs  ┊ GC (mean ± σ):  7.41% ±  4.24%

  ▅██▇▅▃▃▂▁▂▁                                                 ▂
  ████████████████▇▇▅▅▅▆▅▄▅▃▇█████████▇▆▆▅▆▆▁▄▁▅▃▅▄▅▄▃▃▄▅▅▆▆▇ █
  19.7 μs      Histogram: log(frequency) by time      49.8 μs <

 Memory estimate: 81.44 KiB, allocs estimate: 46.


julia> @benchmark step!(rand_net, rand_input) setup=(rand_input = randn((SVector){dim_in, Float32}))

BenchmarkTools.Trial: 10000 samples with 9 evaluations.
 Range (min … max):  2.985 μs … 295.155 μs  ┊ GC (min … max): 0.00% … 97.12%
 Time  (median):     3.293 μs               ┊ GC (median):    0.00%
 Time  (mean ± σ):   4.072 μs ±   5.831 μs  ┊ GC (mean ± σ):  3.36% ±  2.38%

  ▅██▇▅▃▂▁ ▂▂▄▄▄▃▂▂▂▂▃▃▂▂▁▁▁▁   ▁▁ ▁▂▂▁▁                      ▂
  ████████████████████████████████████████▇▇▇▇▇▆▆▆▆▆▅▆▆▇▆▅▅▄▄ █
  2.98 μs      Histogram: log(frequency) by time      8.55 μs <

 Memory estimate: 3.06 KiB, allocs estimate: 20.
```

```julia
julia> @benchmark mutate_genome_duo(data...) setup=(data=(randn(50),0.1))
BenchmarkTools.Trial: 10000 samples with 182 evaluations.
 Range (min … max):  579.692 ns …   5.470 μs  ┊ GC (min … max): 0.00% … 83.99%
 Time  (median):     655.445 ns               ┊ GC (median):    0.00%
 Time  (mean ± σ):   706.123 ns ± 358.661 ns  ┊ GC (mean ± σ):  4.84% ±  8.22%

    ▄▆█▅▃▃▂▂▁ ▁                                                 ▁
  ▅▇████████████▇▅▆▅▅▅▄▅▃▄▁▄▁▄▄▃▁▁▁▁▁▁▁▁▁▄▁▁▁▃▃▃▃▄▅▃▃▅▆█▇▆▆▅▄▃▁ █
  580 ns        Histogram: log(frequency) by time       1.63 μs <

 Memory estimate: 2.42 KiB, allocs estimate: 5.

julia> @benchmark crossover_genome(data...) setup=(data=(randn(50),randn(50)))
BenchmarkTools.Trial: 10000 samples with 198 evaluations.
 Range (min … max):  445.621 ns … 12.457 μs  ┊ GC (min … max):  0.00% … 91.37%
 Time  (median):     506.020 ns              ┊ GC (median):     0.00%
 Time  (mean ± σ):   624.465 ns ±  1.075 μs  ┊ GC (mean ± σ):  16.55% ±  9.13%

  ▁▄▆▇█▇▅▃▃▃▂▂▃▃▁                                              ▂
  █████████████████▇▇▆▆▅▅▅▄▅▄▄▄▁▄▄▄▃▄▄▄▅▄▅▅▄▆▆▅▅▅▄▁▃▄▄▆▆▅▅▄▅▄▅ █
  446 ns        Histogram: log(frequency) by time      1.22 μs <

 Memory estimate: 2.10 KiB, allocs estimate: 8.
``` 