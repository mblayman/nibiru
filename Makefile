build:
	cc \
		src/main.c \
		-o nibiru

format:
	clang-format -i src/**.c
