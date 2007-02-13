package HTML::Copy;

use strict;
use warnings;

use File::Spec;
use File::Basename;
use Cwd;
use IO::File;

use HTML::Parser 3.40;
use HTML::HeadParser;
use base qw(HTML::Parser);

use utf8;

#use Data::Dumper;

our $VERSION = '1.0.5';

=head1 NAME

HTML::Copy - copy a HTML file without breaking links.

=head1 SYMPOSIS

 use HTML::Copy;

 $p = HTML::Copy->new();
 $p->htmlcopy($source_path, $target_path);

=head1 DESCRIPTION

This module is to copy a HTML file without beaking links in the file. This module is a sub class of HTML::Parser.

=head1 METHODS

=over 2

=item new

Make an instance of this module.

	$p = HTML::Copy->new;

=cut

sub new {
	my $class = shift @_;
	my $parent = $class->SUPER::new();
	my $newObj = bless $parent,$class;
    $newObj->{'io_layer'} = '';
	return $newObj;
}
    
=item parse_file

Parse contents of $source_path and change links to copy into $target_path. But don't make $target_path. Just return modified HTML. The encoding of strings is converted into utf8.

	$html_text = $p->parse_file($source_path,$target_path);

=cut

sub parse_file($$$) {
	my ($self, $source_path, $target_path) = @_;
	my $io_layer = $self->setup_files($source_path, $target_path);
	
	my $outHandle = dummyIO->new();
	$self->{'outputHTML'} = $outHandle;
	
	open(my $src_fh, "<$io_layer", $source_path) or die "Can't open file $source_path : $!";
	$self->SUPER::parse_file($src_fh);
	close $src_fh;
	
	return join('',@{$outHandle->{'output'}});
}

=item htmlcopy

Parse contents of $source_path, change links and write into $target_path.

	$p->htmlcopy($source_path,$target_path);

=cut

sub htmlcopy($$$) {
	my ($self, $source_path, $target_path) = @_;
	my $io_layer = $self->setup_files($source_path, $target_path);

	my $fh = IO::File->new($target_path, ">$io_layer");
	
	if (defined $fh) {
		$self->{'outputHTML'} = $fh;
		open my $src_fh, "<$io_layer",$source_path or die "Can't open file $source_path : $!";
		$self->SUPER::parse_file($src_fh);
		$fh->close;
		close $src_fh;
	}
	else {
		die "can't open $target_path.";
	}
	return $self->{'targetFile'};
}

=back

=head1 AUTHOR

Tetsuro KURITA <tkurita@mac.com>

=cut

##== overriding methods of HTML::Parser

sub declaration { $_[0]->output("<!$_[1]>")     }
sub process     { $_[0]->output($_[2])          }
sub comment     { $_[0]->output("<!--$_[1]-->") }
sub end         { $_[0]->output($_[2])          }
sub text        { $_[0]->output($_[1])          }

sub start {
	my ($self, $tag, $attr_dict, $attr_names, $tag_text) = @_; 
	my @link_attrs = ();
	
	if (grep {/^$tag/} ('img','frame','script')){
		@link_attrs = ('src','livesrc'); #livesrc is for GoLive
	}
	elsif (grep {/^$tag/} ('link','a')){
		@link_attrs = ('href');
	}
	elsif ($tag eq 'csobj'){ #GoLive
		@link_attrs = ('csref');
	}

	my $is_changed = 0;
	foreach my $an_attr (@link_attrs) {
		if (exists($attr_dict->{$an_attr})){
			my $link_path = $attr_dict->{$an_attr};
			unless ($link_path =~ /^\$/) {
				if (is_rel_link($link_path)){
					$is_changed = 1;
					$attr_dict->{$an_attr} = $self->change_link($link_path);
				}
			}
		}
	}

	if ($is_changed) {
		my $attrs_text = $self->build_attributes($attr_dict, $attr_names);
		$tag_text = "<$tag $attrs_text>";
	}

	$self->output($tag_text);
}

##== private functions

sub setup_files {
	my ($self, $source_path, $target_path) = @_;
	$self->{'sourceFile'}=$source_path;
	$target_path = Cwd::realpath($target_path);
	if (-d $target_path) {
		my $file_name = basename($source_path);
		$target_path = File::Spec->catfile($target_path, $file_name);
	}
	$self->{'targetFile'} = $target_path;
	
	return $self->get_io_layer();
}

sub check_encoding($$) {
	my ($self, $html_file) = @_;
	my $p = HTML::HeadParser->new;
	$p->parse_file($html_file);
	my $content_type = $p->header('content-type');
	my $encoding = '';
	if ($content_type) {
	    if ($content_type =~ /charset\s*=(.+)/) {
	        $encoding = $1;
	    }
	}
	return $encoding;
}

sub check_io_layer($$) {
    my ($self, $html_file) = @_;
	my $encoding = $self->check_encoding($html_file);
	return '' unless ($encoding);
	
	my $io_layer = '';
	if (grep {/$encoding/} ('utf-8', 'UTF-8') ) {
		$io_layer = ":utf8";
	}
	else {
		$io_layer = ":encoding($encoding)";
	}
	return $io_layer;
}

sub get_io_layer($) {
	my ($self) = @_;
	unless ($self->{'io_layer'}) {
		my $io_layer = $self->check_io_layer($self->{'sourceFile'});
		$self->{'io_layer'} = $io_layer;
	}
	
	return $self->{'io_layer'};
}

sub is_rel_link($) {
	my $an_url = shift @_;
	return ($an_url =~ /^(?!http:|mailto:|ftp:|#)(.+)/);
}

sub build_attributes {
  my ($self, $attr_dict, $attr_names) = @_;
  my @attrs = ();
  foreach my $attr_name (@{$attr_names}) {
	my $attr_value = $attr_dict->{$attr_name};
	push @attrs, "$attr_name=\"$attr_value\"";
  }
  return join(' ', @attrs);
}

sub change_link{
	my ($self, $a_path) = @_;
	my $abs_source_path = File::Spec->rel2abs($a_path, dirname($self->{'sourceFile'}));
	$abs_source_path = Cwd::realpath($abs_source_path);
	my $rel_path;
	if (-e $abs_source_path) {
		$rel_path = File::Spec->abs2rel($abs_source_path, dirname($self->{'targetFile'}));
	}
	else {
		warn("$abs_source_path is not found.\nThe link to this path is not changed.\n");
		$rel_path = $a_path;
	}
	return $rel_path;
}

sub output{
	my ($self,$out_text) = @_;
	$self->{'outputHTML'}->print($out_text);
	#push(@{$self -> {outputHTML}}, shift @_);
}

package dummyIO;

use strict;
use warnings;

sub new {
  my $class = shift @_;
  my $self = bless {'output'=>[]}, $class;
  return $self;
}

sub print {
  my ($self,$outText) = @_;
  push(@{$self -> {'output'}}, $outText);
}

1;
