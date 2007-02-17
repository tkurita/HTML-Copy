#escapeChars {return}
#use lib '../lib';
use strict;
use warnings;
use HTML::Copy;
use utf8;
use File::Spec;
#use Data::Dumper;

use Test::More tests => 10;

my $linked_html = <<EOT;
<!DOCTYPE html>
<html>
</html>
EOT

my $linked_file_name = "linked$$.html";
open(my $linked_fh, ">", $linked_file_name);
print $linked_fh $linked_html;
close $linked_fh;

##== HTML data without charsets
my $source_html_nocharset = <<EOT;
<!DOCTYPE html>
<html>
ああ
<a href="$linked_file_name"></a>
<frame src="$linked_file_name">
<img src="$linked_file_name">
<script src="$linked_file_name"></script>
<link href="$linked_file_name">
</html>
EOT

my $result_html_nocharset = <<EOT;
<!DOCTYPE html>
<html>
ああ
<a href="../$linked_file_name"></a>
<frame src="../$linked_file_name">
<img src="../$linked_file_name">
<script src="../$linked_file_name"></script>
<link href="../$linked_file_name">
</html>
EOT

##== write test data
my $sub_dir_name = "sub$$";
mkdir($sub_dir_name);
my $src_file_name = "file$$.html";
my $destination = File::Spec->catfile($sub_dir_name, $src_file_name);

##== Test code with no charsets HTML
open(my $src_fh, ">:utf8", $src_file_name);
print $src_fh $source_html_nocharset;
close $src_fh;

##=== parse_to UTF-8
my $p = HTML::Copy->new($src_file_name);
my $copy_html = $p->parse_to($destination);

ok($copy_html eq $result_html_nocharset, "parse_to no charset UTF-8");

##=== copty_to UTF8
$p->copy_to($destination);
open(my $in, "<".$p->io_layer(), $destination);
{local $/; $copy_html = <$in>};
close $in;
unlink($destination);

ok($copy_html eq $result_html_nocharset, "copy_to no charset UTF-8");

##=== write data with shift_jis
open($src_fh, ">:encoding(shiftjis)", $src_file_name);
print $src_fh $source_html_nocharset;
close $src_fh;

##=== parse_to shift_jis
$p = HTML::Copy->new($src_file_name);
$p->encode_suspects("shiftjis");
$copy_html = $p->parse_to("$sub_dir_name/$src_file_name");

ok($copy_html eq $result_html_nocharset, "parse_to no charset shift_jis");

##=== copy_to shift_jis
$p->copy_to($destination);
open($in, "<".$p->io_layer, $destination);
{local $/; $copy_html = <$in>};
close $in;
unlink($destination);

ok($copy_html eq $result_html_nocharset, "copy_to no charset shift_jis");

##== HTML with charset uft-8
my $src_html_utf8 = <<EOT;
<!DOCTYPE html>
<html>
<head>
<meta http-equiv="content-type" content="text/html;charset=utf-8">
</head>
ああ
<a href="$linked_file_name"></a>
<frame src="$linked_file_name">
<img src="$linked_file_name">
<script src="$linked_file_name"></script>
<link href="$linked_file_name">
</html>
EOT

my $result_html_utf8 = <<EOT;
<!DOCTYPE html>
<html>
<head>
<meta http-equiv="content-type" content="text/html;charset=utf-8">
</head>
ああ
<a href="../$linked_file_name"></a>
<frame src="../$linked_file_name">
<img src="../$linked_file_name">
<script src="../$linked_file_name"></script>
<link href="../$linked_file_name">
</html>
EOT

##== Test code with charset utf-8
open($src_fh, ">:utf8", $src_file_name);
print $src_fh $src_html_utf8;
close $src_fh;

##=== parse_to
$p = HTML::Copy->new($src_file_name);
$copy_html = $p->parse_to($destination);

ok($copy_html eq $result_html_utf8, "parse_to charset UTF-8");

##=== copy_to
$p->copy_to($destination);
open($in, "<".$p->io_layer(), $destination);
{local $/; $copy_html = <$in>};
close $in;
unlink($destination);

ok($copy_html eq $result_html_utf8, "copy_to charset UTF-8");

##== HTML with charset shift_jis
my $src_html_shiftjis = <<EOT;
<!DOCTYPE html>
<html>
<head>
<meta http-equiv="content-type" content="text/html;charset=shift_jis">
</head>
ああ
<a href="$linked_file_name"></a>
<frame src="$linked_file_name">
<img src="$linked_file_name">
<script src="$linked_file_name"></script>
<link href="$linked_file_name">
</html>
EOT

my $result_html_shiftjis = <<EOT;
<!DOCTYPE html>
<html>
<head>
<meta http-equiv="content-type" content="text/html;charset=shift_jis">
</head>
ああ
<a href="../$linked_file_name"></a>
<frame src="../$linked_file_name">
<img src="../$linked_file_name">
<script src="../$linked_file_name"></script>
<link href="../$linked_file_name">
</html>
EOT

##== Test code with charset shift_jis
open($src_fh, ">:encoding(shiftjis)", $src_file_name);
print $src_fh $src_html_shiftjis;
close $src_fh;

##=== parse_to
$p = HTML::Copy->new($src_file_name);
$p->encode_suspects("shiftjis");
$copy_html = $p->parse_to($destination);

ok($copy_html eq $result_html_shiftjis, "parse_to no charset shift_jis");

##=== copy_to
$p->copy_to($destination);
open($in, "<".$p->io_layer, $destination);
{local $/; $copy_html = <$in>};
close $in;

ok($copy_html eq $result_html_shiftjis, "copy_to no charset shift_jis");
unlink($destination);

##== class_methods
$copy_html = HTML::Copy->parse_file($src_file_name, $destination);

ok($copy_html eq $result_html_shiftjis, "parse_file");

HTML::Copy->htmlcopy($src_file_name, $destination);

open($in, "<".$p->io_layer, $destination);
{local $/; $copy_html = <$in>};
close $in;

ok($copy_html eq $result_html_shiftjis, "htmlcopy");

unlink($linked_file_name, $src_file_name, $destination);
rmdir($sub_dir_name);
