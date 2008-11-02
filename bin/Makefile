LDFLAGS = -ltcl
CFLAGS = -Wall -W
BINS = rivet.cgi

all: $(BINS)

rivet.cgi: rivet
	rm -f rivet.cgi
	ln rivet rivet.cgi

rivet: rivet.o
rivet.o: rivet.c

.PHONY: clean

clean:
	rm -f $(BINS) rivet *.o
