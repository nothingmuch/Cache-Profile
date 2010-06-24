package Cache::Profile::CorrelateMissTiming;
use Moose;

use Time::HiRes qw(tv_interval clock gettimeofday);

use namespace::autoclean;

extends qw(Cache::Profile);

has _last_get_timing => (
    traits => [qw(Hash)],
    isa => "HashRef",
    is => "rw",
    handles => {
        _missed_key => "delete",
        _clear_missed => "clear",
    },
);

sub clear {
    my $self = shift;

    $self->_clear_missed;

    $self->SUPER::clear(@_);
}

sub _record_get {
    my ( $self, %args ) = @_;

    $self->SUPER::_record_get(%args);

    my ( @keys, @ret );

    if ( $self->cache->isa("Cache::Ref") ) {
        # mget by default
        @keys = @{ $args{args} };
        @ret  = @{ $args{ret} };
    } else {
        @keys = ( $args{args}[0] );
        @ret  = ( $args{ret}[0] );
    }

    my %timing;
    my %data;
    for ( my $i = 0; $i < @keys; $i++ ) {
        my ( $key, $value ) = ( $keys[$i], $ret[$i] );

        unless ( defined $value ) {
            $data{$key} = \%timing,
        }
    }

    $self->_last_get_timing(\%data);

    $timing{start_r} = [gettimeofday];
    $timing{start_c} = clock;
}

sub _record_set {
    my ( $self, %args ) = @_;

    my %pairs = @{ $args{args} };
    
    foreach my $key ( keys %pairs ) {
        if ( my $start_timing = $self->_missed_key($key) ) {
            my $set_timing = $args{timing};

            my %timing = (
                start_c => $start_timing->{start_c},
                end_c => $set_timing->{start_c},
                time_c => $set_timing->{start_c} - $start_timing->{start_c},
                start_r => $start_timing->{start_r},
                end_r => $set_timing->{end_r},
                time_r => tv_interval($start_timing->{start_r}, $set_timing->{end_r}),
            );
            
            $self->_record_miss(
                %args,
                counter => "miss",
                timing => \%timing,
            );
        }
    }

    $self->SUPER::_record_set(%args);
}

__PACKAGE__->meta->make_immutable;

# ex: set sw=4 et:

__PACKAGE__

__END__

=pod

=head1 NAME

Cache::Profile::CorrelateMissTiming - Guess the time to compute a cache miss by
correlating C<set> and C<get>

=head1 SYNOPSIS

    # see Cache::Profile

=head1 DESCRIPTION

This class will make a guess at the time it took to generate values, by saving
the time just before returning from a C<get> with a cache miss, until the
begining of a C<set>.

This value is a guess and may be completely wrong.

It also fails to account for the overhead of profiling/delegating/etc, so it's
only really useful when the cost of a cache miss is more than a simple
computation.

Otherwise it works exactly like C<Cache::Profile>
