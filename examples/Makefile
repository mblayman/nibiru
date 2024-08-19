CFLAGS += -I/usr/local/Cellar/lua/5.4.6/include/lua
CFLAGS += -L/usr/local/Cellar/lua/5.4.6/lib
CFLAGS += -llua

ip:
	cc showip.c -o showip.out

simp:
	cc simpleserver.c -o simpleserver.out
	cc simpleclient.c -o simpleclient.out

lua:
	cc $(CFLAGS) calllua.c -o calllua.out

workers:
	cc workers.c -o workers.out
