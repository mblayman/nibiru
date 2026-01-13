# Makefile.test - Build and run C unit tests with Unity

CC=gcc
CFLAGS=-I../src -I. -Wall -Wextra -std=c99 -D_GNU_SOURCE

.PHONY: all clean run

all: test_runner

test_runner: test_parse.o test_main.o unity.o ../src/parse.o ../src/static.o
	$(CC) $(CFLAGS) $^ -o $@

run: all
	./test_runner

unity.o: unity.c unity.h unity_internals.h
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f *.o test_runner