=head1 NAME

Photonic::NonRetarded::SHChiTensor

=head1 VERSION

version 0.007

=head1 SYNOPSIS

   use Photonic::NonRetarded::SHChiTensor;
   my $chi=Photonic::NonRetarded::SHChiTensor->new(geometry=>$g,
           $densityA=>$dA, $densityB=>$dB, nh=>$nh, nhf=>$nhf,
           filter=>$f, filterflag=>$ff); 
   my $chiTensor=$chi->evaluate($epsA1, $epsB1, $epsA2, $epsB2);

=head1 DESCRIPTION

Calculates the second harmonic susceptibility tensor for a given fixed
Photonic::Geometry structure as a function of the dielectric
functions of the components.

=head1 METHODS

=over 4

=item * new(geometry=>$g, densityA=>$da, densityB=>$db, nh=>$nh, nhf=>$nhf[, filter=>$ff][, smallH=>$smallH][, smallE=>$smallE])

Initializes the structure.

$g Photonic::Geometry describing the structure

$da, $db number densities for material A and B (in which units?)

$nh is the maximum number of Haydock coefficients to use.

$nhf is the maximum number of Haydock coefficients for the field calculation. 

$ff is a (maybe smooth) cutoff function in reciprocal space to smothen the geometry. 

$smallH and $smallE are the criteria of convergence (default 1e-7) for
haydock coefficients and continued fraction. From Photonic::Roles::EpsParams.

=item * evaluate($epsA1, $epsB1, $epsA2, $epsB2)

Returns the macroscopic second Harmonic susceptibility function for a
given value of the dielectric functions of the host $epsA and the
=particle $epsB at the fundamental 1 and second harmonic 2 frequency. 

=back

=head1 ACCESORS (read only)

=over 4

=item * epsA1, epsB1, epsA2, epsB2

Dielectric functions of components A and B at fundamental and SH frequency

=item * nrshp

Array of Photonic::NonRetarded::SHP Haydock SH polarization calculators,
one for each direction

=item * chiTensor

The dielectric tensor

=item * nh

The maximum number of Haydock coefficients to use.

=item * nhActual

The actual number of Haydock coefficients used in the last calculation

=item * converged

Flags that the last calculation converged before using up all coefficients

=item * smallH smallE

Criteria of convergence for Haydock coefficients and for fields. 0
means don't check. 

=back

=head1 ACCESORS (missing)

=over 4

=item * u1, u2 

Spectral variables

=back

=cut

package Photonic::NonRetarded::SHChiTensor;
$Photonic::NonRetarded::SHChiTensor::VERSION = '0.007';
use namespace::autoclean;
use PDL::Lite;
use PDL::NiceSlice;
use PDL::Complex;
use PDL::MatrixOps;
use Storable qw(dclone);
use PDL::IO::Storable;
use Moose;
use Photonic::Types;
with 'Photonic::Roles::EpsParams';

#required parameters
has 'geometry'=>(is=>'ro', isa => 'Photonic::Geometry',
    handles=>[qw(B dims r G GNorm L scale f)],required=>1
);
has 'densityA'=>(is=>'ro', isa=>'Num', required=>1,
         documentation=>'Normalized dipole entities density in medium A');
has 'densityB'=>(is=>'ro', isa=>'Num', required=>1,
         documentation=>'Normalized dipole entities density in medium B');
has 'nhf'=>(is=>'ro', required=>1, 
         documentation=>'Maximum number of desired Haydock
                         coefficients for field calculation');
#optional parameters 
has 'filter'=>(is=>'ro', isa=>'PDL', predicate=>'has_filter',
               documentation=>'Optional reciprocal space filter');

#accesors
has 'epsA1'=>(is=>'ro', isa=>'PDL::Complex', init_arg=>undef, writer=>'_epsA1',
    documentation=>'Dielectric function of host');
has 'epsB1'=>(is=>'ro', isa=>'PDL::Complex', init_arg=>undef, writer=>'_epsB1',
        documentation=>'Dielectric function of inclusions');
has 'epsA2'=>(is=>'ro', isa=>'PDL::Complex', init_arg=>undef, writer=>'_epsA2',
    documentation=>'Dielectric function of host');
has 'epsB2'=>(is=>'ro', isa=>'PDL::Complex', init_arg=>undef, writer=>'_epsB2',
        documentation=>'Dielectric function of inclusions');
has 'nrshp' =>(is=>'ro', isa=>'ArrayRef[Photonic::NonRetarded::SHP]',
            init_arg=>undef, lazy=>1, builder=>'_build_nrshp',
            documentation=>'Array of Haydock SH polarization calculators');
has 'chiTensor'=>(is=>'ro', isa=>'PDL', init_arg=>undef, writer=>'_chiTensor', 
             documentation=>'SH Susceptibility from last evaluation');


sub evaluate {
    my $self=shift;
    $self->_epsA1(my $epsA1=shift);
    $self->_epsB1(my $epsB1=shift);
    $self->_epsA2(my $epsA2=shift);
    $self->_epsB2(my $epsB2=shift);
    my @P2M; #array of longitudinal polarizations along different directions.
    foreach(@{$self->nrshp}){
	my $nrsh=Photonic::NonRetarded::SH->new(
	    shp=>$_, epsA1=>$epsA1, epsB1=>$epsB1, epsA2=>$epsA2,
	    epsB2=>$epsB2);
	# RorI, XorY,nx,ny
	my $P2=$nrsh->P2;
#	my $P2=$nrsh->dipolar;
#	my $P2=$nrsh->external;
	my $P2M=$P2->mv(0,-1)->mv(0,-1)
	    ->clump(-3) #linear index, RorI, XorY
	    ->mv(-2,0) #RorI, index, XorY
	    ->complex->sumover  #RorI, XorY
	    /$self->geometry->npoints;
	push @P2M, $P2M;
    }
    #NOTE. Maybe I have to correct response to D-> response to E
    #I have to convert from the array of polarizations for given
    #directions to the actual cartesian chi's. 
    #$reP2M and $imP2M have cartesian, dyad indices
    my $reP2M=PDL->pdl([map {$_->re} @P2M]);
    my $imP2M=PDL->pdl([map {$_->im} @P2M]);
    my ($lu, $perm, $parity)=@{$self->geometry->unitDyadsLU};
    #$reChi, $imChi have cartesian, dyad indices
    #Get cartesian indices out of the way, solve the system of
    #equations, and move the cartesian indices back
    my $reChi=lu_backsub($lu, $perm, $parity, $reP2M->mv(0,-1))->mv(-1,0);
    my $imChi=lu_backsub($lu, $perm, $parity, $imP2M->mv(0,-1))->mv(-1,0);
    my $nd=$self->geometry->B->ndims;
    #chi has three cartesian indices
    my $chiTensor=PDL->zeroes(2, $nd, $nd, $nd)->complex;
    #convert dyadic to cartesian indices
    my $n=0;
    for my $i(0..$nd-1){
	for my $j($i..$nd-1){
	    $chiTensor->(:,:,($i),($j)).=$reChi(:,$n)+i*$imChi(:,$n);
	    $chiTensor->(:,:,($j),($i)).=$reChi(:,$n)+i*$imChi(:,$n);
	    ++$n;
	}
    }
    $self->_chiTensor($chiTensor);
    return $chiTensor;
}

#Need geometry, maximum number of Haydock coefficients for NonRetarded::ALL nh, número de
#haydock para el comp nhf
sub _build_nrshp { # One Haydock coefficients calculator per direction0
    my $self=shift;
    my @nrshp;
    foreach(@{$self->geometry->unitPairs}){
	my $g=dclone($self->geometry); #clone geometry
	#OJO: Cuánto vale el campo macroscópico? Hay que normalizar esto?
	$g->Direction0($_); #add G0 direction
	#Build a corresponding NonRetarded::AllH structure
	my $nr=Photonic::NonRetarded::AllH->new(nh=>$self->nh, geometry=>$g,
				keepStates=>1, smallH=>$self->smallH);  
	my $nrf=Photonic::NonRetarded::FieldH->new(nr=>$nr, nh=>$self->nhf, 
					smallE=>$self->smallE);
	my $nrshp=Photonic::NonRetarded::SHP->
	    new(nrf=>$nrf, densityA=>$self->densityA, 
		densityB=>$self->densityB); 
	push @nrshp, $nrshp;
    }
    return [@nrshp]
}


__PACKAGE__->meta->make_immutable;
    
1;

__END__
