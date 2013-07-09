use Module::Build;

my $build = Module::Build->new (
    module_name => 'etree-scripts',
    license => 'perl',
    dist_version => '3.2',
    dist_abstract => "Useful scripts for managing, converting, " .
	"and burning losslessly compressed audio files",
    dist_author => 'Caleb Epstein <caleb.epstein@gmail.com>',
    requires => {
	'Digest::MD5'    => 0
    },
    recommends => {
	'Date::Parse'    => 0,	# InfoFile.pm
	'Audio::Wav'     => 0,	# unshn
	'HTML::Entities' => 0,	# makehbx
    },
    pm_files => { 'Etree/InfoFile.pm' => 'lib/Etree/InfoFile.pm' },
);

$build->create_build_script;
