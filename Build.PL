use Module::Build;

my $build = Module::Build->new
  (
   module_name => 'etree-scripts',
   dist_version => '3.2',
   license => 'perl',
   dist_abstract => "Useful scripts for managing, converting, " .
   "and burning losslessly compressed audio files",
   dist_author => 'Caleb Epstein <caleb.epstein@gmail.com>',
   requires => {
		'Date::Parse'    => 0,
		'HTML::Entities' => 0,
		'Digest::MD5'    => 0
	       },

   pm_files => { 'Etree/InfoFile.pm' => 'lib/Etree/InfoFile.pm' },

   script_files => [ "md5check", "unshn", "burn-shns",
		     "cdfill", "makehbx", "shn2mp3", "shn2ogg",
		     "make-toc", "flacify", "parseinfo" ],
  );

$build->create_build_script;
