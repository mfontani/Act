package Act::Handler::Talk::List;
use strict;
use Apache::Constants qw(NOT_FOUND);
use Act::Config;
use Act::Template::HTML;
use Act::Talk;
use Act::Track;
use Act::Handler::Talk::Util;

sub handler
{
    # retrieve talks and speaker info
    my $talks =Act::Talk->get_talks( conf_id => $Request{conference} );
    my $talks_total = scalar @$talks;
    $_->{user} = Act::User->new( user_id => $_->user_id ) for @$talks;

    # sort talks
    $talks = [
        sort {
                   $a->lightning <=> $b->lightning
                || lc $a->{user}->last_name cmp lc $b->{user}->last_name
                || lc $a->{user}->first_name cmp lc $b->{user}->first_name
                || $a->talk_id <=> $b->talk_id
        }
        grep {    $Config->talks_show_all
               || $_->accepted
               || ($Request{user} && (   $Request{user}->is_orga
                                      || $Request{user}->user_id == $_->user_id))
        } @$talks
    ];

    # accept / unaccept talks
    if ($Request{user} && $Request{user}->is_orga && $Request{args}{ok}) {
        for my $t (@$talks) {
            if ($t->accepted && !$Request{args}{$t->talk_id}) {
                $t->update(accepted => 0 );
                $t->{accepted} = undef;
            }
            elsif (!$t->accepted && $Request{args}{$t->talk_id}) {
                $t->update(accepted => 1 );
                Act::Handler::Talk::Util::notify_accept($t);
            }
        }
    }

    # compute some global information
    my ($accepted, $lightnings, $duration ) = ( 0, 0, 0 );
    $_->accepted && do { $accepted++; $_->lightning ? $lightnings++ : ( $duration += $_->duration) } for @$talks;

    # link the talks to their tracks (keeping the talks ordered)
    my $tracks = Act::Track->get_tracks( conf_id => $Request{conference} );

    # add the "empty track" for talks without a track
    if( @$tracks ) {
        unshift @$tracks, my $t = Act::Track->new();
        @{$t}{qw( conf_id track_id title description )}
            = ( $Request{conference}, '', '', '' );
    }
    for my $track ( @$tracks ) {
        my $id = $track->track_id;
        $track->{talks} = [ grep { $_->track_id == $id } @$talks ];
    }
    
    # process the template
    my $template = Act::Template::HTML->new();
    $template->variables(
        talks          => $talks,
        talks_total    => $talks_total,
        talks_accepted => $accepted,
        talks_duration => $duration,
        talks_lightning => $lightnings,
        tracks         => $tracks,
    ); 
    $template->process('talk/list');
}

1;
__END__

=head1 NAME

Act::Handler::User::List - show all talks

=head1 DESCRIPTION

See F<DEVDOC> for a complete discussion on handlers.

=cut
