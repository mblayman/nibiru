.PHONY: docs

CFLAGS += -I/usr/local/Cellar/lua/5.4.6/include/lua
CFLAGS += -L/usr/local/Cellar/lua/5.4.6/lib
CFLAGS += -llua

build: exe lib

lib:
	cc \
	$(CFLAGS) \
	-shared -fPIC \
	src/libnibiru.c \
	-o lua/nibiru_core.so

exe:
	cc \
	$(CFLAGS) \
	src/main.c \
	-o nibiru

run: build
	./nibiru run docs.app:app

clean:
	rm -rf out nibiru lua/nibiru_core.so rocks

deps:
	luarocks --tree .luarocks install luatest

format:
	clang-format -i src/**.c

req:
	@printf 'GET / HTTP/1.1\r\n\r\n' | nc 127.0.0.1 8080

docs: clean
	mkdir out
	~/.local/share/nvim/mason/bin/lua-language-server --doc lua/nibiru --doc_out_path out

test-packaging: clean
	luarocks make --tree ./rocks
	tree rocks
