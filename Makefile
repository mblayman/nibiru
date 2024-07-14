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

format:
	clang-format -i src/**.c

req:
	@printf 'GET /\n\n' | nc 127.0.0.1 8080
