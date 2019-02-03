package Photonic::Roles::ReorthogonalizeR;
$Photonic::Roles::ReorthogonalizeR::VERSION = '0.010';
use Moose::Role;
use namespace::autoclean;
use Machine::Epsilon;
use PDL::Lite;
use PDL::NiceSlice;

has 'previous_W' =>(is=>'ro', 
     writer=>'_previous_W', lazy=>1, init_arg=>undef,
     default=>sub{PDL->pdl([0])},
     documentation=>"Row of error matrix"
);
has 'current_W' =>(is=>'ro',
     writer=>'_current_W', lazy=>1, init_arg=>undef,
     default=>sub{PDL->pdl([0])},
     documentation=>"Row of error matrix"
);
has 'next_W' =>(is=>'ro',
     writer=>'_next_W', lazy=>1, init_arg=>undef,
     default=>sub {PDL->pdl([1])},
     documentation=>"Next row of error matrix"
);
has 'accuracy'=>(is=>'ro', default=>sub{machine_epsilon()},
                documentation=>'Desired or machine precision');
has 'noise'=>(is=>'ro', default=>sub{machine_epsilon()},
    documentation=>'Noise introduced each iteration to overlap matrix');
has 'orthogonalizations'=>(is=>'ro', init_arg=>undef, default=>0,
			   writer=>'_orthogonalizations');

sub _checkorthogonalize {
    my $self=shift;
    return unless defined $self->nextState;
    my $a=PDL->pdl($self->as);
    my $b=PDL->pdl($self->bs);
    my $n=$self->iteration;
    $self->_previous_W(my $previous_W=$self->current_W);
    $self->_current_W(my $current_W=$self->next_W);
    my $next_W=PDL->pdl([]);
    if($n>=2){
	$next_W= $b->(1:-1)*$current_W->(1:-1) 
	    + ($a->(0:-2)-$a->(($n-1)))*$current_W->(0:-2)
	    - $b->(($n-1))*$previous_W;
	$next_W->(1:-1)+=$b->(1:-2)*$current_W->(0:-3) if ($n>=3);
	$next_W+=_sign($next_W)*2*$self->noise;
	$next_W/=$self->next_b;
    }
    $next_W=$next_W->append($self->noise) if $n>=1;
    $next_W=$next_W->append(1);
    $self->_next_W($next_W);
    return unless $n>=2;
    my $max=$next_W->(0:-2)->maximum;
    if($max > sqrt($self->accuracy)){
	$self->_orthogonalize;
	$current_W(0:-2).=$self->noise;
	$next_W(0:-2).=$self->noise;
    }
    $self->_current_W($current_W);
    $self->_next_W($next_W);
}

sub _orthogonalize {
    my $self=shift;
    $self->_orthogonalizations($self->orthogonalizations+1);
    my $states=$self->states;
    my $currentState=$self->currentState;
    my $nextState=$self->nextState;
    pop(@{$states}); #get rid of currentState;
    for my $s (@{$states}){
	($nextState,$currentState)=
	    map {$_-$s*$self->innerProduct($s, $_)}($nextState, $currentState);
    }
    my $sc=$self->magnitude($currentState);
    # Is there a danger that orthogonalization finishes the iteration
    # early at current or next state?
    $currentState/=$sc;
    $self->_currentState($currentState);
    push @{$self->states}, $currentState;
    #necessary?: By the way, -= may not work yet
    $nextState=$nextState
	-$currentState*$self->innerProduct($currentState, $nextState); 
    my $sn=$self->magnitude($nextState);
    #What if nextstate disappears after reorthogonalization?
    $nextState/=$sn;
    $self->_nextState($nextState);
}

sub _sign {
    my $s=shift;
    return 2*($s>=0)-1;
}

1;
