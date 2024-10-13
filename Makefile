
all: build

setup:
	@julia --project -e 'import Pkg; Pkg.instantiate()'
	@julia --project=scripts/build -e 'import Pkg; Pkg.develop(path=@__DIR__)'

build:
	@julia --project=scripts/build scripts/build/script.jl

test-build:
	@julia --project=scripts/build --load scripts/build/runtests.jl --eval 'test_main()'

clear:
	@rm -rf ./dist

setup-docs:
	@julia --project=docs -e 'import Pkg; Pkg.develop(path=@__DIR__); Pkg.instantiate()'

docs:
	@julia --project=docs ./docs/make.jl --skip-deploy
