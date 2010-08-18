
CC=gcc
NUWEB=nuweb
CFLAGS?=`sdl-config --cflags` -Wall
LIBS?=`sdl-config --libs` -lSDL_image -lGL -lGLU -lm
SOURCES=main.c os_specific.c event.c collision.c characters.c bullets.c levels.c timers.c player_coord.c damage.c
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
