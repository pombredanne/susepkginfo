#!/usr/bin/perl -w
use strict;
use DB_File;
use Fcntl;

sub usage()
{
    print "gzip -cd /mounts/dist/full/full-head-x86_64/ARCHIVES.gz | $0\n";
    exit 0;
}

if(@ARGV) {usage}

my %data;
my %filepkgmap;
my %pkgsrcmap;
my %binpath=qw(/bin 1 /sbin 1 /usr/bin 1 /usr/sbin 1);

while(<>) {
    next unless m{\./(.*)\.rpm:    (.*)};
    my ($pkg, $info)=($1, $2);
    next unless $pkg=~m{suse/([^/]+)/([^/]+)};
    my ($arch, $pkgname)=($1, $2);
    if ($info=~m/^Version\s*: (\S+)/) {$data{$pkgname}{version}=$1}
    if ($info=~m/^Release\s*: (\S+)/) {$data{$pkgname}{release}=$1}
    if ($info=~m/^Source RPM\s*: (\S+)-[^-]+-[^-]+\.\w+\.rpm$/) {
        $pkgsrcmap{$pkgname}=$1;
        $data{$pkgname}{srcpkg}=$1;
    } elsif ($info=~m/^([dl-][r-][w-][x-][r-][w-][x-][r-][w-][x-])\s+(\d+)\s+(\S+)\s+(\S+)\s+(\d+)\s+(\w{3}\s+\d+\s+[0-9:]+)\s+(.*)/) {
        my ($perm, $linkcount, $owner, $group, $size, $date, $file)=($1, $2, $3, $4, $5, $6, $7);
        if($perm=~m/^l/) { # is a link
            $file=~s/ -> .*//; # strip link target
        }
        push(@{$filepkgmap{$file}}, $pkgname);
        if($perm=~/^-rwx/ && $file!~m{/usr/lib/debug} && 
          $file=~m{(.*bin)/([^/]+)$} && !$binpath{$1}) {
            my($p,$f)=($1,$2);
            $filepkgmap{"/xbin/$f"}=$pkgname;
            #print "found executable in $p / $f\n";
        }
        #push(@{$data{$pkgname}{files}}, $file);
        #$info="$file $perm $linkcount, $owner, $group, $size, $date";
    }
    #print "$arch $pkgname $pkgsrcmap{$pkgname} $info\n";
}

print "writing out data...\n";
sub writehash($$)
{
    my ($filename, $hash) = @_;
    foreach my $k (sort keys(%$hash)) {
        next unless ref($hash->{$k});
        $hash->{$k}=join("\000", @{$hash->{$k}}); # convert arrayref into string
    }
    unlink $filename;
    my %dbmap;
    tie %dbmap, "DB_File", $filename, O_RDWR|O_CREAT, 0666;
    %dbmap=%$hash;
    untie %dbmap;
}

my $tmpdir='/dev/shm/parsearchives';
mkdir $tmpdir;
chmod 0755, $tmpdir or die "could not mkdir/chmod $tmpdir";
writehash("$tmpdir/filepkg.dbm", \%filepkgmap);
writehash("$tmpdir/pkgsrc.dbm", \%pkgsrcmap);

