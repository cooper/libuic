# Copyright (c) 2012, Mitchell Cooper
package UIC::Type::Object;

use warnings;
use strict;
use utf8;

sub new {
    return bless {}, shift;
}

sub is_string  { 0 }
sub is_number  { 0 }
sub is_array   { 0 }
sub is_object  { 1 }
sub is_boolean { 0 }

1
