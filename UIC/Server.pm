# Copyright (c) 2012, Mitchell Cooper
# UIC::Server: represents a server on UIC.
# This class is typically subclassed by a server or client.
package UIC::Server;

use warnings;
use strict;
use utf8;
use parent 'UIC::EventedObject';

# create a new server.
sub new {
    my ($class, %opts) = @_;
    my $uic = $opts{uic} || $UIC::main_uic;
    
    # make sure all required options are present.
    foreach my $what (qw|name network_name id description software version|) {
        next if exists $opts{$what};
        $opts{name} ||= 'unknown';
        $uic->log("server '$opts{name}' does not have '$what' option.");
        return;
    }
    
    return bless \%opts, $class;
}

# returns the next available user ID and increments the counter.
sub next_user_id {
    my $server = shift;
    $server->{userID} ||= 0;
    return $server->{id}.q(.).$server->{userID}++;
}

##########################
### UIC OBJECT METHODS ###
##########################

sub uic_id   { shift->{id} }
sub uic_type { 'srv'       }

1
