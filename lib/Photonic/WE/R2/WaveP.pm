=head1 NAME

Photonic::WE::R2::WaveP

=head1 VERSION

version 0.011

=head1 SYNOPSIS

   use Photonic::WE::R2::WaveP;
   my $W=Photonic::WE::R2::WaveP->new(haydock=>$h, nh=>$nh, smallE=>$s);
   my $WaveProjection=$W->evaluate($epsB);

=head1 DESCRIPTION

Calculates the macroscopic projected wave operator for a given fixed
Photonic::WE::R2::AllH structure as a function of the dielectric
functions of the components. 

NOTE: Only works along principal directions, as it treats Green's
function as scalar.  

=head1 METHODS

=over 4

=item * new(haydock=>$h, nh=>$nh, smallE=>$smallE)  

Initializes the structure.

$h is Photonic::WE::R2::AllH structure (required).

$nh is the maximum number of Haydock coefficients to use (required).

$smallE is the criteria of convergence (default 1e-7).

=item * evaluate($epsB)

Returns the macroscopic wave operator for a given value of the
dielectric functions of the particle $epsB. The host's
response $epsA is taken from the metric.  

=back

=head1 ACCESORS (read only)

=over 4

=item * waveOperator

The macroscopic wave operator of the last operation

=item * All accesors of Photonic::WE::R2::GreenP


=back

=cut

package Photonic::WE::R2::WaveP;
$Photonic::WE::R2::WaveP::VERSION = '0.011';
use namespace::autoclean;
use PDL::Lite;
use PDL::NiceSlice;
use PDL::Complex;
#use PDL::MatrixOps;
use Storable qw(dclone);
use PDL::IO::Storable;
#use Photonic::WE::R2::AllH;
use Photonic::Types;
use Moose;
use MooseX::StrictConstructor;

extends 'Photonic::WE::R2::GreenP'; 

has 'waveOperator' =>  (is=>'ro', isa=>'PDL::Complex', init_arg=>undef,
             writer=>'_waveOperator',   
             documentation=>'Wave operator from last evaluation');

around 'evaluate' => sub {
    my $orig=shift;
    my $self=shift;
    my $greenP=$self->$orig(@_);
    my $wave=1/$greenP; #only works along principal directions!!
    $self->_waveOperator($wave);
    return $wave;
};

__PACKAGE__->meta->make_immutable;
    
1;

__END__
