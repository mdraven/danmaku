
CC=gcc
NUWEB=~/MyWork/myweb/myweb.py
CFLAGS+=`sdl-config --cflags` -Wall -O0 -I/usr/include/libpng12/
LIBS+=`sdl-config --libs` -lSDL_image -lGL -lm 
SOURCES=main.c os_specific.c event.c collision.c characters.c bullets.c levels.c timers.c player.c damage.c bonuses.c font.c dialog.c
OBJECTS=$(SOURCES:.c=.o)
EXECUTABLE=danmaku

all: $(SOURCES) $(EXECUTABLE)

$(EXECUTABLE): $(OBJECTS) 
	$(CC) $(LIBS) $(LDFLAGS) $^ -o $@

main.c: main.w
	$(NUWEB) $<

.c.o:
	$(CC) -c $(CFLAGS) $<

.PHONY: clean

clean:
	rm -f $(OBJECTS)
