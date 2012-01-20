
CC=gcc
NUWEB=~/MyWork/myweb/myweb.py
CFLAGS+=`sdl-config --cflags` -W -Wall -O0 -I/usr/include/libpng12/
LDFLAGS+=-pg
LIBS+=`sdl-config --libs` -lSDL_image -lGL -lm
SOURCES=main.c os_specific.c event.c collision.c characters.c bullets.c levels.c timers.c player.c damage.c bonuses.c font.c dialog.c panel.c dlist.c
OBJECTS=$(SOURCES:.c=.o)
EXECUTABLE=danmaku

all: $(SOURCES) $(EXECUTABLE)

$(EXECUTABLE): $(OBJECTS) 
	$(CC) $(LDFLAGS) $^ -o $@ $(LIBS)

main.c: main.w
	$(NUWEB) $<

.c.o:
	$(CC) -c $(LDFLAGS) $(CFLAGS) $<

.PHONY: clean

clean:
	rm -f $(OBJECTS)
