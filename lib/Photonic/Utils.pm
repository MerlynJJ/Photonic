package Photonic::Utils;
$Photonic::Utils::VERSION = '0.010';
# Collection of subroutines. Thus, no Moose
require Exporter;
@ISA=qw(Exporter);
@EXPORT_OK=qw(vectors2Dlist tile cmatmult  RtoG GtoR LC
              HProd MHProd EProd SProd linearCombine);
use PDL::Lite;
use PDL::NiceSlice;
use PDL::FFTW3;
use PDL::Complex;
use Carp;
use warnings;
use strict;

sub linearCombine { #complex linear combination of states
    my $coefficients=shift; #arrayref of complex coefficients
    my $states=shift; #arrayref of complex states
    my $numCoeff=@$coefficients;
    die "More coefficients than states in basis" if
	$numCoeff>@$states;
    my $result=0+0*i;
    foreach(0..$numCoeff-1){
	$result += $coefficients->[$_]*$states->[$_];
    }
    return $result;
}
    
sub HProd { #Hermitean product between two fields. skip first 'skip' dims
    my $first=shift; 
    my $second=shift;
    my $skip=shift//0;
    my $iscomplex = (ref $first eq 'PDL::Complex' or ref $second eq
	'PDL::Complex');  
    my $ndims=$first->ndims;
    die "Dimensions should be equal" unless $ndims == $second->ndims;
    my $prod=$first->complex->Cconj*$second->complex;
    # clump all except skip dimensions, protecto RorI index and sum.
    my $result=$prod->reorder($skip+1..$ndims-1,1..$skip,0)->clump(-1-$skip-1)
	->mv(-1,0)->sumover;
    #Note: real does not take the real part, just gives a 2-real
    #vector view of each complex
    $result=$result->real unless $iscomplex;
    return $result;
}

sub MHProd { #Hermitean product between two fields with metric. skip
	     #first 'skip' dims  
    my $first=shift; 
    my $second=shift;
    my $metric=shift;
    # pass $metric->value  xyz xyz nx ny nz
    my $skip=shift//0;
    my $iscomplex = (ref $first eq 'PDL::Complex' or ref $second eq
	'PDL::Complex');  
    my $ndims=$first->ndims;
    die "Dimensions should be equal" unless $ndims == $second->ndims;
    carp "We don't trust the skip argument in MHProd yet" if $skip;
    # I'm not sure about the skiped dimensions in the next line. Is it right?
    my $mprod=($metric*$second(:,:,*1))->sumover;
    die "Dimensions should be equal" unless $ndims == $mprod->ndims;
    my $prod=$first->complex->Cconj*$mprod->complex;
    my $result=$prod->reorder($skip+1..$ndims-1,1..$skip,0)->clump(-1-$skip-1)
	->mv(-1,0)->sumover;
    #Note: real does not take the real part, just gives a 2-real
    #vector view of each complex
    $result=$result->real unless $iscomplex;
    return $result;
}

sub EProd { #Euclidean product between two fields in reciprocal
	    #space. Have to map G->-G and change magical sign. skip
	    #first 'skip' dims   
    my $first=shift; 
    my $second=shift;
    my $skip=shift//0;
    my $iscomplex = (ref $first eq 'PDL::Complex' or ref $second eq
	'PDL::Complex');  
    my $ndims=$first->ndims;
    die "Dimensions should be equal" unless $ndims == $second->ndims;
    #First reverse all reciprocal dimensions
    my $sl=":" #slice to skip complex dimension
	. (", :" x $skip) #skip dimensions
	. (", -1:0" x ($ndims-1-$skip)); #and reverse the rest
    my $first_mG=$first->slice($sl);
    #Then rotate psi_{G=0} to opposite corner with coords. (0,0,...)
    foreach($skip+1..$ndims-1){
	$first_mG=$first_mG->mv($_,0)->rotate(1)->mv(0,$_);
    }
    my $prod=$first_mG->complex*$second->complex;
    # clump all except skip dimensions, protecto RorI index and sum.
    my $result=$prod #rori, s1,s2, nx,ny
	->reorder($skip+1..$ndims-1,1..$skip,0) #nx,ny,s1,s2,rori
	->clump(-1-$skip-1) #nx*ny,s1,s2,rori
	->mv(-1,0) #rori, nx*ny,s1,s2
	->sumover; #rori, s1, s2
    #Note: real does not take the real part, just gives a 2-real
    #vector view of each complex
    $result=$result->real unless $iscomplex;
    return $result;
}

sub SProd { #Spinor product between two fields in reciprocal
	    #space. Have to map G->-G. skip first 'skip' dims (after
	    #complex and spinor dimension    
    my $first=shift; 
    my $second=shift;
    my $skip=shift//0;
    my $iscomplex = (ref $first eq 'PDL::Complex' or ref $second eq
	'PDL::Complex');  
    my $ndims=$first->ndims;
    die "Dimensions should be equal" unless $ndims == $second->ndims;
    #dimensions are like rori, pmk, s1,s2, nx,ny
    #First reverse all reciprocal dimensions
    my $sl=":" #slice to keep complex dimension
	. ", -1:0" #interchange spinor components +- to -+
	. (", :" x $skip) #keep skip dimensions
	. (", -1:0" x ($ndims-1-1-$skip)); #and reverse G indices
    my $first_mG=$first->slice($sl); #rori,pmk,s1,s2,nx,ny
    #Then rotate psi_{G=0} to opposite corner with coords. (0,0,...)
    foreach($skip+2..$ndims-1){
	$first_mG=$first_mG->mv($_,0)->rotate(1)->mv(0,$_);
    }
    my $prod=$first_mG->complex*$second->complex; #rori,pmk,s1,s2,nx,ny
    # clump all except skip dimensions, protect RorI index and sum.
    my $result=$prod #rori,pmk, s1,s2,nx,ny
	->reorder($skip+2..$ndims-1,1..$skip+1,0) #nx,ny,pmk,s1,s2,rori
	->clump(-1-$skip-1)  #nx*ny*pmk, s1, s2, rori
	->mv(-1,0) #rori,nx*ny*pmk, s1,s2
	->sumover; #rori, s1, s2
    #Note: real does not take the real part, just gives a 2-real
    #vector view of each complex
    $result=$result->real unless $iscomplex;
    return $result;
}



sub RtoG { #transform a 'complex' scalar, vector or tensorial field
	   #from real to reciprocal space  
    my $field=shift; #field to fourier transform
    my $ndims=shift; #number of dimensions to transform
    my $skip=shift; #dimensions to skip
    my $iscomplex=ref $field eq 'PDL::Complex';
    my $moved=$iscomplex? $field->real : $field;
    $moved=$moved->mv(1,-1) foreach(0..$skip-1);
    my $transformed=fftn($moved, $ndims);
    my $result= $iscomplex?$transformed->complex : $transformed;
    $result=$result->mv(-1,1) foreach(0..$skip-1);
    return $result;
}
    
sub GtoR { #transform a 'complex' scalar, vector or tensorial field from
	   #reciprocal to real space  
    my $field=shift; #field to fourier transform
    my $ndims=shift; #number of dimensions to transform
    my $skip=shift; #dimensions to skip
    my $iscomplex=ref $field eq 'PDL::Complex';
    my $moved=$iscomplex? $field->real : $field;
    $moved=$moved->mv(1,-1) foreach(0..$skip-1);
    my $transformed=ifftn($moved, $ndims);
    my $result= $iscomplex?$transformed->complex : $transformed;
    $result=$result->mv(-1,1) foreach(0..$skip-1);
    return $result;
}

sub tile { # repeat field Nx X Ny X... times
    my $f=shift;
    my @n=@_; #number of repetitions along dimension
    # Is next comment correct (2 X)?
    my $dim=0; #field is 2 X dims X nx,ny,nz...
    my $r=$f; #result
    for my $n(@n){
	die "repetition in tile should be >0" unless $n>0;
	my $r1=$r;
	$n--;
	while($n-->0){
	    $r1=$r1->glue($dim, $r);
	}
	$dim++; #prepare for next dimension
	$r=$r1;
    }
    return $r;
}

sub vectors2Dlist { #2D vector fields ready for gnuploting
    my $f=shift; #vector field
    my $s=shift; #scale
    my $d=shift; #decimation
    my $f1=$s*$f->(:,0:-1:$d, 0:-1:$d); #decimate two dimensions
    my $coords=$d*PDL::ndcoords(@{[$f1->dims]}[1,2]);
    return ( #basex, basey, vectorx vectory
	($coords((0))-.5*$f1((0)))->flat, 
	($coords((1))-.5*$f1((1)))->flat, 
	$f1((0))->flat, $f1((1))->flat);
}
    

sub cmatmult {
    my $a=shift;
    my $b=shift;
    my $ar=$a((0)); #realpart
    my $ai=$a((1)); #imaginary part
    my $br=$b((0)); #realpart
    my $bi=$b((1)); #imaginary part
    my $cr=($ar x $br) - ($ai x $bi);
    my $ci=($ar x $bi) + ($ai x $br);
    my $c=PDL::cat($cr, $ci)->mv(-1,0);
    return $c;
}

1;


__END__


=head1 NAME

Photonic::Utils

=head1 VERSION

version 0.010

=head1 SYNOPSIS

    use Photonic::Utils qw(cmatmult);
    $c=cmatmult($a, $b);

=head1 DESCRIPTION

Utility functions that may be useful.

=head1 Exportable Functions

=over 4

=item * $r=linearCombine($c, $s)

Complex linear combination of states. $c is an arrayref of 'complex' pdl
scalars and $s is an arrayref of 'complex' states ('complex'
multidimensional pdl). 

=item * $p=HProd($a, $b, $skip)

Hermitean product <a|b> of two 2x.... 'complex' multidimensional
pdls $a and $b. If $skip is present, preserve the first 1+$skip
_dimensions (the first dimension is RorI) before adding up.

=item * $p=MHProd($a, $b, $m, $skip)

Hermitean product <a|m|b> of two 2x.... 'complex' multidimensional
pdls $a and $b representing vector fields using metric $m. If $skip is
present, preserve the first 1+$skip dimensions (the first dimension
is RorI) before adding up. (Might not be functional yet, or might be wrong)

=item * $p=EProd($a, $b, $skip)

Euclidean product <a|b> of two 2x.... 'complex' multidimensional
pdls $a and $b in reciprocal space. If $skip is present, preserve the
first 1+$skip dimensions (the first dimension is RorI) before adding up. 

=item * $p=SProd($a, $b, $skip)

Spinor product <a|b> of two 2x.... 'complex' multidimensional
pdls $a and $b in reciprocal space. If $skip is present, preserve the
first 2+$skip dimensions (the first dimension is RorI and the second
the spinor dimension) before adding up. 

=item * $psiG = RtoG($psiR, $ndims, $skip)

Transforms a $ndims-dimensional 'complex' scalar, vector or tensor
field $psiR that is a function of position within the unit cell to a
complex field $psiG that is a function of the reciprocal vectors. The
first dimension must be 2, as the values are complex. The next $skip
dimensions are skiped (0 for a scalar, 1 for a vector, 2 for a
2-tensor field). The Fourier transform is performed over the
following $ndims dimensions. 

=item * $psiR = GtoR($psiG, $ndims, $skip)

The opposite transformation to RtoG. Transform a 'complex' scalara,
vector or tensorial field from reciprocal to real space. 

=item * $b=tile($a, $nx, $ny,...)

returns $a repeated periodically $nx times along the x direction, $ny
along the y direction, etc. Useful for making plots.

=item * $l=vectors2Dlist($f, $s, $d)

Returns a 2D vector field ready for gnuplotting from a vector field $f
scaling the result by $s and decimating the field by $d. The vectors
are centered on the decimated lattice points.

=item * $c=cmatmult($a, $b)

Returns the matrix product of the complex matrices $a times $b, with
signatures a(2,j,i), b(2,k,j), c(2,k,i). The first index is 2,
corresponding to the real and imaginary parts, j denotes columns of a,
rows of b, i denotes rows of a and of the result c, k denotes columns
of b and the result c. Recall that in pdl the first (row) index is
faster. May thread over extra dimensions.

=back

=head1 NOTE

Uses Inline::Pdlpp, so the first time it is run it compiles itself,
and would take a little longer than the following. To recompile,
remove the directory _Inline/ before running.

B<You must make sure that the relative location of the libutils.so
library is correct.> See $Bin below.

=cut
