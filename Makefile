SCRIPTS = md5check unshn burn-shns shn cdfill makehbx shn2mp3 make-toc

DESTDIR =
prefix = $(DESTDIR)/usr

all : $(SCRIPTS)

install : $(SCRIPTS)
	mkdir -p $(prefix)/bin
	install -m 755 $(SCRIPTS) $(prefix)/bin
	( cd $(prefix)/bin && ln -s unshn unflac )

clean :
	@echo Nothing to do

tarball : clean
	( dir=`pwd`; base=`basename $$dir`; cd ..; \
	  tar --exclude CVS --exclude .cvsignore -cvzf $$base.tar.gz $$base )
