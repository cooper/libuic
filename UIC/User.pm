# Copyright (c) 2012, Mitchell Cooper
# UIC::User: represents a user on UIC.
# This class is typically subclassed by a server or client.
package UIC::User;

use warnings;
use strict;
use utf8;
use parent 'EventedObject';

# create a new user.
sub new {
    my ($class, %opts) = @_;
    my $uic  = $opts{uic} || $UIC::main_uic;
    
    # make sure all required options are present.
    foreach my $what (qw|id name software version|) {
        next if exists $opts{$what};
        $opts{name} ||= 'unknown';
        $uic->log("user '$opts{name}' does not have '$what' option.");
        return;
    }
    
    return bless \%opts, $class;
}

##########################
### UIC OBJECT METHODS ###
##########################

sub uic_id   { shift->{id} }
sub uic_type { 'usr'       }

1
