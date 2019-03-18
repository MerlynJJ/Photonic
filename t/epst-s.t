use strict;
use warnings;
use PDL;
use PDL::NiceSlice;
use PDL::Complex;
use Photonic::Geometry::FromEpsilon;
use Photonic::LE::S::EpsTensor;

use Machine::Epsilon;
use List::Util;

use Test::More tests => 5;

#my $pi=4*atan2(1,1);

sub Cagree {    
    my $a=shift;
    my $b=shift//0;
    my $prec=shift//1e-7;
    return (($a-$b)->Cabs2)->sum<=$prec;
}

my $ea=1+2*i;
my $eb=3+4*i;
#Check haydock coefficients for simple 1D system
my $B=zeroes(11)->xvals<5; #1D system
my $f=$B->sum/$B->nelem;
my $epsilon=$ea*(1-$B)+$eb*$B;
my $gl=Photonic::Geometry::FromEpsilon->new(epsilon=>$epsilon); #long
my $elo=Photonic::LE::S::EpsTensor->new(geometry=>$gl, nh=>10); 
my $elv=$elo->epsTensor;
my $elx=1/((1-$f)/$ea+$f/$eb);
ok(Cagree($elv, $elx), "1D long epsilon");
is($elo->converged,1, "Converged");
#View 2D from 1D superlattice.
my $Bt=zeroes(1,11)->yvals<5; #2D flat system
my $epsilont=$ea*(1-$Bt)+$eb*$Bt;
my $gt=Photonic::Geometry::FromEpsilon->new(epsilon=>$epsilont); #trans
my $eto=Photonic::LE::S::EpsTensor->new(geometry=>$gt, nh=>10);
my $etv=$eto->epsTensor;
my $etx=(1-$f)*$ea+$f*$eb;
my $etenx=pdl([$etx, 0+0*i],[0+0*i, $elx])->complex;
ok(Cagree($etv, $etenx), "1D trans epsilon");
is($eto->converged,1, "Converged");
#Keller
my $Nk=6;
my $Bk=zeroes(2*$Nk,2*$Nk);
$Bk=((($Bk->xvals<$Nk) & ($Bk->yvals<$Nk))
   | (($Bk->xvals>=$Nk) & ($Bk->yvals>=$Nk)));
my $epsilonk=$ea*(1-$Bk)+$eb*$Bk;
my $gk=Photonic::Geometry::FromEpsilon->new(epsilon=>$epsilonk); #
my $eko=Photonic::LE::S::EpsTensor->new(
    geometry=>$gk, nh=>1000, reorthogonalize=>1, use_mask=>1);
my $etva=$eko->epsTensor;
my $epsilonkk=$eb*(1-$Bk)+$ea*$Bk;
my $gkk=Photonic::Geometry::FromEpsilon->new(epsilon=>$epsilonkk); #
my $ekko=Photonic::LE::S::EpsTensor->new(
    geometry=>$gkk, nh=>1000, reorthogonalize=>1, use_mask=>1);
my $etvb=$eko->epsTensor;
my $etvr=zeroes(2,2,2)->complex;
$etvr->(:,(0),(0)).= $etvb->(:,(1),(1));
$etvr->(:,(0),(1)).=-$etvb->(:,(1),(0));
$etvr->(:,(1),(0)).=-$etvb->(:,(0),(1));
$etvr->(:,(1),(1)).= $etvb->(:,(0),(0));
my $etvar=($etva->(:,*1,:,:)*$etvr->(:,:,:,*1))->mv(2,1)->sumover;
ok(Cagree($etvar,$ea*$eb*identity(2), 1e-3), "Keller");