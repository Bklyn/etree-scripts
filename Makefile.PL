#!/usr/bin/perl
#
# MakeMaker script for etree-scripts
#
# $Id$

use ExtUtils::MakeMaker;

WriteMakefile (
	       NAME => "etree-scripts",
	       VERSION => "2.0",
	       AUTHOR => "Caleb Epstein <cae@bklyn.org>",

	       EXE_FILES => [ "md5check", "unshn", "burn-shns",
			      "cdfill", "makehbx", "shn2mp3", "shn2ogg",
			      "make-toc", "flacify" ],

	       PM => { "Etree/InfoFile.pm" =>
		       '$(INST_LIBDIR)/Etree/InfoFile.pm' },
	      );
