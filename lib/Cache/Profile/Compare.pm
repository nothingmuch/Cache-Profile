package Cache::Profile::Compare;
use Moose;

use Cache::Profile::CorrelateMissTiming;

use namespace::autoclean;

has profile_class => (
    isa => "ClassName",
    is  => "ro",
    default => "Cache::Profile::CorrelateMissTiming",
    required => 1,
);

has caches => (
    traits => [qw(Array)],
    isa => "ArrayRef[Object]",
    required => 1,
    handles => {
        caches => "elements",
    },
);

has profiles => (
    traits => [qw(Array)],
    isa => "ArrayRef[Object]",
    lazy_build => 1,
    handles => {
        profiles => "elements",
    },
);

sub _build_profiles {
    my $self = shift;

    [ map { $self->wrap_cache($_) } $self->caches ];
}

sub wrap_cache {
    my ( $self, $cache ) = @_;

    $self->profile_class->new( cache => $cache );
}

sub get { shift->_first_def( get => @_ ) }
sub compute { shift->_first_def( compute => @_ ) }

sub _first_def {
    my $self = shift;
    my $method = shift;

    my @all_rets;

    foreach my $cache ( $self->profiles ) {
        my @ret;
        if ( wantarray ) {
            @ret = $cache->$method(@_);
        } else {
            $ret[0] = $cache->$method(@_);
        }
        push @all_rets, \@ret;
    }

    if ( wantarray ) {
        return @{ $all_rets[0] };
    } else {
        foreach my $ret ( map { $_->[0] } @all_rets ) {
            return $ret if defined $ret;
        }

        return undef;
    }
}

sub AUTOLOAD {
    my $self = shift;

    my ( $method ) = ( our $AUTOLOAD =~ /([^:]+)$/ );

    $_->$method(@_) for $self->profiles;
}

sub report {
    my $self = shift;

    my ( $fastest ) = $self->by_speedup;
    my ( $best_rate ) = $self->by_hit_rate;

    return join("\n",
        "Best speedup: " . $fastest->moniker,
        $fastest->report,
        "",
        "Best hit rate: " . $best_rate->moniker,
        $best_rate->report
    );
}

sub by_hit_rate {
    my $self = shift;

    sort { $b->hit_rate <=> $a->hit_rate } grep { defined $_->hit_rate } $self->profiles;
}

sub by_speedup {
    my $self = shift;

    sort { $a->speedup <=> $b->speedup } grep { defined $_->speedup } $self->profiles;
}

__PACKAGE__->meta->make_immutable;

# ex: set sw=4 et:

__PACKAGE__

__END__

=pod

=head1 NAME


