=head1 COPYRIGHT NOTICE

Photonic - A perl package for calculations on photonics and
metamaterials.

Copyright (C) 2016 by W. Luis Mochán

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 1, or (at your option)
any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA  02110-1301 USA

    mochan@fis.unam.mx

    Instituto de Ciencias Físicas, UNAM
    Apartado Postal 48-3
    62251 Cuernavaca, Morelos
    México

=cut

use strict;
use warnings;
use PDL;
use PDL::Complex;
use Photonic::Geometry::FromEpsilon;
use Photonic::LE::NP::AllH;

use Test::More;
use lib 't/lib';
use TestUtils;

my $fn = make_fn();
make_default_store($fn);

#Check haydock coefficients for simple 1D system
my ($ea, $eb)=(1+2*i, 3+4*i);
my $f=6/11;
my $eps=r2C($ea*(zeroes(11)->xvals<5)+ $eb*(zeroes(11)->xvals>=5));
my $g=Photonic::Geometry::FromEpsilon
    ->new(epsilon=>$eps, Direction0=>pdl([1]));
my $a=Photonic::LE::NP::AllH->new(geometry=>$g, nh=>10);
$a->run;
my $as=pdl($a->as)->cplx;
my $bs=pdl($a->bs)->cplx;
my $b2s=pdl($a->b2s)->cplx;
is($a->iteration, 2, "Number of iterations 1D longitudinal");
ok(Cagree($b2s->slice(",(0)"), r2C(1)), "1D L b_0^2");
ok(Cagree($as, pdl([$ea*(1-$f)+$eb*$f, $ea*$f+$eb*(1-$f)])->cplx), "1D L a");
ok(Cagree($b2s->slice(",(1)"), ($eb-$ea)**2*$f*(1-$f)), "1D L b_1^2");
ok(Cagree($b2s, $bs**2), "1D L b2==b^2");

#View 1D system as 2D. Transverse direction
my $epst=r2C($ea*(zeroes(1,11)->xvals<5)+ $eb*(zeroes(1,11)->xvals>=5));
my $gt=Photonic::Geometry::FromEpsilon
   ->new(epsilon=>$epst, Direction0=>pdl([1,0])); #trans
my $at=Photonic::LE::NP::AllH->new(geometry=>$gt, nh=>10);
$at->run;
my $ast=pdl($a->as)->cplx;
my $bst=pdl($a->bs)->cplx;
my $b2st=pdl($a->b2s)->cplx;
is($at->iteration, 1, "Number of iterations 1D trans");
ok(Cagree($b2st->slice(",(0)"), 1), "1D T b_0^2");
ok(Cagree($ast->slice(",(0)"), $ea*(1-$f)+$eb*$f), "1D T a_0");
ok(Cagree($b2st, $bst**2), "1D L b2==b^2");

{
    #check reorthogonalize with square array
    my $epss=$eb*(zeroes(15,15)->rvals<5)+$ea*(zeroes(15,15)->rvals>=5);
    my $gs=Photonic::Geometry::FromEpsilon
	->new(epsilon=>$epss, Direction0=>pdl([1,0]));
    my $als=Photonic::LE::NP::AllH
	->new(geometry=>$gs, nh=>2*15*15, reorthogonalize=>1,
	      accuracy=>machine_epsilon(), noise=>3*machine_epsilon(),
	      normOp=>$eb->Cabs);
    $als->run;
    ok($als->iteration <= 15*15,
              "No more iterations than dimensions. Square. States in mem.");
    diag("Actual iterations: " .$als->iteration
	 . " Actual orthogonalizations: " . $als->orthogonalizations);
}
{
    #check reorthogonalize with square array. Data in file
    my $epss=$eb*(zeroes(15,15)->rvals<5)+$ea*(zeroes(15,15)->rvals>=5);
    my $gs=Photonic::Geometry::FromEpsilon
	->new(epsilon=>$epss, Direction0=>pdl([1,0]));
    my $als=Photonic::LE::NP::AllH
	->new(geometry=>$gs, nh=>2*15*15, reorthogonalize=>1,
	      accuracy=>machine_epsilon(), noise=>3*machine_epsilon(),
	      normOp=>$eb->Cabs, stateFN=>$fn);
    $als->run;
    ok($als->iteration <= 15*15,
       "No more iterations than dimensions. Square. States in mem.");
    diag("Actual iterations: " .$als->iteration
	 . " Actual orthogonalizations: " . $als->orthogonalizations);
}

done_testing;
