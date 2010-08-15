
CC=gcc
NUWEB=nuweb -d
CFLAGS?=`sdl-config --cflags` -Wall
LIBS?=`sdl-config --libs` -lSDL_image -lGL -lGLU -lm
SOURCES=main.c os_specific.c event.c collision.c characters.c bullets.c levels.c timers.c player_coord.c
OBJECTS=$(SOURCES:.c=.o)
EXECUTABLE=danmaku

all: $(SOURCES) $(EXECUTABLE)

$(EXECUTABLE): $(OBJECTS) 
	$(CC) $(LIBS) $(LDFLAGS) $^ -o $@

$(SOURCES): main.w
	$(NUWEB) $<

.c.o:
	$(CC) -c $(CFLAGS) $<

.PHONY: clean

clean:
	rm -f $(OBJECTS)
