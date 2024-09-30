
all: build

setup:
	@julia --project -e 'import Pkg; Pkg.instantiate()'
	@julia --project=scripts/build -e 'import Pkg; Pkg.develop(path=@__DIR__)'

build:
	@julia --project=scripts/build ./scripts/build/build.jl

clear:
	@rm -rf ./dist

run: setup
	@julia --project=scripts/run/mqlib ./scripts/run/mqlib/run.jl

setup-docs:
	@julia --project=docs -e 'import Pkg; Pkg.develop(path=@__DIR__); Pkg.instantiate()'

docs:
	@julia --project=docs ./docs/make.jl --skip-deploy
