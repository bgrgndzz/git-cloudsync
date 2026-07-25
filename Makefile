PREFIX ?= $(HOME)/.local
BINDIR := $(PREFIX)/bin

.PHONY: install uninstall test

install:
	mkdir -p $(BINDIR)
	rm -f $(BINDIR)/cloudsync $(BINDIR)/git-cloudsync
	install -m 755 cloudsync $(BINDIR)/cloudsync
	ln -sf $(BINDIR)/cloudsync $(BINDIR)/git-cloudsync
	@echo "installed: $(BINDIR)/cloudsync"

uninstall:
	rm -f $(BINDIR)/cloudsync $(BINDIR)/git-cloudsync

test:
	bash test/test.sh
