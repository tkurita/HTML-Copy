#!perl -w
use strict;
use ExtUtils::MakeMaker;

my @programs_to_install = qw(htmlcopy);

WriteMakefile(
	'NAME'			=> 'HTML::Copy',
	'VERSION_FROM' 	=> 'lib/HTML/Copy.pm',
	'EXE_FILES'     => [ map {"bin/$_"} @programs_to_install ],
	'PREREQ_PM' => {
		'Test::More'   => 0,
		'HTML::Parser' => 3.40
	},
	'dist'           => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },	
	'clean'          => { FILES => 'HTML-Copy-*' },

);
