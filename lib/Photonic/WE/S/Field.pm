package Photonic::WE::S::Field;
$Photonic::WE::S::Field::VERSION = '0.018';

=encoding UTF-8

=head1 NAME

Photonic::WE::S::Field

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

   use Photonic::WE::S::Field;
   my $nrf=Photonic::WE::S::Field->new(...);
   my $field=$nrf->evaluate($epsA, $epsB);

=head1 DESCRIPTION

Calculates the non retarded electric field for a given fixed
Photonic::Geometry structure and given dielectric functions of
the components.

=head1 METHODS

=over 4

=item * new(haydock=>$haydock, nh=>$nh, smallE=>$smallE)

Initializes the structure.

$haydock Photonic::WE::S::Haydock is a Haydock calculator for the
structure, *initialized* with the flag keepStates=>1
(Photonic::Types::HaydockSave, as defined in Photonic::Types).

$nh is the maximum number of Haydock coefficients to use.

$smallE is the criteria of convergence (default 1e-7) for
Field calculations

=item * evaluate($epsA, $epsB...)

Returns the microscopic electric field for given
dielectric functions of the host $epsA and the particle $epsB.

=back

=head1 ACCESSORS (read only)

=over 4

=item * haydock

Photonic::WE::S::Haydock structure

=item * nh

Maximum number of Haydock coefficients to use.

=item * smallE

Criteria of convergence. 0 means don't check.

=item * epsA

Dielectric function of component A

=item * epsB

Dielectric function of componente B

=item * u

Spectral variable

=item * Es

Array of field coefficients

=item * filter

optional reciprocal space filter

=item * field

real space field in format cartesian, nx, ny,...

=item * epsL

Longitudinal dielectric response, obtained colaterally from last
evaluation of the field

=back

=begin Pod::Coverage

=head2 BUILD

=end Pod::Coverage

=cut



use namespace::autoclean;
use PDL::Lite;
use PDL::NiceSlice;
use Photonic::WE::S::Haydock;
use Photonic::Utils qw(cgtsv GtoR);
use Photonic::Types;
use Photonic::Iterator;
use Moose;
use MooseX::StrictConstructor;

has 'haydock'=>(is=>'ro', isa=>'Photonic::Types::HaydockSave', required=>1,
           documentation=>'Haydock recursion calculator');
has 'Es'=>(is=>'ro', isa=>'ArrayRef[Photonic::Types::PDLComplex]', init_arg=>undef,
           writer=>'_Es', documentation=>'Field coefficients');
has 'filter'=>(is=>'ro', isa=>'PDL', predicate=>'has_filter',
               documentation=>'Optional reciprocal space filter');
has 'field'=>(is=>'ro', isa=>'Photonic::Types::PDLComplex', init_arg=>undef,
           writer=>'_field', documentation=>'Calculated real space field');
has 'nh' =>(is=>'ro', isa=>'Num', required=>1,
	    documentation=>'Desired no. of Haydock coefficients');
has 'smallH'=>(is=>'ro', isa=>'Num', required=>1, default=>1e-7,
    	    documentation=>'Convergence criterium for Haydock coefficients');
has 'smallE'=>(is=>'ro', isa=>'Num', required=>1, default=>1e-7,
    	    documentation=>'Convergence criterium for use of Haydock coeff.');
#has 'epsA'=>(is=>'ro', isa=>'Photonic::Types::PDLComplex', init_arg=>undef, writer=>'_epsA',
#    documentation=>'Dielectric function of host');
#has 'epsB'=>(is=>'ro', isa=>'Photonic::Types::PDLComplex', init_arg=>undef, writer=>'_epsB',
#        documentation=>'Dielectric function of inclusions');
#has 'u'=>(is=>'ro', isa=>'Photonic::Types::PDLComplex', init_arg=>undef, writer=>'_u',
#    documentation=>'Spectral variable');

sub BUILD {
    my $self=shift;
    $self->haydock->run unless $self->haydock->iteration;
}

sub evaluate {
    my $self=shift;
    my $as=$self->haydock->as;
    my $bs=$self->haydock->bs;
    my $cs=$self->haydock->cs;
    my $stateit=$self->haydock->state_iterator;
    my $nh=$self->nh; #desired number of Haydock terms
    #don't go beyond available values.
    $nh=$self->haydock->iteration if $nh>$self->haydock->iteration;
    # calculate using lapack for tridiag system
    my $diag = 1-$as->(0:$nh-1);
    # rotate complex zero from first to last element.
    my $subdiag = -$bs->(0:$nh-1)->rotate(-1);
    my $supradiag =-$cs->(0:$nh-1)->rotate(-1);
    my $rhs=PDL->zeroes($nh); #build a nh pdl
    $rhs->slice((0)).=1;
    $rhs=$rhs->r2C;
    #coefficients of g^{-1}E
    my $giEs= cgtsv($subdiag, $diag, $supradiag, $rhs);
    #states are xy,pm,nx,ny...
    my @dims=$self->haydock->B->dims; # actual dims of space
    my $ndims=@dims; # num. of dims of space
    #field is xy,pm,nx,ny...
    my $field_G=PDL->zeroes($ndims, 2, @dims)->r2C;
    #print $field_G->info, "\n";
    #field is xy,pm,nx,ny...
    for(my $n=0; $n<$nh; ++$n){
	my $giE_G=$giEs->($n)*$stateit->nextval; #En ^G|psi_n>
	$field_G+=$giE_G;
    }
    #
    my $Es=$self->haydock->applyMetric($field_G);
    #Comment as normalization below makes it useless
    #$Es*=$bs->((0))/$self->haydock->metric->epsilon;
    my $Esp=$Es(:,(0)); # choose +k spinor component.
    my $e_0=1/($Esp->slice(":" . ",(0)" x $ndims)
	       *$self->haydock->polarization->conj)->sumover;
    # Normalize result so macroscopic field is 1.
    $Esp*=$e_0;
    $Esp *= $self->filter->(*1) if $self->has_filter;
    ##get cartesian out of the way, fourier transform, put cartesian.
    my $field_R=GtoR($Esp, $ndims, 1);
    $field_R*=$self->haydock->B->nelem; #scale to have unit macroscopic field
    #result is xy,nx,ny...
    $self->_field($field_R);
    return $field_R;
}

__PACKAGE__->meta->make_immutable;

1;
