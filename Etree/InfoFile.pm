#!/usr/bin/perl -w
#
# Live concert recording info file parsing module
#
# $Id$


=head1 NAME

  Etree::InfoFile - Parse live concert recording "info" files and
  possibly associate the information with lossless audio files.

=head1 SYNOPSIS

    my $dir = "/shn/ph2003-01-01.flac16";

    my $info = new Etree::InfoFile (Directory => $dir)
        or die "Unable to create Etree::InfoFile object";

    $info->parse or warn "Unable to handle $dir";

    print "Artist: " . $info->artist . "\n" .
  	  "  Date: " . $info->date . "\n" .
          " Venue: " . $info->venue . "\n" .
          "Source: " . $info->source . "\n";

=cut

package Etree::InfoFile;

use strict;
use File::Basename;
use File::Find;
use POSIX qw(strftime);
eval "use Locale::Country";
my $have_locale = not $@;

eval "use Date::Parse";
my $have_date_parse = not $@;

my
  $VERSION = sprintf "%d.%03d", q$Revision$ =~ /(\d+)/g;
my $debug = 0;
my $test = 0;

my %WORD2NUM = ("one" => 1, "two" => 2, "three" => 3, "four" => 4, "five" => 5,
		"six" => 6, "seven" => 7, "eight" => 8, "nine" => 9,
		"ten" => 10,
		# Roman numerals
		"i" => 1, "ii" => 2, "iii" => 3, "iv" => 4, "v" => 5,
		"vi" => 6, "vii" => 7, "viii" => 8, "ix" => 9, "x" => 10 );

my $numberwords = join ("|", keys %WORD2NUM);

# Some regexps we use to recognize certain parts of the text file,
# mostly taping related
my $spots = qr/fob|dfc|btp|d?aud|d?sbd|soundboard|on(\s*|-)stage|matrix|
  mix|balcony|rail|stand/ix;
my $mics = qr/caps|omni|cardioid|sc?ho?ep[sz]|neumann|mbho|akg|b&k|dpa|
  audio.technica/ix;
my $configs = qr/\b(?:ortf|x[-\/]?y|degrees|blumlein|binaural|nos|din)\b/ix;
my $cables = qr/kc5|actives?|patch(?:ed)?|coax|optical/ix;
my $pres = qr/lunatec|apogee|ad1000|ad2k\+?|oade|sonosax|sbm-?1|
  usb-pre|mini[\s-]?me/ix;
my $dats = qr/dat|pcm|d[378]|da20|d10|m1|sv-25[05]|da-?p1|tascam|sony|
  teac|aiwa|panasonic|hhb|portadat|44\.1(?:k(?:hz))|mini-?disc|fostex/ix;
my $laptops = qr/laptop|dell|ibm|apple|toshiba|(power|i)-?book/ix;
my $digicards = qr/ieee1394|s.?pdif|zefiro|za-?2|rme|digiface|sb-?live|fiji|
  turtle\sbeach|delta\sdio|event\sgina|montego|zoltrix|prodif/ix;
my $software = qr/cd-?wave?|mkwact|shn(?:v3)?|shorten|samplitude|
  cool[-\s]?edit|sound.?forge|wavelab/ix;
my $venues = qr/(?:arts cent|theat)(?:er|re)|playhouse|arena|club|university|
  festival|lounge|room|cafe|field|house|airport|ballroom|college|hall|
  auditorium/ix;
my $states = qr/A[BLKZR]|BC|CA|CO|CT|DE|FL|GA|HI|I[DLNA]|KS|KY|LA|M[ABEDINSOT]|
  N[BCDEFVHJMSY]|O[HKNR]|P[AQ]|PEI|QC|RI|S[CDK]|TN|TX|UT|VT|VA|W[AVIY]|DC/x;
my $countries;
if ($have_locale) {
   # Large list of all countries Perl knows about
   $countries = join ("|", map { qr/$_/ } all_country_names ());
} else {
   # Small list of countries we might see
   $countries = 'Japan|England|Ireland|Brazil|Jamaica|United\s+Kingdom|Italy|'.
     'South\s+Africa|Sweden|Portugal|Israel|Egypt|Norway|France|India|' .
       'Finland|United\s+States|China|Mexico|Costa\s+Rica|Ecuador|' .
	 'New\s+Zealand|Puerto\s+Rico|Djibouti'; # shake it!
}

$countries = qr($countries);
my $trackre = qr/^\s*(?:d\d+)?t?(\d+) 	# sometimes you see d<n>t<m>
  \s* (?:[[:punct:]]+)? 		# whitespace, some punctuation
  \s* (.*)/ix;				# whitespace, the track title

# A regex that matches most dates
my $datefmt = qr/\d{4}[-\.\/]\d{1,2}[-\.\/]\d{1,2}|
		 \d{1,2}[-\.\/]\d{1,2}[-\.\/]\d{2,4}|
		 (?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\w*
		 \s+\d{1,2}(?:st|nd|rd|th)?,?\s+\d{2,4}/ix;

=head1 METHODS

These methods may be invoked on an instance of the class:

=over

=item new

Constructor.  Takes a parameter hash.  Should be called with
"Directory" => C<somedir> where C<somedir> is the directory you wish
to process.

=cut

sub new {
   my $type = shift;
   my %param = @_;
   my $self = bless { %param }, $type;

   $self;
}

# extension - get the extension part of a filename
sub extension {
   my $filename = shift;
   my $ext = $filename;
   return if $ext =~ /(^(bak|orig)$|~$)/;
   $ext =~ s/^.+\.([^\.]+)$/$1/;
   $ext;
}

# findfiles - find all of the files in a directory
sub findfiles {
   my $self = shift;
   my $dir = $self->{"Directory"};

   return unless defined $dir;

   # Incase this is smbfs or whatever
   local $File::Find::dont_use_nlink = 1;

   # Find all of the files in this directory and group them by their
   # filename extension as well as their full path
   find (sub { return unless -f;
	       my $ext = extension ($_);
	       return unless defined $ext;
	       my $file = File::Spec->abs2rel ($File::Find::name,
					       $dir);
	       $self->{"Files"}{$file} = { "ext" => lc $ext, "size" => -s $_ };
	       $self->{"ByExt"}{lc $ext}{$file} = 1;
	    }, $dir);
}

# matchchars - count the number of matching characters between two strings
sub matchchars {
   my $tomatch = shift;
   my $string = shift;
   my $numcheck = length $tomatch;
   $numcheck = length $string if length $string < $numcheck;
   my $hits = 0;

   foreach my $i (0 .. $numcheck - 1) {
      if (lc (substr ($tomatch, $i, 1)) eq lc (substr ($string, $i, 1))) {
	 ++$hits;
      } else {
	 last;
      }
   }

   $hits;
}

# readtext - choose the text file which describes the SHNs and read it
sub readtext {
   my $self = shift;
   my $dir = $self->{"Directory"};
   my $infofile = $self->{"InfoFile"};

   if (not defined $dir and defined $infofile) {
      $self->{Directory} = $dir = dirname $infofile;
   }

   if (not defined $infofile and defined $dir) {
      $self->findfiles;

      # Try and find any .txt or .nfo file in the current directory.
      my (@TXT, @NFO, @ALL);
      if (exists $self->{"ByExt"}{"txt"}) {
	 push (@TXT, grep { not m/ffp/i } keys %{ $self->{"ByExt"}{"txt"}});
	 push (@ALL, @TXT);
      }

      if (exists $self->{"ByExt"}{"nfo"}) {
	 push (@NFO, keys %{ $self->{"ByExt"}{"nfo"}});
	 push (@ALL, @NFO);
      }

      if (not scalar @ALL) {
	 warn ref ($self) . "::readtext: No txt or nfo files found\n";
	 return;
      }

      $infofile = $ALL[0];

      if (scalar @ALL > 1) {
	 # See if we can determine which is the "real" info file; prefer
	 # the .txt extension.
	 if (scalar @TXT == 1) {
	    $infofile = $TXT[0];
	 } elsif (scalar @NFO == 1) {
	    $infofile = $NFO[0];
	 } else {
	    # Try and find best matching filename
	    (my $base = basename ($dir)) =~ s/(shn|ogg|flac\d*)f?$//;
	    my @BEST;
	    my $score = 0;

	    foreach my $txtfile (@ALL) {
	       my $s = matchchars ($base, basename $txtfile);
	       if ($s > $score) {
		  $score = $s;
		  @BEST = ( $txtfile );
	       } elsif ($s == $score) {
		  push (@BEST, $txtfile);
	       }
	    }
	    $infofile = $BEST[0];
	    if (scalar @BEST > 1) {
	       warn ref ($self) . "::readtext: Too many candiates for the " .
		 "info file (@BEST); using $infofile\n";
	    }
	 }
      }

      $self->{"InfoFile"} = $infofile;
   }

   if (not defined $infofile) {
      warn ref ($self) . "::readtext: No info file defined\n";
      return;
   }

   if (not open (INFOFILE, $self->{"Directory"} . "/$infofile")) {
      warn ref ($self) . "::readtext: Unable to open $infofile: $!\n";
      return;
   }

   while (<INFOFILE>) {
      chomp;
      s/\r//g;
      my $line = $_;

      # add it to the array
      push (@{$self->{"InfoFileLines"}}, $line);
   }

   close (INFOFILE);
}

# fmttime - convert seconds into m:ss.ff
sub fmttime {
   my $seconds = shift;
   my $time;

   if (defined $seconds) {
      my $min = int ($seconds / 60);
      my $sec = int ($seconds - 60 * $min);
      my $frames = 75 * ($seconds - $sec - 60 * $min);
      if ($frames) {
	 $time = sprintf ("%d:%02d.%02d", $min, $sec, $frames);
      } else {
	 $time = sprintf ("%d:%02d", $min, $sec);
      }
   }

   $time;
}

# parsetitle - take the song title from a text file and strip off any
# segue indicator, notation characters (like @#$%^*) and running time
sub parsetitle {
   my $title = shift;

   my ($segue, $notes, $running_time, $set);

   # Strip off any running time from the end of the title
   $title =~ s/\W?(\d+[:\.\']\d{2}([\":\.]\d+)?)\W?/
     $running_time = $1; ""; /eg;

   # I've been seeing this a lot in some info files: whitespace,
   # dash, whitespace then the track timing.
   $title =~ s/\s+-\s*$//;

   # Strip off any trailing segue marker
   $title =~ s/\s*(-*\>)\s*$/ $segue = $1; "" /e;

   # Strip off any "notes" indicators like @, #, $, %, ^, and *
   $title =~ s/\s*([\*\@\#\$\%\^]+)\s*$/ $notes = $1; "" /e;

   # remove leading and trailing whitespace
   $title =~ s/^\s+//; $title =~ s/\s+$//;

   # See if there is a set indicator (e.g. I: Song or E: Song)
   if ($title =~ /^($numberwords):\s*(.+)/i) {
      $set = word2num ($1);
      $title = $2;
   } elsif ($title =~ /^e(?:ncore)?:\s*(.+)/i) {
      $set = "E";
      $title = $1;
   }

   ($title, $segue, $notes, $running_time, $set);
}

# word2num - convert a word into a number
sub word2num {
   my $word = shift;
   return int ($word) if $word =~ /^\d+$/;
   return $WORD2NUM{lc $word};
}

=item parseinfo

Internal method used to parse the info file contents for disc numbers
and track names.  Should not be called directly.

=cut

sub parseinfo {
   my $self = shift;

   my $discnum = 1;		# start with disc 1
   my $index = 0;
   my $numsongs = 0;
   my $lastsong = 0;
   my $lastindex = 0;
   my $lastdisc = 1;
   my $indisc = 0;
   my $haveall = 0;
   my $set;

   $self->{NumSongs} = 0 unless exists $self->{NumSongs};

   foreach my $line (@{$self->{"InfoFileLines"}}) {
      # Strip whitespace
      $line =~ s/^\s+//; $line =~ s/\s+$//;

      next unless length $line;

      # looking for disc delimeters
      if (not $numsongs and not exists $self->{"Band"}
	  and $line !~ /\b($venues|$states|$countries|^(?:$datefmt))\b/ix) {
	 $self->{"Band"} = $line;
      } elsif ($line =~ /^(source|src)\b/i or
	       $line !~ /^((trans|x)fer|conver(ted|sion))\b/i and
	       $line =~ /\b($spots|$mics|$configs|$cables|$pres|$dats)\b/
	       and not $indisc) {
	 $line =~ s/^(source|src)\b:?\s*//i;
	 if (length $line) {
	    $self->{"Source"} .= " " if exists $self->{"Source"};
	    $self->{"Source"} .= $line;
	 }
      } elsif ($line =~ /^((?:trans|x)fer|conver(?:ted|sion))/i or
	       $line =~ /($dats|$laptops|$digicards|$software)/
	       and not $indisc) {
	 $line =~ s/^((trans|x)fer|conver(ted|sion))\b:?\s*//i;
	 if (length $line) {
	    $self->{"Transfer"} .= " " if exists $self->{"Transfer"};
	    $self->{"Transfer"} .= $line;
	 }
      } elsif ($line =~ /^(tape[rd]|recorded)/i) {
	 $line =~ s/^(recorde|tape)(r|d)(\sby)?:?\s*//i;
	 $self->{"Taper"} = $line;
      } elsif ($line =~ /^seede[rd]/i) {
	 $line =~ s/^seede(r|d)( by)?:?\s*//i;
	 $self->{"Seeder"} = $line;
      } elsif (not $numsongs and not exists $self->{"Date"} and
	       $line =~ /($datefmt)/ix) {
	 $self->{"Date"} = $1;
      } elsif (not $numsongs
	       and not exists $self->{Source}
	       and ($line =~ /\b($venues|$states|$countries)/)
	       and not $indisc) {
	 $self->{"Venue"} .= " - " if exists $self->{"Venue"};
	 $self->{"Venue"} .= $line;
      } elsif ($line =~ /^\W*(c?d|dis[kc]|volume)\W*(\d+|$numberwords)\b/ix){
	 $discnum = word2num ($2);
	 $indisc = $discnum;
	 $lastsong = 0;
      } elsif ($line =~ /\bset\s*(\d+|$numberwords)\b/ix) {
	 $set = word2num ($1);
      } elsif ($line =~ /^encore/i) {
	 $set = "E";
      } elsif ($line =~ /^(\d+)\s*(cd|dis[ck])s?/ix) {
	 $self->{"Discs"} = $1;
      } elsif (not $haveall and
	       $line =~ $trackre and int ($1) > 0) {
	 my $songnum = int $1;
	 my ($title, $segue, $notes, $runtime, $maybeset) = parsetitle ($2);
	 $set = $maybeset if defined $maybeset;

	 if ($lastsong and $songnum < $lastsong) {
	    $indisc = ++$discnum;
	 }

	 if ($debug) {
	    local $SIG{__WARN__} = sub {};
	    print "$line\n -> disc=$discnum title=$title " .
	      "segue=$segue notes=$notes " .
		"runtime=$runtime set=$set\n";
	 }

	 $self->{"Discs"} = $discnum
	   if not exists $self->{"Discs"} or
	     $discnum > $self->{"Discs"};
	 $self->{"Disc"}{$discnum}{"Tracks"} = $songnum
	   if not exists $self->{"Disc"}{$discnum}{"Tracks"} or
	     $songnum > $self->{"Disc"}{$discnum}{"Tracks"};
	 $self->{"Songs"}[$index] = { Disc => $discnum,
				      Track => $songnum,
				      Index => $index,
				      Set => $set,
				      Title => $title,
				      Line => $line };
	 $self->{Songs}[$index]{Notes} = $notes if defined $notes;
	 $self->{Songs}[$index]{Segue} = $segue if defined $segue;
	 $self->{Songs}[$index]{Time} = $runtime if defined $runtime;
	 $self->{Notes}{$notes} ||= "" if defined $notes;

	 ++$index;
       	 ++$numsongs;
	 $lastsong = $songnum;
	 $lastdisc = $indisc = $discnum;
	 $lastindex = $index;

	 if ($numsongs == $self->{"NumSongs"}) {
	    print "Disc $discnum Song $songnum: have all needed song names\n"
	      if $debug;
	    $haveall = 1;
	 }
      } elsif ($line =~ /^([\*\@\#\$\%\^]+)\s*[-=:]?\s*(.+)/
	       and exists $self->{"Notes"}{$1}) {
	 $self->{"Notes"}{$1} .= $2;
      } elsif ($line =~ /\w/) {
	 push (@{$self->{"Etc"}}, $line);
      }
   }

   # Sometimes Band and Date get smushed together
   if (not exists $self->{"Date"}
       and exists $self->{"Band"}
       and $self->{"Band"} =~ /^(.+)\s+((?:$datefmt).*)/ix) {
      $self->{"Date"} = $2;
      ($self->{"Band"} = $1) =~ s/\s+\W$//
   }

   # Still no date?  Try and get it from the directory name
   if (not exists $self->{"Date"} and exists $self->{Directory}
       and defined $self->{Directory}) {
      my $base = basename $self->{"Directory"};
      if (defined $base and
	  $base =~ /^.+-?(\d{2,4})-(\d{1,2})-(\d{1,2})(-.+)?\./) {
	 $self->{"Date"} = "$2/$3/$1";
      }
   }

   # Sometimes Date and Venue get smushed together
   if (not exists $self->{"Venue"}
       and exists $self->{"Date"}
       and defined $self->{"Date"}
       and $self->{"Date"} =~ /^($datefmt)\s*-?\s*(.+,\s*[A-Z][A-Z]\b.*)$/i) {
      $self->{"Date"} = $1;
      $self->{"Venue"} = $2;
   }

   # Sometimes Date and Venue get smushed together (part 2)
   if (not exists $self->{"Date"}
       and exists $self->{"Venue"}
       and $self->{"Venue"} =~ /^($datefmt)\s*-?\s*(.+,\s*[A-Z][A-Z]\b.*)$/i) {
      $self->{"Date"} = $1;
      $self->{"Venue"} = $2;
   }

   if (exists $self->{"Date"} and defined $self->{"Date"}) {
      if ($have_date_parse) {
	 my $time = str2time ($self->{"Date"});
	 if (defined $time) {
	    $self->{"CanonicalDate"} =
	      strftime ("%Y-%m-%d", localtime ($time));
	 }
      } else {
	 if ($self->{Date} =~ m@^(\d{1,2})[-/](\d{1,2})[-/](\d{2}|\d{4})$@
	     and $1 >= 1 and $1 <= 12
	     and $2 >= 1 and $2 <= 31) {
	    my ($m, $d, $y) = ($1, $2, $3);
	    if (length $y == 2) {
	       if ($y < 60) {
		  $y += 2000;
	       } else {
		  $y += 1900; }
	    }
	    $self->{CanonicalDate} = sprintf ("%04d-%02d-%02d", $y, $m, $d);
	 } elsif ($self->{Date} =~ m@^(\d{4})[-/](\d\d)[-/](\d\d)$@
		 and $2 >= 1 and $2 <= 12
		 and $3 >= 1 and $3 <= 31) {
	    $self->{CanonicalDate} = sprintf ("%04d-%02d-%02d", $1, $2, $3);
	 }
      }
   }

   $self->altparseinfo unless $numsongs;
}

# altparseinfo - alternate parsing routine
sub altparseinfo {
   my $self = shift;

   my $songnum = 0;
   my $discnum = 1;		# start with disc 1
   my $numsongs = 0;
   my $index = 0;
   my $indisc = 0;
   my $set;

   foreach my $line (@{ $self->{"InfoFileLines"}}) {
      $line =~ s/^\s+//;
      $line =~ s/\s+$//;

      # looking for disc delimeters
      if ($line =~ /^\W*(?:cd|dis[kc]|volume)\W*(\d+|$numberwords)\b/i) {
	 $discnum = word2num ($1);
	 $indisc = 1;
	 $songnum = 0;
	 next;
      } elsif ($line =~ /^\W*set\s*(\d+|$numberwords)\b/ix) {
	 $set = word2num ($1);
      } elsif ($line =~ /^\W*encore\b/i) {
	 $set = "E";
      } elsif ($indisc) {
	 # we are trying to interpret the case where the songs are not
	 # numbered at all.  We will treat every non blank line as a
	 # song name - except those lines whose contents are "set* and
	 # encore* ...
	 if ($line =~ /\w/) {
	    $numsongs++;
	    $songnum++;
	    my ($title, $segue, $notes, $runtime, $maybeset) =
	      parsetitle ($line);
	    $set = $maybeset if defined $maybeset;

	    # check that there is a matching index in the shn's
	    if (exists $self->{"ShnIndex"}{$index}) {
	       $self->{"Discs"} = $discnum;
               $self->{"Disc"}{$discnum}{"Tracks"} = $songnum;
	       $self->{Songs}[$index] = { Disc => $discnum,
					  Track => $songnum,
					  Set => $set,
					  Title => $title,
					  Time => $runtime };
	       $self->{Songs}[$index]{Notes} = $notes if defined $notes;
	       $self->{Songs}[$index]{Segue} = $segue if defined $segue;

	       # Remove this from the "Etc" list if it is in there
	       if (exists $self->{"Etc"}) {
		  @{$self->{"Etc"}} = grep { $_ ne $line } @{$self->{"Etc"}};
	       }

	       ++$index;

	       $indisc = 0 if $numsongs == $self->{"NumSongs"};
	    }
	 }
      }
   }
}

sub _wrap {
   my $self = shift;
   my @KEYS = @_;
   my $value;

   foreach my $key (@KEYS) {
      if (exists $self->{$key}) {
	 $value = $self->{$key};
	 last;
      }
   }
   $value;
}

=item artist

Return the artist information that was parsed.  This is usually just
the first line from the info file.

=cut

sub artist { my $self = shift; $self->_wrap ("Band"); }

sub date { my $self = shift; $self->_wrap ("CanonicalDate", "Date"); }
sub year { my $self = shift; my $cd = $self->_wrap ("CanonicalDate");
	   if (defined $cd) { return substr ($cd, 0, 4) }
	   else { return 0 } }
sub venue { my $self = shift; $self->_wrap ("Venue"); }
sub source { my $self = shift; $self->_wrap ("Source"); }
sub transfer { my $self = shift; $self->_wrap ("Transfer"); }
sub taper { my $self = shift; $self->_wrap ("Taper"); }
sub seeder { my $self = shift; $self->_wrap ("Seeder"); }
sub num_discs { my $self = shift; $self->_wrap ("Discs"); }

sub album {
   my $self = shift;
   my $date = $self->date;
   my $album = (defined $date ? "$date " : "");
   $album .= $self->{Venue} if exists $self->{Venue};
   $album;
}

sub num_tracks {
   my $self = shift;
   my $disc = shift;
   defined $disc ? $self->{Disc}{$disc}{Tracks} : scalar (@{$self->{Songs}});
}

sub songs {
   my $self = shift;
   return unless exists $self->{Songs} and defined $self->{Songs};
   @{$self->{Songs}};
}

sub notes {
   my $self = shift;
   my $note = shift;

   if (defined $note) {
      if (exists $self->{Notes}{$note}) {
	 return $self->{Notes}{$note};
      }
   } else {
      return %{$self->{Notes}};
   }

   undef;
}

sub files {
   my $self = shift;
   my $ext = shift;

   $self->findfiles unless exists $self->{Files};

   if (defined $ext) {
      return sort keys %{$self->{ByExt}{lc $ext}};
   }
   return %{$self->{Files}};
}

=item parse

User entry point to the parsing code.  Should be called before any of
the data access mehtods.

=cut

sub parse {
   my $self = shift;
   my $infofile = shift;
   $self->{InfoFile} = $infofile if defined $infofile;
   $self->readtext;
   $self->parseinfo;
}

1;

__END__

=back

=head1 VERSION

$Id$

=head1 SEE ALSO

L<flacify>, L<makehbx>, L<shn2mp3>, L<http://etree.org/>

=head1 AUTHOR

Caleb Epstein E<lt>cae at bklyn dot orgE<gt>

=cut


