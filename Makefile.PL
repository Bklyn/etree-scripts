#!/usr/bin/perl
#
# MakeMaker script for etree-scripts
#
# $Id$

use ExtUtils::MakeMaker;

WriteMakefile (
	       NAME => "etree-scripts",
	       ABSTRACT => "Useful scripts for managing, converting, " .
	       			"and burning losslessly compressed audio files",
	       VERSION => "2.1",
	       AUTHOR => 'Caleb Epstein <cae@bklyn.org>',

	       EXE_FILES => [ "md5check", "unshn", "burn-shns",
			      "cdfill", "makehbx", "shn2mp3", "shn2ogg",
			      "make-toc", "flacify" ],

	       PREREQ_PM => { "Date::Parse" => 0,
			      "HTML::Entities" => 0,
			      "Digest::MD5" => 0 },

	       PM => { "Etree/InfoFile.pm" =>
		       '$(INST_LIBDIR)/Etree/InfoFile.pm' },
	      );
