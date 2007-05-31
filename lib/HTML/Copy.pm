package HTML::Copy;

use 5.008;
use strict;
use warnings;
use File::Spec;
use File::Basename;
use Cwd;
use IO::File;
use utf8;
use Encode;
use Encode::Guess;
use Carp;
#use Data::Dumper;

use HTML::Parser 3.40;
use HTML::HeadParser;
use URI::file;

use base qw(HTML::Parser Class::Accessor);

__PACKAGE__->mk_accessors(qw(source_path
                            destination_path
                            link_attributes
                            has_base
                            source_uri
                            destination_uri));

#use Data::Dumper;

=head1 NAME

HTML::Copy - copy a HTML file without breaking links.

=head1 VERSION

Version 1.2

=cut

our $VERSION = '1.2';

=head1 SYMPOSIS

  use HTML::Copy;
  
  HTML::Copy->htmlcopy($source_path, $destination_path);
  
  # or
  
  $p = HTML::Copy->new($source_path);
  $p->copy_to($destination_path);

=head1 DESCRIPTION

This module is to copy a HTML file without beaking links in the file. This module is a sub class of HTML::Parser.

=head1 REQUIRED MODULES

=over 2

=item L<HTML::Parser>

=back

=head1 CLASS METHODS

=head2 htmlcopy

    HTML::Copy->htmlcopy($source_path, $destination_path);

Parse contents of $source_path, change links and write into $destination_path.

=cut

sub htmlcopy($$$) {
    my ($class, $source_path, $destination_path) = @_;
    my $p = $class->new($source_path);
    return $p->copy_to($destination_path);
}

=head2 parse_file

    $html_text = HTML::Copy->parse_file($source_path, $destination_path);

Parse contents of $source_path and change links to copy into $destination_path. But don't make $destination_path. Just return modified HTML. The encoding of strings is converted into utf8.

=cut

sub parse_file($$$) {
    my ($class, $source_path, $destination_path) = @_;
    my $p = $class->new($source_path);
    return $p->parse_to($destination_path);
}


=head1 CONSTRUCTOR METHODS

=head2 new

    $p = HTML::Copy->new($source_path);

Make an instance of this module.

=cut

sub new {
    my $class = shift @_;
    my $self = $class->SUPER::new();
    if (@_ > 1) {
        my %args = @_;
        my @keys = keys %args;
        @$self{@keys} = @args{@keys};
    } else {
        $self->source_path(shift @_);
    }
    
    if ($self->source_path) {
        (-e $self->source_path) or croak $self->source_path." is not found.\n";
        $self->source_path($self->source_path);
    }
    
    $self->link_attributes(['src', 'href', 'background', 'csref', 'livesrc']);
    # 'livesrc' and 'csref' are uesed in Adobe GoLive
    $self->has_base(0);
    
    return $self;
}


=head1 INSTANCE METHODS

=head2 copy_to

    $p->copy_to($destination_path)

Parse contents of $source_path given in new method, change links and write into $destination_path.

=cut

sub copy_to {
    my ($self, $destination_path) = @_;
    $self->set_destination($destination_path);
    my $io_layer = $self->io_layer();
    
    my $fh = IO::File->new($destination_path, ">$io_layer");
    
    if (defined $fh) {
        $self->{'outputHTML'} = $fh;
        $self->SUPER::parse($self->{'source_html'});
        $self->eof;
        $fh->close;
    } else {
        die "can't open $destination_path.";
    }
    
    return $self->destination_path;
}

=head2 parse_to

    $p->parse_to($destination_path)

Parse contents of $source_path given in new method, change links and return HTML contents to wirte $destination_path. Unlike copy_to, $destination_path will not created.

=cut

sub parse_to {
    my ($self, $destination_path) = @_;
    $self->set_destination($destination_path);
    $self->io_layer;
    
    my $output = '';
    my $fh = IO::File->new(\$output, ">:utf8");
    $self->{'outputHTML'} = $fh;
    $self->SUPER::parse($self->{'source_html'});
    $self->eof;
    $fh->close;
    return decode_utf8($output);
}

=head1 ACCESSOR METHODS

=head2 io_layer

    $p->io_layer;
    $p->io_layer(':utf8');

Get and set PerlIO layer to read $source_path and to write $destination_path. Usualy it was automatically determined by $source_path's charset tag. If charset is not specified, Encode::Guess module will be used.

=cut
sub io_layer {
    my $self = shift @_;
    if (@_) {
        $self->{'io_layer'} = shift @_;
    }
    else {
        unless ($self->{'io_layer'}) {
            $self->{'io_layer'} = $self->check_io_layer();
        }
    }
    
    return $self->{'io_layer'};
}

=head2 encode_suspects

    @suspects = $p->encode_sustects;
    $p->encode_suspects(qw/shiftjis euc-jp/);

Add suspects of text encoding to guess the text encoding of the source HTML. If the source HTML have charset tag, it is not requred to add suspects.

=cut

sub encode_suspects {
    my $self = shift @_;
    
    if (@_) {
        my @suspects = @_;
        $self->{'EncodeSuspects'} = \@suspects;
    }
    
    if (my $suspects_ref = $self->{'EncodeSuspects'}) {
        return @$suspects_ref;
    }
    else {
        return ();
    }
}

=head2 source_html

    $p->source_html;

Obtain source HTML's contents

=cut

sub source_html {
    my ($self) = @_;
    $self->io_layer;
    return $self->{'source_html'};
}

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
    
    unless ($self->has_base) {
        if ($tag eq 'base') {
            $self->has_base(1);
        }
        
        my $is_changed = 0;
        foreach my $an_attr (@{$self->link_attributes}) {
            if (exists($attr_dict->{$an_attr})){
                my $link_path = $attr_dict->{$an_attr};
                next if ($link_path =~ /^\$/);
                my $uri = URI->new($link_path);
                next if ($uri->scheme);
                $is_changed = 1;
                $attr_dict->{$an_attr} = $self->change_link($uri);
            }
        }
    
        if ($is_changed) {
            my $attrs_text = $self->build_attributes($attr_dict, $attr_names);
            $tag_text = "<$tag $attrs_text>";
        }
    }
    
    $self->output($tag_text);
}

##== private functions

sub set_destination {
    my ($self, $destination_path) = @_;

    if (-d $destination_path) {
        my $file_name = basename($self->source_path);
        $destination_path = File::Spec->catfile($destination_path, $file_name);
    }

    return $self->destination_path($destination_path);
}

sub check_encoding {
    my ($self) = @_;
    my $data;
    open my $in, "<", $self->source_path;
    {local $/; $data = <$in>;}
    close $in;
    
    my $p = HTML::HeadParser->new;
    $p->utf8_mode(1);
    $p->parse($data);
    my $content_type = $p->header('content-type');
    my $encoding = '';
    if ($content_type) {
        if ($content_type =~ /charset\s*=(.+)/) {
            $encoding = $1;
        }
    }
    
    unless ($encoding) {
        my $decoder;
        if (my @suspects = $self->encode_suspects) {
            $decoder = Encode::Guess->guess($data, @suspects);
        }
        else {
            $decoder = Encode::Guess->guess($data);
        }
        
        ref($decoder) or 
                    die("Can't guess encoding of ".$self->source_path);
                    
        $encoding = $decoder->name;
    }
    
    $self->{'source_html'} = Encode::decode($encoding, $data);
    
    return $encoding;
}

sub check_io_layer {
    my ($self) = @_;
    my $encoding = $self->check_encoding;
    return '' unless ($encoding);
    
    my $io_layer = '';
    if (grep {/$encoding/} ('utf8', 'utf-8', 'UTF-8') ) {
        $io_layer = ":utf8";
    }
    else {
        $io_layer = ":encoding($encoding)";
    }
    return $io_layer;
}

sub build_attributes {
    my ($self, $attr_dict, $attr_names) = @_;
    my @attrs = ();
    foreach my $attr_name (@{$attr_names}) {
        if ($attr_name eq '/') {
            push @attrs, '/';
        } else {
            my $attr_value = $attr_dict->{$attr_name};
            push @attrs, "$attr_name=\"$attr_value\"";
        }
    }
    return join(' ', @attrs);
}

sub change_link {
    my ($self, $uri) = @_;
    my $result_uri;
    my $abs_uri = $uri->abs( $self->source_uri );
    my $abs_path = $abs_uri->file;
    if (-e $abs_path) {
        $result_uri = $abs_uri->rel($self->destination_uri);
    } else {
        warn("$abs_path is not found.\nThe link to this path is not changed.\n");
        $result_uri = $uri;
    }
    
    return $result_uri->as_string;
}

sub output {
    my ($self, $out_text) = @_;
    $self->{'outputHTML'}->print($out_text);
}

sub source_path {
    my $self = shift @_;
    
    if (@_) {
        my $path = Cwd::abs_path(shift @_);
        $self->{'source_path'} = $path;
        $self->source_uri(URI::file->new($path));
    }
    return $self->{'source_path'};
}

sub destination_path {
    my $self = shift @_;
    
    if (@_) {
        my $path = Cwd::abs_path(shift @_);
        $self->{'destination_path'} = $path;
        $self->destination_uri(URI::file->new($path));
    }
    return $self->{'destination_path'};
}

1;
