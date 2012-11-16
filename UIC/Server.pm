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
    my ($class, %opt) = @_;
    my $server = bless \%opt, $class;
    return $server;
}

1
