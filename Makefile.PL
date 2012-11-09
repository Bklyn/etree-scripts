#!/usr/bin/perl
#
# MakeMaker script for etree-scripts
#
# $Id: Makefile.PL 147 2007-07-23 21:32:37Z cepstein $

use ExtUtils::MakeMaker;

WriteMakefile (
	       NAME => "etree-scripts",
	       ABSTRACT => "Useful scripts for managing, converting, " .
	       		   "and burning losslessly compressed audio files",
	       VERSION => "3.2",
	       AUTHOR => 'Caleb Epstein <caleb.epstein@gmail.com>',

	       EXE_FILES => [ "md5check", "unshn", "burn-shns",
			      "cdfill", "makehbx", "shn2mp3", "shn2ogg",
			      "make-toc", "flacify" ],

	       PREREQ_PM => { "Date::Parse" => 0,
			      "HTML::Entities" => 0,
			      "Digest::MD5" => 0 },

	       PM => { "Etree/InfoFile.pm" =>
		       '$(INST_LIBDIR)/Etree/InfoFile.pm' },
	      );
