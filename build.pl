#!/usr/bin/perl

#--------------------------------------------#
# dat-browser                                #
# License: Public Domain (www.unlicense.org) #
#--------------------------------------------#

use strict;
use Encode;
use Archive::Zip;
use LWP::UserAgent;
use Time::HiRes;

our $template = "index.html";
our $outdir = "out";
our $cachedir = undef;
our $import_previous = "https://puredos.github.io/dat-browser/";

our %dats = (
	# Pure DOS DAT
	PURE => "https://github.com/PureDOS/DAT/archive/refs/heads/main.zip",

	# Total DOS Collection
	TDC05 => "http://www.totaldoscollection.org/nugnugnug/TDC_DAT_release_5.zip",
	TDC06 => "http://www.totaldoscollection.org/nugnugnug/TDC_DAT_release_6.zip",
	TDC07 => "http://www.totaldoscollection.org/nugnugnug/TDC_DAT_release_7.zip",
	TDC08 => "http://www.totaldoscollection.org/nugnugnug/TDC_DAT_release_8.zip",
	TDC09 => "http://www.totaldoscollection.org/nugnugnug/TDC_DAT_release_9.zip",
	TDC10 => "http://www.totaldoscollection.org/nugnugnug/TDC_DAT_release_10.zip",
	TDC11 => "http://www.totaldoscollection.org/nugnugnug/TDC_DAT_release_11.zip",
	TDC12 => "http://www.totaldoscollection.org/nugnugnug/TDC_DAT_release_12.zip",
	TDC13 => "http://www.totaldoscollection.org/nugnugnug/TDC_DAT_release_13.zip",
	TDC14 => "http://www.totaldoscollection.org/nugnugnug/TDC_DAT_release_14.zip",
	TDC15 => "http://www.totaldoscollection.org/nugnugnug/TDC_DAT_release_15.zip",
	TDC16 => "http://www.totaldoscollection.org/nugnugnug/TDC_DAT_release_16.zip",
	TDC17 => "http://www.totaldoscollection.org/nugnugnug/TDC_DAT_release_17.zip",
	TDC18 => "http://www.totaldoscollection.org/nugnugnug/TDC_DAT_release_18.zip",
	TDC19 => "http://www.totaldoscollection.org/nugnugnug/TDC_DAT_release_19.zip",
	TDC20 => "http://www.totaldoscollection.org/nugnugnug/TDC_DAT_release_20.zip",
	TDC21 => "http://www.totaldoscollection.org/nugnugnug/TDC_DAT_release_21.zip",
	TDC22 => "http://www.totaldoscollection.org/nugnugnug/TDC_DAT_release_22.zip",
	TDC23 => "http://www.totaldoscollection.org/nugnugnug/TDC_DAT_release_23.zip",

	# The Good Old Days (wrong SHA1s fixed and missing files added by PureDOS)
	TGOD => "https://github.com/PureDOS/dat-browser/releases/download/dats/tgod_floppy_images_pdfix.zip",

	# Digitoxin's PC Game Preservation Project (https://github.com/Eggmansworld/Datfiles/releases/tag/digitoxin)
	DIGITOXIN => "https://github.com/Eggmansworld/Datfiles/releases/download/digitoxin/Digitoxin.s.PC.Game.Preservation.Project.2026-04-30_RomVault.zip",
);

our %dat_filter = map { die "Build for unknown DAT requested '".uc($_)."'" if !$dats{uc($_)}; uc($_) => 1; } @ARGV;

our %zipfilter = (
	DIGITOXIN => qr/^Floppy\//,
	PURE => qr/\.xml$/,
);

our (%gamedb, %tdc_tagsdb);

our %tdc_validtags = (
	"!" => 1, "Action" => 1, "Addon" => 1, "Adult" => 1, "Adventure" => 1, "Board" => 1, "Cards" => 1, "Chess" => 1, "Compilation" => 1, "Educational" => 1, "Golf" => 1, "Interactive Fiction" => 1, "Overlord" => 1, "Prologue" => 1, "Puzzle" => 1, "Racing" => 1, "Racing - Driving" => 1, "Role Playing (RPG)" => 1, "Role-Playing (RPG)" => 1, "Role-playing (RPG)" => 1, "Simulation" => 1, "Sports" => 1, "Strategy" => 1, "TAC" => 1, "TC" => 1, "TD0" => 1, "Tennis" => 1, "Trivia" => 1, "War" => 1,
	"a1" => 1, "a2" => 1, "a3" => 1, "a4" => 1, "a5" => 1, "a6" => 1, "a7" => 1, "a8" => 1, "a9" => 1, "alt" => 1, "b1" => 1, "b2" => 1, "b3" => 1, "b4" => 1, "b5" => 1, "b6" => 1, "b7" => 1, "b8" => 1, "cp" => 1, "cr" => 1, "f1" => 1, "f2" => 1, "h1" => 1, "h2" => 1, "h3" => 1, "h4" => 1, "h5" => 1, "h6" => 1, "h7" => 1, "o1" => 1, "o2" => 1, "o3" => 1,
	"tr Ar" => 1, "tr Cs" => 1, "tr De" => 1, "tr En" => 1, "tr Es" => 1, "tr Fi" => 1, "tr Fr" => 1, "tr He" => 1, "tr It" => 1, "tr Ko" => 1, "tr No" => 1, "tr Pt" => 1, "tr Ru" => 1, "tr Tr" => 1, "tr Zh" => 1, "tr-Ru" => 1,
	"SW" => 1, "SWR" => 1, "DC" => 1, "FW" => 1, "Fw" => 1,
	"CCD" => 1, "ccd" => 1, "ISO" => 1, "bin-cue" => 1, "NRG" => 1, "mdf" => 1, "IMA" => 1, "IMD" => 1, "tc" => 1, "JRC" => 1, "cr" => 1,
	"1.440k" => 1, "1.44M" => 1, "1200" => 1, "1200k" => 1, "1200k-1440k" => 1, "1200k-360k" => 1, "1220k" => 1, "1220k-360k" => 1, "1220kb" => 1, "1440K" => 1, "1440k" => 1, "1440k-720k" => 1, "160" => 1, "160k" => 1, "180k" => 1, "180k-360k" => 1, "320k" => 1, "360" => 1, "360K" => 1, "360k" => 1, "360k-1200k" => 1, "360k-720k" => 1, "720" => 1, "720K" => 1, "720k" => 1, "720k-1200k" => 1, "720k-1220k" => 1, "720k-1440k" => 1,
);

our %digitoxin_ignoredirs = ( "Docs" => 1, "Flux" => 1, "Patch Disks" => 1, "TSN" => 1 );
our $digitoxin_ignoregames = qr/^(NamingScheme|forensics)(\.txt|)$| - Docs$|\[Flux\]/;

our %known_duplicates = ( "Willow (1988) (360K) [cp cr] [M]" => 1 );

if ($cachedir) { mkdir($cachedir); }

print "Parsing DATs ...\n";
my $releases_start = [Time::HiRes::gettimeofday()];
foreach my $datid (sort keys %dats)
{
	if (%dat_filter && !$dat_filter{$datid}) { next; }
	print "  Loading DAT for $datid ...\n";
	my $dat = Get($dats{$datid}, $zipfilter{$datid});
	unless ($dat) { die "Got no DAT for $datid from '".$dats{$datid}."'\n"; }

	my $cut_r = (index($dat, "\r") == -1 ? 0 : 1);
	if ((index($dat, '<?xml version="1.0"')|0) <= 3) #can be at offset 3 if there's a UTF-8 BOM
	{
		for (my ($i, $iNext, $iEnd, $rel, $ingame, $inheader, @filearr) = (0, 0, length($dat), $datid); $i < $iEnd; $i = ($iNext == -1 ? $iEnd : $iNext + 1))
		{
			$iNext = index($dat, "\n", $i);
			while (index($dat, "\t", $i) == $i) { $i++; }
			my $ln = substr($dat, $i, ($iNext == -1 ? $iEnd : ($iNext - $cut_r)) - $i);
			if ($ingame)
			{
				if ($ln =~ /^<rom name="([^\"]+)" sha1="[^\"]+" crc="([^\"]+)"  size="(\d+)"(?: status="[^\"]+"?|) \/>$/) #TGOD
				{
					my ($fname, $fcrc, $fsize) = ($1, $2, $3);
					push(@filearr, "[\"".$fname."\",".int($fsize).",0,0,0,0,0,0,\"".lc($fcrc)."\"]");
				}
				elsif ($ln =~ /^<rom name="([^\"]+)" size="(\d+)" crc="([^\"]+)" sha1="[^\"]+"\/?>$/) #DIGITOXIN
				{
					my ($fname, $fsize, $fcrc) = ($1, $2, $3);
					push(@filearr, "[\"".$fname."\",".int($fsize).",0,0,0,0,0,0,\"".lc($fcrc)."\"]");
				}
				elsif ($ln =~ /^<rom name="([^\"]+)" size="(\d+)" crc="([^\"]+)" md5="[^\"]+" sha1="[^\"]+"(?: date="(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)"|)(?: data="[^\"]+"|)\/?>$/) #PURE
				{
					my ($fname, $fsize, $fcrc, $fyear,$fmon,$fday,$fhour,$fmin,$fsec) = ($1, $2, $3, $4, $5, $6, $7, $8, $9);
					push(@filearr, "[\"".$fname."\",".int($fsize).",".int($fyear-1900).",".int($fmon).",".int($fday).",".int($fhour).",".int($fmin).",".int($fsec).",\"".lc($fcrc)."\"]");
				}
				elsif ($ln =~ /^<\/game>$/)
				{
					if (!@filearr)                  { print "    [$datid] No file in '$ingame'\n"; next; }
					if (!$rel)                        { die "    [$datid] Missing release id for '$ingame'\n"; }
					if (index($ingame, "\x7F") != -1) { die "    [$datid] 7F byte in name '$ingame'\n"; }
					if (index($ingame, "\xFF") != -1) { die "    [$datid] FF byte in name '$ingame'\n"; }
					if (index($ingame, "\"") != -1)   { die "    [$datid] Double quote in name '$ingame'\n"; }
					if (index($ingame, "\\") != -1)   { die "    [$datid] Backslash in name '$ingame'\n"; }
					#if (index($ingame, "/") != -1)   { die "    [$datid] Slash in name '$ingame'\n"; } #TGOD has slashes
					my $filars = join(",", sort @filearr);
					$filars =~ s/\\/\//g;$filars=~s/\&amp;/\&/g;$filars=~s/\&\#(\d+);/pack("C",$1)/eg;$filars=~s/\&lt;/</g;$filars=~s/\&quot;/"/g;$filars=~s/\&gt;/>/g;$filars=~s/\&apos;/'/g;
					$ingame =~ s/\\/\//g;$ingame=~s/\&amp;/\&/g;$ingame=~s/\&\#(\d+);/pack("C",$1)/eg;$ingame=~s/\&lt;/</g;$ingame=~s/\&quot;/"/g;$ingame=~s/\&gt;/>/g;$ingame=~s/\&apos;/'/g;
					if (index($filars, "\x7F") != -1) { die "    [$datid] 7F byte in file list of '$ingame'\n\n$filars"; }
					if (index($filars, "\xFF") != -1) { die "    [$datid] FF byte in file list of '$ingame'\n\n$filars"; }
					die "[$datid] [$ingame] [$filars]" if $filars =~ /forensics|namingscheme/i or $ingame =~ /forensics|namingscheme/i;
					for (my ($orgingame, $duplnum, $have) = ($ingame, 2);;)
					{
						my $have = $gamedb{$ingame}->{$rel};
						if (!$have) { $gamedb{$ingame}->{$rel} = $filars; last; }
						if ($have eq $filars) { last; }
						if (!$known_duplicates{$ingame}) { print "    [$datid] Duplicate game '$ingame'!\n"; }
						$ingame = $orgingame." (#".($duplnum++).")";
					}
					$ingame = 0;
				}
				elsif ($ln =~ /^<description>[^<]+<\/description>$/)
				{
					if ($datid eq "TGOD")
					{
						my ($desc_title, $desc_id) = ($ln =~ /^<description>(.*?) \[(\d+)\]<\/description>$/);
						my ($tgod_id, $tgod_code) = ($ingame =~ /^00(\d+)_(.*)$/); #$tgod_code =~ s/_/ /g; #$tgod_code =~ s/((?:^|\s)\w)/\U$1\E/g;
						unless ($desc_title) { die "    Malformed TGOD description '$ln' for $ingame\n"; }
						unless ($desc_id == $tgod_id) { die "    ID in TGOD description '$ln' for $ingame does not match $tgod_id\n"; }
						($ingame, $rel) = ($desc_title, "TGOD $tgod_id");
					}
				}
				elsif ($ln =~ /^<year>[^<]+<\/year>$/) { }
				elsif ($ln =~ /^<comment>[^<]+<\/comment>$/) { }
				elsif ($ln =~ /^<comment_dosc>[^<]+<\/comment_dosc>$/) { }
				elsif ($ln =~ /^<developer>[^<]+<\/developer>$/) { }
				elsif ($ln =~ /^<parent>[^<]+<\/parent>$/) { }
				elsif ($ln =~ /^<variant>[^<]+<\/variant>$/) { }
				elsif ($ln =~ /^<media_link>[^<]+<\/media_link>$/) { }
				elsif ($ln =~ /^<link[^<]+<\/link>$/) { }
				elsif ($ln =~ /^<source type=[^>]+\/>$/) { }
				elsif ($ln =~ /^<track number=[^>]+\/>$/) { }
				elsif ($ln =~ /^<patch data=[^>]+\/>$/) { }
				elsif ($ln =~ /^<\/rom>$/) { }
				elsif ($ln eq "<comment>") { $iNext = index($dat, "</", $iNext); die if substr($dat, $iNext, 11) ne "</comment>\n"; $iNext += 10; } 
				elsif ($ln eq "<comment_dosc>") { $iNext = index($dat, "</", $iNext); die if substr($dat, $iNext, 16) ne "</comment_dosc>\n"; $iNext += 15; } 
				else { die "    Unknown XML game line [$ln]"; }
			}
			elsif ($ln =~ /^<game name="([^\"]+)">$/)
			{
				$ingame = $1;
				@filearr = ();
				if ($datid eq "TGOD") { $rel = 0; } #wait for description
				elsif ($datid eq "DIGITOXIN" && $ingame =~ $digitoxin_ignoregames)
				{
					$iNext = index($dat, "</game>\n", $iNext)+7;
					$ingame = 0;
				}
			}
			elsif ($inheader)
			{
				if ($ln =~ /<name>(.*?)<\/name>/) { print "    Parsing DAT Name: $1\n"; }
				if ($ln eq "</header>") { $inheader = 0; }
			}
			elsif ($ln =~ /^<dir name="([^\"]+)">$/ && $datid eq "DIGITOXIN")
			{
				if ($digitoxin_ignoredirs{$1}) { $iNext = index($dat, "</dir>\n", $iNext)+6; } #print "      Ignoring DIGITOXIN <DIR> tag $1\n"; }
				#else { print "      Including DIGITOXIN <DIR> tag $1\n"; }
			}
			elsif ($ln eq "<header>") { $inheader = 1; }
			elsif ($ln eq "</dir>") {}
			elsif ($ln eq '<datafile>') {}
			elsif ($ln eq '</datafile>') {}
			elsif ($ln eq '<?xml version="1.0" encoding="UTF-8"?>') {}
			elsif ($ln eq '<?xml version="1.0"?>') {}
			elsif ($ln eq "\xef\xbb\xbf".'<?xml version="1.0"?>') {}
			elsif ($ln eq '<!DOCTYPE datafile PUBLIC "-//Logiqx//DTD ROM Management Datafile//EN" "http://www.logiqx.com/Dats/datafile.dtd">') {}
			elsif ($ln eq '') {}
			else { die "    Unknown XML root line [$ln]"; }
		}
	}
	elsif ((index($dat, "DOSCenter (")|0) <= 3) #can be at offset 3 if there's a UTF-8 BOM
	{
		my $isutf8 = ((substr($dat, 0, 3) eq "\xEF\xBB\xBF") || (index($dat, "\xC3\xB8") > 0)); # find UTF-8 BOM or UTF-8 o with slash in Broderbund
		for (my ($i, $iNext, $iEnd, $ingame, @filearr) = (0, 0, length($dat), 0); $i < $iEnd; $i = ($iNext == -1 ? $iEnd : $iNext + 1))
		{
			$iNext = index($dat, "\n", $i);
			my $ln = substr($dat, $i, ($iNext == -1 ? $iEnd : ($iNext - $cut_r)) - $i);
			if ($ingame)
			{
				my $fourcode = substr($ln, 1, 4);
				if ($fourcode eq "name" && $ln =~ /^\tname "(?:\\[\dx]+\\|\\|)(.+?).(?:zip|ZIP|7z|7Z)"$/s)
				{
					if ($ingame ne "(") { die "    [$datid] Double game '$ingame' [$1]\n"; }
					$ingame = $1;
					if (index($ingame, "(Installer)") != -1) { $ingame = 0; next; }
					my $gameyear = (($ingame =~ /\((\d+x* ?)\)/)[0]);
					#if (!$gameyear) { print "    No year in '$ingame'\n"; }
					if (!$gameyear) { $ingame = 0; next; }
					my ($invalid_tag);
					while ($ingame =~ /\[([^\[\]]+)\]/g)
					{
						my $tags = $1;
						while ($tags =~ /\s*([^,]+)\s*/g)
						{
							if (!$tdc_validtags{$1}) { $invalid_tag++; }
							#if (!$tdc_tagsdb{$1}) { $tdc_tagsdb{$1} = 1; print "    \"$1\" => 1,\n"; }
						}
					}
					if ($invalid_tag) { $ingame = 0; next; }
					@filearr = ();
				}
				elsif ($fourcode eq "file" && $ln =~ /^\tfile \( name (.+?) size (\S+) date (\d+)[\/\\](\d+)[\/\\](\d+) (\d+):(\d+)(?::(\d+)|) crc (\w+) \)$/)
				{
					my ($fname, $fsize, $fyear,$fmon,$fday,$fhour,$fmin,$fsec, $fcrc) = ($1, $2, $3, $4, $5, $6, $7, $8, $9);
					if (index($fname, '"') >= 0) { $fname =~ s/\"/\\\"/g; } #{ die "Double quote in file name [$&]\n"; }
					if (int($fyear) < 1900) { die "Unknown year in [$&]\n"; }
					$fname =~ s/\\/\//g;
					push(@filearr, "[\"".$fname."\",".int($fsize).",".int($fyear-1900).",".int($fmon).",".int($fday).",".int($fhour).",".int($fmin).",".int($fsec).",\"".lc($fcrc)."\"]");
				}
				elsif ($ln eq ")")
				{
					if ($ingame eq "(") { die "    Missing game name '$ingame'\n"; }
					if (!@filearr)                  { print "    [$datid] No file in '$ingame'\n"; next; }
					if (index($ingame, "\x7F") != -1) { die "    [$datid] 7F byte in name '$ingame'\n"; }
					if (index($ingame, "\xFF") != -1) { die "    [$datid] FF byte in name '$ingame'\n"; }
					if (index($ingame, "\"") != -1)   { die "    [$datid] Double quote in name '$ingame'\n"; }
					if (index($ingame, "\\") != -1)   { die "    [$datid] Backslash in name '$ingame'\n"; }
					if (index($ingame, "/") != -1)    { die "    [$datid] Slash in name '$ingame'\n"; }
					my $filars = join(",", sort @filearr);
					if (!$isutf8) { Encode::from_to($filars, 'cp1250', 'utf8'); }
					$filars =~ s/\\/\//g;$filars=~s/\&amp;/\&/g;$filars=~s/\&\#(\d+);/pack("C",$1)/eg;$filars=~s/\&lt;/</g;$filars=~s/\&quot;/"/g;$filars=~s/\&gt;/>/g;$filars=~s/\&apos;/'/g;
					$ingame =~ s/\\/\//g;$ingame=~s/\&amp;/\&/g;$ingame=~s/\&\#(\d+);/pack("C",$1)/eg;$ingame=~s/\&lt;/</g;$ingame=~s/\&quot;/"/g;$ingame=~s/\&gt;/>/g;$ingame=~s/\&apos;/'/g;
					#if (index($filars, "\x7F") != -1) { die "    [$datid] 7F byte in file list of '$ingame'\n\n$filars"; } # 7F is contained in non UTF-8 dats (before TDC14)
					if (index($filars, "\xFF") != -1) { die "    [$datid] FF byte in file list of '$ingame'\n\n$filars"; }
					if ($gamedb{$ingame}->{$datid}) { die "    [$datid] Duplicate game '$ingame'!\n"; }
					$gamedb{$ingame}->{$datid} = $filars;
					$ingame = 0;
				}
				else { die "Unknown DOSCenter game line [$ln]\n"; }
			}
			elsif ($ln eq "game (")
			{
				$ingame = "(";
			}
			elsif ($ln eq ")") {}
			elsif ($ln eq "") {}
			elsif (substr($ln, 1, 4) eq "file" && $ln =~ /^\tfile \( name (.+?) size (\S+) date (\d+)[\/\\](\d+)[\/\\](\d+) (\d+):(\d+)(?::(\d+)|) crc (\w+) \)$/) {} # for files games ignored due to tags
			elsif ((index($ln, "DOSCenter (")|0) <= 3) {} #can be at offset 3 if there's a UTF-8 BOM
			elsif ($ln =~ /\b(Name|Description|Version|Date|Author|Homepage|Comment):/) {}
			else { die "    Unknown DOSCenter root line [$ln]"; }
		}
	}
	else { die "    Unknown DAT format '$datid'"; }
}
print "Parsing DATs done (".(Time::HiRes::tv_interval($releases_start)*1000)."ms)\n\n";

if ($import_previous && %dat_filter)
{
	print "Importing previous data ...\n";
	my $import_start = [Time::HiRes::gettimeofday()];
	my $html = Get($import_previous."index.html");
	my ($oldranges) = ($html =~ /var ranges = \[([\d\s,]+)\]/);
	foreach my $oldrange (split(/\s*,\s*/, $oldranges))
	{
		my $js = Get($import_previous."dat_".$oldrange.".js");
		while ($js =~ /\["(.*?[^\\])",\[([^\]]+)\],\[(.*?)\]\],\n/g)
		{
			die "Got escape sequence in row '$&' of range $oldrange!\n" if index($&, "\\") >= 0;
			my ($ingame, $datids, $filearrstr) = ($1, $2, $3);
			$datids =~ s/\'//g;
			for my $datid (split(/,/, $datids))
			{
				if ($dat_filter{$datid}) { next; }
				$gamedb{$ingame}->{$datid} = $filearrstr;
			}
		}
	}
	print "Importing previous data done (".(Time::HiRes::tv_interval($import_start)*1000)."ms)\n\n";
}

if (!mkdir($outdir))
{
	opendir(DIR, $outdir);
	my @files = readdir(DIR);
	closedir(DIR);
	foreach my $f (@files) { if (substr($f, 0, 1) ne ".") { unlink($outdir."/".$f); } }
}

print "Building JS data set into '$outdir'...\n";
my $ranges;
my @gamedb_names = sort { "\L$a".$a cmp "\L$b".$b } keys %gamedb;
my $output_start = [Time::HiRes::gettimeofday()];
for (my ($i, $ilast, $outlen, $prevgame, $lastsplit, $nextrange, @out) = (0, @gamedb_names-1, 0, "", 0, 0); $i <= $ilast; $i++)
{
	my $ingame = $gamedb_names[$i];
	if (uc(substr($ingame, 0, 4)) ne uc(substr($prevgame, 0, 4)))
	{
		$lastsplit = @out;
	}
	$prevgame = $ingame;

	my %filesets;
	foreach my $datid (reverse sort { $a cmp $b } keys %{$gamedb{$ingame}})
	{
		my $filearr = $gamedb{$ingame}->{$datid};
		$filesets{$filearr} .= $datid.",";
	}

	my %datsets = reverse %filesets;
	foreach my $datset (reverse sort { $a cmp $b } keys %datsets)
	{
		my $line = "[\"$ingame\",[".join(",", map { "'$_'" } sort { $a cmp $b } grep { length > 0 } split(",", $datset))."],[".$datsets{$datset}."]],\n";
		push(@out, $line);
		$outlen += length($line);
	}

	my $isend = ($i == $ilast);
	if (($outlen > 512*1024 && $lastsplit) || $isend)
	{
		my @block = splice(@out, 0, ($isend ? int(@out) : $lastsplit));
		#print "    Writing "."dat_".$nextrange.".js"."\n";
		open(OUT, ">:raw", $outdir."/"."dat_".$nextrange.".js");
		print OUT "document.OnDATData([\n";
		print OUT join("", @block);
		print OUT "]);";

		$ranges .= $nextrange.($isend ? "" : ",");
		$nextrange = unpack("N", uc(substr($block[-1], 2, 4))."\0\0\0\0") + 1;
		$lastsplit = 0;
		$outlen = length(join("", @out));
	}
}
print "Building JS data set done (".(Time::HiRes::tv_interval($output_start)*1000)."ms)\n\n";

print "Building index.html from $template ...\n";
open(IN, "<:raw", $template);
open(OUT, ">:raw", $outdir."/index.html");
while (<IN>)
{
	my $line = $_;
	$line =~ s/<<<RANGES>>>/$ranges/;
	print OUT $line;
}
close(OUT);
close(IN);
print "Building index.html done\n\n";

sub Get
{
	my ($path, $bin) = ($_[0], "");
	if ($cachedir && $path =~ /[^\\\/]+$/ && -e $cachedir."/".(($path =~ /([^\\\/]+)$/)[0]))
	{
		$path = $cachedir."/".(($path =~ /([^\\\/]+)$/)[0]);
		print("    Loading cached '".$path."' ...\n");
		open(IN,"<:raw", $path); $bin.= $_ while <IN>; close(IN);
	}
	elsif (index($path, "://") > 0)
	{
		for (my $retry = 0;; $retry++)
		{
			print("    Downloading '".$path."' ".($retry ? "(Retry $retry)" : "")."...\n");
			my $ua = LWP::UserAgent->new(send_te => 0, ssl_opts => { verify_hostname => 0 }, protocols_allowed => ['http','https'],);
			my $req = HTTP::Request->new('GET', $path, [ 'Accept-Encoding' => scalar(HTTP::Message::decodable) ]); # use gzip/zlib if possible
			#print "REQUEST: \n-----------------------\n".$ua->prepare_request($req)->as_string."\n----------------------------\n";#exit;
			my $res = $ua->request($req);
			#print "RESPONSE: \n-----------------------\n".$res->as_string."\n----------------------------\n";#exit;
			$bin =  $res->decoded_content(charset => 'none');
			if ($res->code >= 200 && $res->code <= 299) { last; }
			if ($retry == 10) { die "Download of '$path' failed\n"; }
		}
	}
	else
	{
		print("    Loading '".$path."' ...\n");
		open(IN,"<:raw", $path); $bin.= $_ while <IN>; close(IN);
	}

	if ($cachedir && index($path, $cachedir) != 0)
	{
		my $outpath = $cachedir."/".(($path =~ /([^\\\/]+)$/)[0]);
		print("    Caching '".$path."' to '".$outpath."' ...\n");
		open(OUT,">:raw", $outpath); print OUT $bin; close(OUT);
	}
	
	if ($path =~ /\.zip$/ && $bin)
	{
		open(my $dh, "+<:raw", \$bin) or die;
		my $zip = Archive::Zip->new;
		$zip->readFromFileHandle($dh);
		my ($dats, $mixedrn) = ("");
		foreach my $m ($zip->memberNames())
		{
			if ($m =~ /\/$/ || ($_[1] && $m !~ $_[1])) { next; }
			if ($m !~ /.(dat|xml)$/i) { die "Non-DAT file in ZIP of '$path' ($m)\n"; }
			if ($dats) { $dats .= "\n"; $mixedrn = 1; }
			$dats .= $zip->contents($m);
		}
		close($dh);
		if ($mixedrn) { $dats =~ s/\r//g; }
		$bin = $dats;
	}
	return $bin;
}
