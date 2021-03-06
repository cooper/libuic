# Copyright (c) 2012, Mitchell Cooper
# UIC::Channel: represents a channel on UIC.
# This class is typically subclassed by a server or client.
package UIC::Channel;

use warnings;
use strict;
use utf8;
use parent 'EventedObject';

##########################
### UIC OBJECT METHODS ###
##########################

sub uic_id   { shift->{id} }
sub uic_type { 'chn'       }

1
