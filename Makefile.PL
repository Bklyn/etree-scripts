use ExtUtils::MakeMaker;

WriteMakefile (
	       NAME => "Etree::InfoFile",
	       VERSION => 2.000,
	       AUTHOR => "Caleb Epstein <cae@bklyn.org>",
	       EXE_FILES => [ "md5check", "unshn", "burn-shns", "shn",
			      "cdfill", "makehbx", "shn2mp3", "make-toc",
			      "flacify" ],
	      );
