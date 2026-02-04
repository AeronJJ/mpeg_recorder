CC      := gcc
CFLAGS  := -Wall -Wextra -O2
LDFLAGS := -lrt

TARGET  := main
SRC     := main.c

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

clean:
	rm -f $(TARGET)

.PHONY: all clean
