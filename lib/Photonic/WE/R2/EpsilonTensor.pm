=head1 NAME

Photonic::WE::R2::EpsilonTensor

=head1 VERSION

version 0.011

=head1 SYNOPSIS

   use Photonic::WE::R2::EpsilonTensor;
   my $epsT=Photonic::WE::R2::EpsilonTensor->new(metric=>$m, nh=>$nh);
   my $EpsTensor=$W->evaluate($epsB);

=head1 DESCRIPTION

Calculates the macroscopic dielectric tensor for a given fixed
Photonic::WE::R2::Metric structure as a function of the dielectric
functions of the components.

=head1 METHODS

=over 4

=item * new(metric=>$m, nh=>$nh, smallE=>$smallE, smallH=>$smallH,
keepStates=>$k)  

Initializes the structure.

$m Photonic::WE::R2::Metric describing the structure and some parametres.

$nh is the maximum number of Haydock coefficients to use.

$smallH and $smallE are the criteria of convergence (default 1e-7) for
Haydock coefficients and for the continued fraction. From
Photonic::Roles::EpsParams.  

$k is a flag to keep states in Haydock calculations (default 0)

=item * evaluate($epsB)

Returns the macroscopic dielectric tensor for a given value of the
dielectric function of the particle $epsB. The host's
response $epsA is taken from the metric.  

=back

=head1 ACCESORS (read only)

=over 4

=item * epsilonTensor

The macroscopic dielectric tensor of the last operation

=item * All accesors of Photonic::WE::R2::Wave


=back

=cut

package Photonic::WE::R2::EpsilonTensor;
$Photonic::WE::R2::EpsilonTensor::VERSION = '0.011';
use namespace::autoclean;
use PDL::Lite;
use PDL::NiceSlice;
use PDL::Complex;
use PDL::MatrixOps;
use Storable qw(dclone);
use PDL::IO::Storable;
#use Photonic::WE::R2::AllH;
use Photonic::Types;
use Moose;
use MooseX::StrictConstructor;

extends 'Photonic::WE::R2::Wave'; 

has 'epsilonTensor' =>  (is=>'ro', isa=>'PDL::Complex', init_arg=>undef,
             writer=>'_epsilonTensor',   
             documentation=>'Wave operator from last evaluation');

around 'evaluate' => sub {
    my $orig=shift;
    my $self=shift;
    my $wave=$self->$orig(@_);
    my $q=$self->metric->wavenumber;
    my $q2=$q*$q;
    my $k=$self->metric->wavevector;
    my $k2=$k->inner($k);
    my $kk=$k->outer($k);
    my $id=identity($k);
    my $eps=$wave+$k2/$q2*$id - $kk/$q2;
    $self->_epsilonTensor($eps);
    return $eps;
};

__PACKAGE__->meta->make_immutable;
    
1;

__END__
