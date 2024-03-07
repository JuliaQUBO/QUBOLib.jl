
all: build

setup:
	@julia --project -e 'import Pkg; Pkg.instantiate()'
	@julia --project=scripts/build -e 'import Pkg; Pkg.develop(path=@__DIR__)'

build:
	@julia --project=scripts/build ./scripts/build/build.jl

clear-build:
	@julia --project=scripts/build ./scripts/build/build.jl --clear-build

run: setup
	@julia --project=scripts/run/mqlib ./scripts/run/mqlib/run.jl
