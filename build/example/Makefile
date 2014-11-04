TESTS = test1.cgi test2.cgi

all: $(TESTS)

%.cgi: %.kit
	~/devel/starkit2exe/starkit2exe $^ $@

%.kit: %.vfs
	../../bin/rivet2starkit tclkit $@ $^

test1.cgi: test1.kit
test1.kit: test1.vfs
test2.cgi: test2.kit
test2.kit: test2.vfs

clean:
	rm -f $(TESTS) *.kit

distclean: clean

.PHONY: all clean distclean
