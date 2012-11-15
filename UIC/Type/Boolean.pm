# Copyright (c) 2012, Mitchell Cooper
package UIC::Type::Boolean;

use warnings;
use strict;
use utf8;

sub new {
    return bless {}, shift;
}

sub is_string  { 0 }
sub is_number  { 0 }
sub is_array   { 0 }
sub is_object  { 0 }
sub is_boolean { 1 }

1
