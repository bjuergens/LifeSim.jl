# LifeSim.jl

## getting started 

```zsh
git clone ssh://git@wotanii.de:22123/wotanii/LifeSim.jl.git
cd LifeSim.jl
julia -e "using Pkg; Pkg.develop(path=\"./\")"
julia -e "using LifeSim; main()"
```

```zsh
julia -e "import Pkg; Pkg.activate("."); using LifeSim; main()"
```

Now you can hot-reload the repo by clicking the "revise"-button in the gui. 

Note: hot-reloading only works when starting as a module. Also not all parts of the code can be hot-reloaded. 


# dev notes

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

