SCRIPTS = md5check unshn burn-shns shn cdfill makehbx shn2mp3 make-toc

DESTDIR =
prefix = $(DESTDIR)/usr

all : $(SCRIPTS)

install : $(SCRIPTS)
	mkdir -p $(prefix)/bin
	install -m 755 $(SCRIPTS) $(prefix)/bin
	( cd $(prefix)/bin && ln -s unshn unflac )

clean :
	@echo Nothing to clean

tarball :
	tar cvfz ../etree-scripts.tar.gz $(SCRIPTS) unflac

