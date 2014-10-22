#!/usr/bin/perl -w
use strict;
use DB_File;
use MLDBM qw(DB_File Storable);
use Fcntl;

sub usage()
{
    print "gzip -cd /mounts/dist/full/full-head-x86_64/ARCHIVES.gz | $0\n";
    exit 0;
}

if(@ARGV) {usage}

my (%data, %dbdata);
my (%filepkgmap, %dbfilepkgmap);
my (%pkgsrcmap, %dbpkgsrcmap);

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
            $info="$file $perm $linkcount, $owner, $group, $size, $date";
            $filepkgmap{$file}=$pkgname;
            #push(@{$data{$pkgname}{files}}, $file);
        }
        #print "$arch $pkgname $pkgsrcmap{$pkgname} $info\n";
}

print "writing out data...\n";
###
my $filepkgmapfile='/dev/shm/filepkg.new.dbm';
unlink $filepkgmapfile;
tie %dbfilepkgmap, "DB_File", $filepkgmapfile, O_RDWR|O_CREAT, 0666;
%dbfilepkgmap=%filepkgmap;
untie %dbfilepkgmap;
###
my $pkgsrcmapfile='/dev/shm/pkgsrc.new.dbm';
unlink $pkgsrcmapfile;
tie %dbpkgsrcmap, "DB_File", $pkgsrcmapfile, O_RDWR|O_CREAT, 0666;
%dbpkgsrcmap=%pkgsrcmap;
untie %dbpkgsrcmap;
###
my $dbm = tie %dbdata, 'MLDBM', "packages.mldbm", O_RDWR|O_CREAT, 0666;
%dbdata=%data;
untie %dbdata;

