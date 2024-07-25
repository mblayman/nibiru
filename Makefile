.PHONY: docs

CFLAGS += -I/usr/local/Cellar/lua/5.4.6/include/lua
CFLAGS += -L/usr/local/Cellar/lua/5.4.6/lib
CFLAGS += -llua

build:
	cc \
	$(CFLAGS) \
	src/main.c \
	-o nibiru

run: build
	./nibiru docs.app:app

clean:
	rm -rf out nibiru

deps:
	luarocks --tree .luarocks install luatest

format:
	clang-format -i src/**.c

req:
	@printf 'GET /\n\n' | nc 127.0.0.1 8080

docs: clean
	mkdir out
	~/.local/share/nvim/mason/bin/lua-language-server --doc lua/nibiru --doc_out_path out
