FLAGS=-Wall -Wextra -Werror -g

vorlua: vorlua.o crpat.o
	$(CC) -o vorlua vorlua.o crpat.o -llua5.2 -lm -L/usr/lib/arm-linux-gnueabihf
crpat.o : crpat/crpat.c
	$(CC) -o crpat.o -c crpat/crpat.c -Icrpat $(CFLAGS)
vorlua.o: vorlua.c
	$(CC) -o vorlua.o -c vorlua.c $(CFLAGS) -I. -I/usr/include/lua5.2

clean:
	rm -f vorlua *.o

