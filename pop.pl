#! /usr/bin/perl -w

# pop.pl - scan proftpd logs to rank etree download popularity
# Copyright (C) 2000  Jason Lunz <j@falooley.org>
$version = "0.4";
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307,
# USA.

use File::Basename;
use Date::Calc (Delta_Days);

my %pop;
my $first;
my %last;
my %rate;

#################
# Configuration #
#################

# the $html_header is printed at the top of the page if html output is
# produced

$html_header = <<HEADER;
<HTML>
<HEAD>
<TITLE>download popularity index for deeznutz.etree.org</TITLE>
</HEAD>

<BODY BGCOLOR="#FFFFFF">
<!--#include virtual="/header.shtml" -->
<BR>
<TABLE>
<TR><TH ALIGN="right">Downloads</TH>
<TH>Rate</TH>
<TH>First</TH>
<TH>Last</TH>
<TH ALIGN="left">Show</TH></TR>
HEADER

# the $html_footer is printed at the end of html output
$html_footer = "</TABLE>\n</BODY>\n</HTML>\n";

# $archive_root is a regular expression that matches the part of show
# pathnames you don't want to see. I use it to make matches like
# "/home/ftp/vol1/dead/gd78-08-07.shnf" look like "dead/gd78-08-07.shnf".

$archive_root = '/home/ftp';

#####################
# end configuration #
#####################

use Getopt::Std;
getopts( 'aAhvwfrpFRPz', \%opt );

if($opt{v})
{
    print "pop.pl version $version\n";
    exit 0;
}

if( $opt{h} or scalar(@ARGV) == 0 )
{
    print <<HERE;

pop.pl version $version
usage: pop.pl [options] <xferlog> [xferlog...]

    Where xferlog is a wu-ftpd style transfer log. proftpd writes a
    compatible log in /var/log/xferlog by default. This can be changed
    with proftpd's TransferLog directive.

    options are:
    -h	this Help message
    -v  print Version number
    -w  output Web page
    -f  sort by First download
    -p  sort by Popularity
    -a  sort by download rate
    -r  sort by most Recent download
    -F  reverse sort by First download
    -P  reverse sort by Popularity (default)
    -R  reverse sort by most Recent download
    -A  reverse sort by download rate
    -z  Include shows with no downloads

    The xferlogs can be gzip compressed, so a command like
    "pop.pl /var/log/xferlog*" will do what you expect.

HERE
    exit 0;
}

my $c = grep { /^[fpra]$/i } keys %opt;
if( $c > 1 )
{
    print "Only one of -afprAFPR may be specified.\n";
    exit 1;
}
$opt{A} = 1 unless $c;

my %MONTHS = ( "Jan" => 1, "Feb" => 2, "Mar" => 3, "Apr" => 4,
	       "May" => 5, "Jun" => 6, "Jul" => 7, "Aug" => 8,
	       "Sep" => 9, "Oct" => 10, "Nov" => 11, "Dec" => 12);

sub parse_date {
   my $date = shift;
   my $time = 0;

   # Fri Jan 26 15:10:05 2001
   if ($date =~ /^\S+\s(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+
       (\d+)\s+(\d+):(\d+):(\d+)\s(\d+)/xo) {
     $time = sprintf ("%4d%02d%02d.%02d%02d%02d",
		      $6, $MONTHS{$1}, $2, $3, $4, $5);
   } elsif ($date =~ /^(\d+)(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)
       (\d+):(\d+):(\d+):(\d+)$/x) {
      $time = sprintf ("%4d%02d%02d.%02d%02d%02d",
		       $3, $MONTHS{$2}, $1, $4, $5, $6);

      die "Can't handle date format $date\n";
   }

   $time;
}

sub format_date {
  my $date = shift;
  sprintf ("%02d/%02d/%02d", substr ($date, 4, 2),
	   substr ($date, 6, 2), substr ($date, 2, 2));
}

# accept gzipped files
@ARGV = map { /\.(gz|Z)$/ ? "gzip -dc < $_ |" : $_ } @ARGV;

$archive_root = '' unless defined($archive_root);

# first we fill the %dl hash with a count of shns downloaded from each show
while(<>)
{
    if( m{
	    (^(?:\S+\s+){5})	# the timestamp
	    (?:\S+\s+){3}	# skip three fields
	    (\S+?) 		# capture the folder name
	    /[^/]+\.shn		# only count download of .shn files
	    \s.\s.\so		# only count outgoing transfers
	}xi )
    {
      my $time = $1;
      my $parent = basename (dirname ($2));
      my $dir = basename $2;
      $dir = $parent if $parent =~ /\.shnf$/ or $dir =~ /d\d+(\.shn[f]?)?$/;
      $dl{$dir}++;
      $time = parse_date ($time);
      $first{$dir} = 99991231.235959 unless exists($first{$dir});
      $first{$dir} = $time if $time < $first{$dir};
      $last{$dir} = 0 unless exists($last{$dir});
      $last{$dir} = $time if $time > $last{$dir};
    }
}

# then we count the number of shns in each show
use File::Find;
find( \&wanted, $archive_root);
sub wanted
{
  return unless $File::Find::name =~ /\.shn$/i;
  my $dir = basename ($File::Find::dir);
  my $parent = basename (dirname ($File::Find::dir));
  $dir = $parent if $parent =~ /\.shnf$/ or $dir =~ /d\d+(\.shn[f]?)?$/;
  $count{$dir}++;
}

# now we calculate the number of show downloads for each show
# (number of shn downloads from show) / (number of shns in that show)
foreach my $show (keys %count)
{
    $dl{$show} = 0 unless exists $dl{$show};
    $first{$show} = 0 unless exists $first{$show};
    $last{$show} = 0 unless exists $last{$show};
    $pop{$show} = $dl{$show} / $count{$show} if exists($count{$show});
    $rate{$show} = ($first{$show} and $last{$show} ? 
		    $pop{$show} / (1+Delta_Days (substr ($first{$show}, 0, 4),
						 substr ($first{$show}, 4, 2),
						 substr ($first{$show}, 6, 2),
						 substr ($last{$show}, 0, 4),
						 substr ($last{$show}, 4, 2),
						 substr ($last{$show}, 6, 2)))
		    : 0);

}

# finally, print output
print $html_header if $opt{w};
printf "%5s %5s %10s %10s  Show\n", 'Count', 'Rate', 'First', 'Last'
  unless $opt{w};
for( sort {
	$opt{P} && return $pop{$b} <=> $pop{$a};
	$opt{p} && return $pop{$a} <=> $pop{$b};
	$opt{F} && return $first{$b} <=> $first{$a};
	$opt{f} && return $first{$a} <=> $first{$b};
	$opt{R} && return $last{$b} <=> $last{$a};
	$opt{r} && return $last{$a} <=> $last{$b};
	$opt{a} && return $rate{$a} <=> $rate{$b};
	$opt{A} && return $rate{$b} <=> $rate{$a};
    } keys %pop )
{
  next if not $opt{z} and not $pop{$_};
  my $show = $_;

    my $f = $first{$show} ? format_date ($first{$show}) : "";
    my $l = $last{$show} ? format_date ($last{$show}) : "";
    if($opt{w}) {
	printf "<TR><TD ALIGN=\"right\">%.2f</TD>", $pop{$show};
	printf "<td align=\"right\">%.2f</td>", $rate{$show};
	print "<TD>$f</TD><TD>$l</TD><TD>$show</TD></TR>\n";
    } else {
	printf "%5.2f %5.2f %10s %10s  $show\n",
	  $pop{$show}, $rate{$show}, $f, $l;
    }
}
print $html_footer if $opt{w};

