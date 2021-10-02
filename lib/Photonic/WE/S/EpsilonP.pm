package Photonic::WE::S::EpsilonP;
$Photonic::WE::S::EpsilonP::VERSION = '0.021';

=encoding UTF-8

=head1 NAME

Photonic::WE::S::EpsilonP

=head1 VERSION

version 0.021

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

   use Photonic::WE::S::EpsilonP;
   my $eps=Photonic::WE::S::EpsilonP->new(haydock=>$h, nh=>$nh);
   my $EpsTensor=$W->epsilon;

=head1 DESCRIPTION

Calculates the macroscopic dielectric tensor component for a given fixed
Photonic::WE::S::Haydock structure as a function of the dielectric
functions of the components.

NOTE: Only works for polarizations along principal directions.

=head1 METHODS

=over 4

=item * new(haydock=>$h, nh=>$nh, smallE=>$smallE)

Initializes the structure.

$h Photonic::WE::S::Haydock describing the structure and some parametres.

$nh is the maximum number of Haydock coefficients to use.

$smallE is the criterium of convergence (default 1e-7) for
Haydock coefficients and for the continued fraction.

$k is a flag to keep states in Haydock calculations (default 0)

=back

=head1 ACCESSORS (read only)

=over 4

=item * epsilon

The macroscopic dielectric projection

NOTE: Only works along principal directions.

=item * All accessors of Photonic::WE::S::WaveP

=back

=cut

use namespace::autoclean;
use PDL::Lite;
use Photonic::Types;
use Moose;
use MooseX::StrictConstructor;

extends 'Photonic::WE::S::WaveP';

has 'epsilon' =>  (is=>'ro', isa=>'Photonic::Types::PDLComplex', init_arg=>undef,
		   lazy=>1, builder=>'_build_epsilon',
		   documentation=>'Projected dielectric function');

sub _build_epsilon {
    my $self=shift;
    my $wave=$self->waveOperator;
    my $q=$self->haydock->metric->wavenumber;
    my $q2=$q*$q;
    my $k=$self->haydock->metric->wavevector;
    my $k2=($k*$k)->sumover; #inner. my $k2=$k->inner($k); only works on real
    my $p=$self->haydock->normalizedPolarization;
    #Note $p->inner($p) might be complex, so is not necessarily 1.
    my $p2=($p*$p)->sumover;
    my $pk=($p*$k)->sumover;
    my $proj=$p2*$k2/$q2 - $pk*$pk/$q2;
    my $eps=$wave+$proj;
    return $eps;
};

__PACKAGE__->meta->make_immutable;

1;

__END__
