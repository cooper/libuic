# Copyright (c) 2012, Mitchell Cooper
# UIC::User: represents a user on UIC.
# This class is typically subclassed by a server or client.
package UIC::User;

use warnings;
use strict;
use utf8;
use parent 'UIC::EventedObject';

# create a new user.
sub new {
    my ($class, %opt) = @_;
    my $server = bless \%opt, $class;
    return $server;

}

1
