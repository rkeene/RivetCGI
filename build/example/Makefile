TESTS = test1.cgi

all: $(TESTS)

%.cgi: %.kit
	~/devel/starkit2exe/starkit2exe $^ $@

%.kit: %.vfs
	../../bin/rivet2starkit tclkit $@ $^

test1.cgi: test1.kit
test1.kit: test1.vfs

clean:
	rm -f $(TESTS) *.kit

distclean: clean

.PHONY: all clean distclean
