# Copyright (c) 2012, Mitchell Cooper
package UIC::Type::String;

use warnings;
use strict;
use utf8;

sub new {
    return bless {}, shift;
}

sub is_string  { 1 }
sub is_number  { 0 }
sub is_array   { 0 }
sub is_object  { 0 }
sub is_boolean { 0 }

1
