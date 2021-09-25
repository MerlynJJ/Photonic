package Photonic::LE::NR2::SH;
$Photonic::LE::NR2::SH::VERSION = '0.018';

=encoding UTF-8

=head1 NAME

Photonic::LE::NR2::SH

=head1 VERSION

version 0.018

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

=head1 SYNOPSIS

   use Photonic::LE::NR2::SH;
   my $nrsh=Photonic::LE::NR2::SH->new(shp=>$shp, epsA1=>$epsA1, epsB1=>$epsB1,
-                 epsA2=>$epsA2, epsB2=>$epsB2);
   my $PL_G=$nrsh->selfConsistentL_G;


=head1 DESCRIPTION

Calculates the non retarded SH polarizations and fields of arbitrary a
periodic composite made up of centrosymmetric isotropic component materials,
using the continuous dipolium model.

=head1 METHODS

=over 4

item * new(shp=>$shp, epsA1=>$epsA1, epsB1=>$epsB1, epsA2=>$epsA2,
             epsB2=>epsB2);

Initializes the structure

$shp is a Photonic::LE::NR2::SHP object with the invariant part of
the data structures for the calculations

$epsA1, $epsB1, $epsA2, $epsB2 are the dielectric functions of the A
-and B materials at the fundamental and the second harmonic frequency


=back

=head1 ACCESSORS (read only)

=over 4

=item * shp

Invariant part of SHG calculator.

=item * ndims nrf densityA densityB density haydock

Accessors handled by shp

=item * epsA1, epsB1

Dielectric functions of materials A and B at the fundamental frequency

=item * epsA2, epsB2

Dielectric functions of materials A and B at the second harmonic frequency

=item * alpha1

Polarizabity field at the fundamental frequency

=item * alpha2

Polarizabity field at the second harmonic frequency

=item * u1

Spectral variable at fundamental frequency

=item * u2

Spectral variable at second harmonic frequency

=item * field1

longitudinal field at fundamental

=item * field2

longitudinal field at second harmonic

=item * dipolar

Dipolar contribution to SH polarization field

=item * quadrupolar

SH quadrupolar contribution to SH polarization field

=item * external

External contribution to SH polarization field (quadrupolar + dipolar)

=item * external_G

External SH polarization field in reciprocal space

=item * externalL_G

Longitudinal projection of external polarization field in reciprocal space

=item * HP

Photonic::LE::NR2::Haydock structure to calculate Haydock basis for
non linear polarization

=item * externalL_n

External SH polarization field represented in Haydock basis

=item * selfConsistentL_n

SH self consistent longitudinal polarization in Haydock representation

=item * selfConsistentL_G

SH self consistent longitudinal polarization components in reciprocal
space

=item * selfConsistentVecL_G

SH self consistent longitudinal polarization vector field projection in
reciprocal space

=item * selfConsistentVecL

SH self consistent longitudinal polarization vector projection field
in real space

=item * P2

SH self consistent total polarization vector field in real space

=back

=head1 ACCESSORS (read/write)

=over 4

=item * filterflag

Flag to filter results in reciprocal space to smooth non linear
polarization using the field (nrf) filter.

=back

=begin Pod::Coverage

=head2 BUILD

=end Pod::Coverage

=cut

use namespace::autoclean;
use PDL::Lite;
use PDL::NiceSlice;
use Photonic::LE::NR2::Haydock;
use Photonic::Utils qw(RtoG GtoR HProd linearCombineIt any_complex cgtsv);
use Photonic::Iterator;
use Photonic::Types;
use PDL::Constants qw(PI);
use Moose;
use MooseX::StrictConstructor;

has 'shp'=>(is=>'ro', 'isa'=>'Photonic::LE::NR2::SHP', required=>1,
    handles=>[qw(ndims nrf densityA densityB density haydock)],
    documentation=>'Object with invariant part of SHG calculation');
has 'epsA1'=>(is=>'ro', isa=>'Photonic::Types::PDLComplex', required=>1,
    documentation=>'Fundamental dielectric function of host');
has 'epsB1'=>(is=>'ro', isa=>'Photonic::Types::PDLComplex',
        documentation=>'Fundamental dielectric function of inclusions');
has 'epsA2'=>(is=>'ro', isa=>'Photonic::Types::PDLComplex', required=>1,
    documentation=>'SH Dielectric function of host');
has 'epsB2'=>(is=>'ro', isa=>'Photonic::Types::PDLComplex', required=>1,
        documentation=>'SH Dielectric function of inclusions');
has 'alpha1'=>(is=>'ro', isa=>'Photonic::Types::PDLComplex', init_arg=>undef,
         lazy=>1, builder=>'_build_alpha1',
         documentation=>'Linear "atomic" polarizability');
has 'alpha2'=>(is=>'ro', isa=>'Photonic::Types::PDLComplex', init_arg=>undef,
         lazy=>1, builder=>'_build_alpha2',
         documentation=>'SH linear "atomic" polarizability');
has 'u1'=>(is=>'ro', isa=>'Photonic::Types::PDLComplex', init_arg=>undef,
         lazy=>1, builder=>'_build_u1',
         documentation=>'Spectral variable at fundamental');
has 'u2'=>(is=>'ro', isa=>'Photonic::Types::PDLComplex', init_arg=>undef,
         lazy=>1, builder=>'_build_u2',
         documentation=>'Spectral variable at SH');
has 'field1'=>(is=>'ro', isa=>'Photonic::Types::PDLComplex', init_arg=>undef,
         lazy=>1, builder=>'_build_field1',
         documentation=>'longitudinal field at fundamental');
has 'field2'=>(is=>'ro', isa=>'Photonic::Types::PDLComplex', init_arg=>undef,
         lazy=>1, builder=>'_build_field2',
         documentation=>'longitudinal field at second harmonic');
has 'epsL2'=>(is=>'ro', isa=>'Photonic::Types::PDLComplex', init_arg=>undef,
         writer=>'_epsL2', predicate=>'has_epsL2',
         documentation=>'longitudinal dielectric function at 2w');
has 'dipolar'=>(is=>'ro', isa=>'Photonic::Types::PDLComplex', init_arg=>undef,
         lazy=>1, builder=>'_build_dipolar',
         documentation=>'SH dipolar contribution to SH polarization');
has 'quadrupolar'=>(is=>'ro', isa=>'Photonic::Types::PDLComplex', init_arg=>undef,
         lazy=>1, builder=>'_build_quadrupolar',
         documentation=>'SH quadrupolar contribution to SH polarization');
has 'external'=>(is=>'ro', isa=>'Photonic::Types::PDLComplex', init_arg=>undef,
         lazy=>1, builder=>'_build_external',
         documentation=>'SH external contribution to SH polarization');
has 'external_G'=>(is=>'ro', isa=>'Photonic::Types::PDLComplex', init_arg=>undef,
         lazy=>1, builder=>'_build_external_G',
         documentation=>'SH ext. polarization in reciprocal space');
has 'externalL_G'=>(is=>'ro', isa=>'Photonic::Types::PDLComplex', init_arg=>undef,
         lazy=>1, builder=>'_build_externalL_G',
         documentation=>
             'SH ext. longitudinal polarization comp. in reciprocal space');
has 'externalVecL_G'=>(is=>'ro', isa=>'Photonic::Types::PDLComplex', init_arg=>undef,
         lazy=>1, builder=>'_build_externalVecL_G',
         documentation=>
             'SH ext. longitudinal polarization proj. in recip. space');
has 'externalVecL'=>(is=>'ro', isa=>'Photonic::Types::PDLComplex', init_arg=>undef,
         lazy=>1, builder=>'_build_externalVecL',
         documentation=>
             'SH ext. longitudinal polarization proj. in real space');
has 'HP' =>(is=>'ro', isa=>'Photonic::LE::NR2::Haydock', init_arg=>undef,
         lazy=>1, builder=>'_build_HP',
         documentation=>
         'Structure to calculate Haydock basis for non linear polarization');
has 'externalL_n'=>(is=>'ro', isa=>'Photonic::Types::PDLComplex', init_arg=>undef,
         lazy=>1, builder=>'_build_externalL_n',
         documentation=>
             'SH ext. longitudinal polarization in Haydock
               representation');
has 'selfConsistentL_n'=>(is=>'ro', isa=>'Photonic::Types::PDLComplex',
         init_arg=>undef, lazy=>1,
         builder=>'_build_selfConsistentL_n',
         documentation=>
             'SH self consistent longitudinal polarization
              in Haydock representation');
has 'selfConsistentL_G'=>(is=>'ro', isa=>'Photonic::Types::PDLComplex',
         init_arg=>undef, lazy=>1,
         builder=>'_build_selfConsistentL_G',
         documentation=>
             'SH self consistent longitudinal polarization components in
               reciprocal space');
has 'selfConsistentVecL_G'=>(is=>'ro', isa=>'Photonic::Types::PDLComplex',
         init_arg=>undef, lazy=>1,
         builder=>'_build_selfConsistentVecL_G',
         documentation=>
             'SH self consistent longitudinal polarization vector
              field in reciprocal space');
has 'selfConsistentVecL'=>(is=>'ro', isa=>'Photonic::Types::PDLComplex',
         init_arg=>undef, lazy=>1,
         builder=>'_build_selfConsistentVecL',
         documentation=>
             'SH self consistent longitudinal polarization vector
              field in real space');
has 'P2'=>(is=>'ro', isa=>'Photonic::Types::PDLComplex',
         init_arg=>undef, lazy=>1,
         builder=>'_build_P2',
         documentation=>
             'SH self consistent total polarization vector
              field in real space');

has 'P2LMCalt'=>(is=>'ro', isa=>'Photonic::Types::PDLComplex',
         init_arg=>undef, lazy=>1,
         builder=>'_build_P2LMCalt',
         documentation=>
             'SH self consistent total macroscopic polarization
              in real space. Alternative');

has 'filterflag'=>(is=>'rw',
         documentation=>'Filter results in reciprocal space');

sub _alpha {
    my $self=shift;
    my $epsA=shift;
    my $epsB=shift;
    my $alphaA=my $alphaB=PDL::r2C(0);
    $alphaA=($epsA-1)/(4*$self->densityA*PI) unless
	$self->densityA==0;
    $alphaB=($epsB-1)/(4*$self->densityB*PI) unless
	$self->densityB==0;
    $alphaA=$alphaB if $self->densityA==0;
    $alphaB=$alphaA if $self->densityB==0;
    my $B=$self->nrf->haydock->B;
    $alphaA*(1-$B)+$B*$alphaB;
}

sub _build_alpha1 {
    my $self=shift;
    $self->_alpha($self->epsA1,$self->epsB1);
}

sub _build_alpha2 {
    my $self=shift;
    $self->_alpha($self->epsA2,$self->epsB2);
}


sub _build_field1 {
    my $self=shift;
    $self->nrf->evaluate($self->epsA1, $self->epsB1);
}

sub _build_field2 {
    my $self=shift;
    $self->nrf->evaluate($self->epsA2, $self->epsB2);
    $self->_epsL2($self->nrf->epsL);
}

sub _build_dipolar {
    my $self=shift;
    my $field=$self->field1;
    die "Expected complex \$field" unless any_complex($field);
    my $ndims=$self->ndims;
    #E^2 Square each complex component and sum over components
    my $Esquare_R=($field*$field)->sumover; #result is nx, ny...
    #Fourier transform
    my $Esquare_G=RtoG($Esquare_R, $ndims, 0); # nx ny...
    my $G=$self->nrf->haydock->G; #cartesian, nx, ny...
    my $iG=i2C $G; #cartesian nx ny
    my $iGE2=$iG*$Esquare_G->(*1); #cartesian nx ny...
    #back to real space. Get cartesian out of the way and then back
    my $nablaE2=GtoR($iGE2, $ndims, 1); #cartesian, nx, ny...
    my $factor=-$self->density*$self->alpha1*$self->alpha2/2; #nx, ny...
    my $P=$factor->(*1)*$nablaE2;
    #Should I filter in Fourier space before returning?
    return $P;
}

sub _build_quadrupolar {
    my $self=shift;
    my $field=$self->field1;
    my $ndims=$self->ndims; #dims of space
    #E E tensor
    my $EE_R=$field->(*1)*$field->(,*1); #result is cartesian, cartesian, nx, ny... - use dummies for external product
    my $naa=$self->density*$self->alpha1*$self->alpha1/2; #nx, ny...
    my $naaEE_R=$naa->(*1,*1)*$EE_R; #cartesian cartesian nx ny...
    my $naaEE_G=RtoG($naaEE_R, $ndims, 2); # cartesian cartesian nx ny...
    my $G=$self->nrf->haydock->G; #cartesian, nx, ny...
    my $iG=i2C $G; #cartesian nx ny...
    my $iGnaaEE_G=($iG->(,*1)*$naaEE_G)->sumover; #dot - cartesian nx ny...
    $iGnaaEE_G *= $self->nrf->filter->(*1) if $self->nrf->has_filter; # nx ny...
    #back to real space. Get cartesian out of the way and then back
    GtoR($iGnaaEE_G, $ndims, 1); #cartesian, nx, ny...
}

sub _build_external {
    my $self=shift;
    $self->dipolar+$self->quadrupolar;
}

sub _build_external_G {
    my $self=shift;
    my $filterflag=$self->filterflag;
    $self->filterflag(0);
    my $result=RtoG($self->external, $self->ndims, 1); # RoI cartesian nx ny...
    $self->filterflag($filterflag);
    $result=$self->_filter($result,1) if $filterflag;
    return $result;
}

sub _build_externalL_G {
    my $self=shift;
    my $filterflag=$self->filterflag;
    $self->filterflag(0);
    my $result=$self->nrf->haydock->geometry->Vec2LC_G($self->external_G); # RoI cartesian nx ny...
    $self->filterflag($filterflag);
    $result=$self->_filter($result,0) if $filterflag;
    return $result;
}

sub _build_externalVecL_G {
    my $self=shift;
    $self->nrf->haydock->geometry->LC2Vec_G($self->externalL_G);
}

sub _build_externalVecL {
    my $self=shift;
    GtoR($self->externalVecL_G, $self->ndims, 1);
}

sub _build_HP { #build haydock states for P2
    my $self=shift;
    my $ext=$self->externalL_G;
    my $normext=sqrt(PDL::abs2($ext)->sum);
    my $extnorm=$ext/$normext;
    my $hp=Photonic::LE::NR2::Haydock->new(nh=>$self->nrf->nh,
	geometry=>$self->nrf->haydock->geometry, smallH=>$self->nrf->haydock->smallH,
		keepStates=>1, firstState=>$extnorm);
    $hp->run;
    return $hp;
}

sub _build_externalL_n {
    my $self=shift;
    my $pol=$self->externalL_G;
    my $stateit=$self->HP->state_iterator;
    my $nh=$self->HP->iteration;
    # innecesario: \propto \delta_{n0}
    my $Pn=PDL::r2C(PDL->zeroes($nh));
    $Pn->((0)).=HProd($stateit->nextval,$pol);
    $Pn;
}

sub _build_selfConsistentL_n {
    my $self=shift;
    my $external=$self->externalL_n;
    my $nh=$self->HP->iteration;
    my $as=$self->HP->as;
    my $bs=$self->HP->bs;
    my $u2=$self->u2;
    my $diag=$u2 - $as->(0:$nh-1);
    # rotate complex zero from first to last element.
    my $subdiag=-$bs->(0:$nh-1)->rotate(-1)->r2C;
    my $supradiag=$subdiag;
    cgtsv($subdiag, $diag, $supradiag, $external) * ($u2/$self->epsA2);
}

sub _build_selfConsistentL_G {
    my $self=shift;
    my $filterflag=$self->filterflag;
    $self->filterflag(0);
    my $PLn=$self->selfConsistentL_n;
    my $stateit=$self->HP->state_iterator;
    my $result=linearCombineIt($PLn, $stateit);
    $self->filterflag($filterflag);
    $result=$self->_filter($result,0)  if $filterflag;
    return $result;
}

sub _build_selfConsistentVecL_G {
    my $self=shift;
    $self->nrf->haydock->geometry->LC2Vec_G($self->selfConsistentL_G);
}

sub _build_selfConsistentVecL {
    my $self=shift;
    GtoR($self->selfConsistentVecL_G, $self->ndims, 1);
}

sub _build_P2 {
    my $self=shift;
    my $density=$self->density;
    my $alpha2=$self->alpha2;
    my $PL=$self->selfConsistentVecL;
    my $Pext=$self->external;
    -4*PI*($alpha2*$density)->(*1)*$PL+$Pext;
}

sub _build_P2LMCalt {
    my $self=shift;
    my $PexL_G=$self->externalL_G; #external long 2w polarization
    my $PexM=$self->external_G->(:,(0),(0)); #macroscopic external.
    my $nrf=$self->nrf;
    my $haydock=$nrf->haydock;
    my $geom=$haydock->geometry;
    my $ndims=$geom->ndims;
    my $nelem=$geom->npoints;
    my $k=$geom->Direction0;
    my $epsA2=$self->epsA2;
    my $u2=$self->u2;
    my $B=$geom->B;
    my $as=$haydock->as;
    my $bs=$haydock->bs;
    my $nh=$nrf->nh; #desired number of Haydock terms
    #don't go beyond available values.
    $nh=$haydock->iteration if $nh>=$haydock->iteration;
    # calculate using lapack for tridiag system
    # solve \epsilon^LL \vec E^L=|0>.
    my $diag=$self->u2->conj - $as->(0:$nh-1);
    # rotate complex zero from first to last element.
    my $subdiag=-$bs->(0:$nh-1)->rotate(-1)->r2C;
    my $supradiag=$subdiag->rotate(-1);
    my $rhs=PDL->zeroes($nh);
    $rhs->((0)).=1;
    $rhs=$rhs->r2C;
    my $phi_n = cgtsv($subdiag, $diag, $supradiag, $rhs);
    my $states=$haydock->state_iterator;
    my $phi_G=linearCombineIt($phi_n, $states);
    my $Pphi=$k*(1-$epsA2)*$u2/$epsA2*HProd($phi_G, $PexL_G);

    my $beta_G=RtoG($B*GtoR($haydock->firstState,$ndims,0), $ndims,0);
    my $betaV_G=$beta_G->(*1)*$geom->GNorm;
    $states=$haydock->state_iterator;
    my $betaV_n=PDL->pdl(
	[map {HProd($betaV_G,$states->nextval->(*1), 1)} (0..$nh-1)]
	);
    my $Ppsi = PDL->zeroes($ndims)->r2C;
    foreach(0..$ndims-1){
	my $psi_n = cgtsv($subdiag, $diag, $supradiag, $betaV_n->(($_))); # nx ny .... cartesian
	$states=$haydock->state_iterator;
	my $psi_G=linearCombineIt($psi_n, $states);
	$Ppsi->(($_)) .= HProd($psi_G, $PexL_G);
    }
    my $P2M=$Pphi+$Ppsi+$PexM*$nelem; # Unnormalize Pex !!
    return $P2M->(,*1,*1);
}

sub _build_u1 {
    my $self=shift;
    $self->nrf->u;
}

sub _build_u2 {
    my $self=shift;
    1/(1-$self->epsB2/$self->epsA2);
}

sub _filter { #Filter complex field in reciprocal space
    my $self=shift;
    my $field=shift;
    my $skip=shift; #dimensions to skip, 0 for scalar, 1 for vector, 2
		    #for tensor,  etc.
    return $field unless $self->nrf->has_filter;
    my $filter=$self->nrf->filter;
    $field=$field->mv(1,-1) foreach(0..$skip-1); #mv cartesian out of
                                                 #the way
    $field *=$filter;
    $field=$field->mv(-1,1) foreach(0..$skip-1); #mv cartesians back
    return $field;
}

__PACKAGE__->meta->make_immutable;

1;
