build:
	cc \
		src/main.c \
		-o nibiru

format:
	clang-format -i src/**.c

req:
	@printf 'GET /\n\n' | nc 127.0.0.1 8080
