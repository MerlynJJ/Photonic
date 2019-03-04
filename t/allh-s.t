use strict;
use warnings;
use PDL;
use PDL::NiceSlice;
use PDL::Complex;
use Photonic::Geometry::FromEpsilon;
use Photonic::LE::S::AllH;
use Photonic::Utils qw(SProd);

use List::Util;
use Machine::Epsilon;
use Test::More tests => 11;

#my $pi=4*atan2(1,1);

sub Cagree {    
    my $a=shift;
    my $b=shift//0;
    return (($a-$b))->Cabs2->sum<=1e-7;
}

#Check haydock coefficients for simple 1D system
my ($ea, $eb)=(1+2*i, 3+4*i);
my $f=6/11;
my $eps=$ea*(zeroes(11)->xvals<5)+ $eb*(zeroes(11)->xvals>=5)+0*i; 
my $g=Photonic::Geometry::FromEpsilon
    ->new(epsilon=>$eps, Direction0=>pdl([1])); 
my $a=Photonic::LE::S::AllH->new(geometry=>$g, nh=>10);
$a->run;
my $as=$a->as;
my $bs=$a->bs;
my $b2s=$a->b2s;
is($a->iteration, 2, "Number of iterations 1D longitudinal");
ok(Cagree($b2s->[0], r2C(1)), "1D L b_0^2");
ok(Cagree($as->[0], $ea*(1-$f)+$eb*$f), "1D L a_0");
ok(Cagree($as->[1], $ea*$f+$eb*(1-$f)), "1D L a_1");
ok(Cagree($b2s->[1], ($eb-$ea)**2*$f*(1-$f)), "1D L b_1^2");
ok(Cagree(pdl($b2s)->complex, (pdl($bs)->complex)**2), "1D L b2==b^2");

#View 1D system as 2D. Transverse direction
my $epst=$ea*(zeroes(1,11)->xvals<5)+ $eb*(zeroes(1,11)->xvals>=5)+0*i; 
my $gt=Photonic::Geometry::FromEpsilon
   ->new(epsilon=>$epst, Direction0=>pdl([1,0])); #trans 
my $at=Photonic::LE::S::AllH->new(geometry=>$gt, nh=>10);
$at->run;
my $ast=$a->as;
my $bst=$a->bs;
my $b2st=$a->b2s;
is($at->iteration, 1, "Number of iterations 1D trans");
ok(Cagree($b2st->[0], 1), "1D T b_0^2");
ok(Cagree($ast->[0], $ea*(1-$f)+$eb*$f), "1D T a_0");
ok(Cagree(pdl($b2st)->complex, (pdl($bs)->complex)**2), "1D T b2==b^2");

#check reorthogonalize with square array
my $epss=$eb*(zeroes(15,15)->rvals<5)+$ea*(zeroes(15,15)->rvals>=5);
my $gs=Photonic::Geometry::FromEpsilon
    ->new(epsilon=>$epss, Direction0=>pdl([1,0]), L=>pdl(1,1));
my $als=Photonic::LE::S::AllH
    ->new(geometry=>$gs, nh=>2*15*15, reorthogonalize=>1, 
	  accuracy=>machine_epsilon(), noise=>3*machine_epsilon(),
	  normOp=>$eb->Cabs); 
$als->run;
ok($als->iteration <= 15*15, "No more iterations than dimensions");
diag("Actual iterations: " .$als->iteration
     . " Actual orthogonalizations: " . $als->orthogonalizations);
