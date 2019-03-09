package Photonic::Types;
$Photonic::Types::VERSION = '0.011';
use Moose::Util::TypeConstraints;
#use PDL::Lite;
#use PDL::NiceSlice;

subtype 'Photonic::Types::OddInt' =>
    as 'Int',
    where { $_ % 2 == 1 },
    message { "Number $_ must be odd" };

subtype 'Photonic::Types::ArrayOfOddInts' =>
    as 'ArrayRef[Photonic::Types::OddInt]',
    message { "Numbers [".join(", ", @$_). "] must have been odd" };

subtype 'Photonic::Types::Geometry' =>
  as 'Ref',
  where { $_->does('Photonic::Roles::Geometry')},
  message { "Expected a Geometry" };

subtype 'Photonic::Types::GeometryG0' =>
  as 'Photonic::Types::Geometry',
  where { $_->has_Direction0 },
  message { "You should define a direction for G=0 reciprocal vector" };

subtype 'Photonic::Types::AllH' =>
  as 'Ref',
  where { $_->does('Photonic::Roles::AllH')},
  message { "Expected an AllH" };

subtype 'Photonic::Types::AllHSave' =>
  as 'Photonic::Types::AllH',
  where { $_->keepStates == 1 },
    message { "Can't calculate fields if you don't keepStates" };

subtype 'Photonic::Types::WE::R2::AllHSave' =>
  as 'Photonic::WE::R2::AllH',
  where { $_->keepStates == 1 },
    message { "Can't calculate fields if you don't keepStates" };

no Moose::Util::TypeConstraints;

__END__

=head1 NAME

Photonic::Types

=head1 VERSION

version 0.008

=head1 SYNOPSIS

   use Photonic::Types;
   package MyPackage;
   use Moose;
   has 'n' => {is => 'ro', isa =>'Photonic::Types::OddInt'}

=head1 DESCRIPTION

Define types that are useful in constraining values for Photonic
calculations.

=head1 TYPES

=over 4

=item * Photonic::Types::OddInt

Odd integer

=item * Photonic::Types::ArrayOfOddInts

Array of OddInts

=item * Photonic::Types::GeometryG0

Photonic::Geometry with a direction for G=0 reciprocal vector

=item * Photonic::Types::NonRetarded::AllHSave

Photonic::NonRetarded:AllH object where the keepStates flag has been
turned on.

=back

=cut
